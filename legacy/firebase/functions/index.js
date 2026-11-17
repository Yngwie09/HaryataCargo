'use strict';
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const { validateProof, validateCourier } = require('./validation');
initializeApp();
setGlobalOptions({ region: 'asia-southeast2', maxInstances: 3, memory: '256MiB', timeoutSeconds: 60 });
const db = getFirestore();
const samePhotos = (a, b) => ['receipt', 'recipient', 'parcel'].every(key => a?.[key] === b?.[key]);

async function authorize(request, role) {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Silakan masuk terlebih dahulu.');
  const snapshot = await db.doc(`users/${request.auth.uid}`).get();
  const profile = snapshot.data();
  if (!profile || profile.active !== true || profile.role !== role) throw new HttpsError('permission-denied', 'Akun tidak memiliki akses aktif.');
  return profile;
}

exports.createCourier = onCall(async (request) => {
  await authorize(request, 'admin');
  let input;
  try { input = validateCourier(request.data); }
  catch (e) { throw new HttpsError('invalid-argument', e.message); }
  let created;
  try {
    created = await getAuth().createUser({ email: input.email, password: input.password, displayName: input.name, disabled: true });
    await db.doc(`users/${created.uid}`).set({
      name: input.name, email: input.email, phone: input.phone, role: 'kurir', active: true,
      createdAt: FieldValue.serverTimestamp(), createdBy: request.auth.uid,
    });
    await getAuth().updateUser(created.uid, { disabled: false });
    return { uid: created.uid };
  } catch (e) {
    if (created) {
      // Keep a failed provisioning attempt inaccessible even if cleanup fails.
      await db.doc(`users/${created.uid}`).set({ active: false }, { merge: true }).catch(() => {});
      await getAuth().deleteUser(created.uid).catch(() => {});
      await db.doc(`users/${created.uid}`).delete().catch(() => {});
    }
    if (e.code === 'auth/email-already-exists') throw new HttpsError('already-exists', 'Email sudah digunakan.');
    throw new HttpsError('internal', 'Akun belum berhasil dibuat. Periksa konfigurasi Authentication dan coba lagi.');
  }
});

exports.setCourierActive = onCall(async (request) => {
  await authorize(request, 'admin');
  const { uid, active } = request.data || {};
  if (typeof uid !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(uid) || typeof active !== 'boolean') throw new HttpsError('invalid-argument', 'Data akun tidak valid.');
  await db.runTransaction(async (tx) => {
    const ref = db.doc(`users/${uid}`), profile = await tx.get(ref);
    if (profile.data()?.role !== 'kurir') throw new HttpsError('not-found', 'Akun kurir tidak ditemukan.');
    if (!active) {
      const pending = await tx.get(db.collection('shipments').where('courierId', '==', uid).where('status', 'in', ['Pending', 'Proses']).limit(1));
      if (!pending.empty) throw new HttpsError('failed-precondition', 'Selesaikan atau alihkan semua paket Pending/Proses sebelum menonaktifkan kurir.');
    }
    tx.update(ref, { active, updatedAt: FieldValue.serverTimestamp() });
  });
  try {
    await getAuth().updateUser(uid, { disabled: !active });
    if (!active) await getAuth().revokeRefreshTokens(uid);
  } catch (_) {
    // Firestore remains fail-closed. Repeating the call repairs Auth state.
    throw new HttpsError('internal', 'Akses database telah diperbarui, tetapi akun login belum sinkron. Ulangi tindakan ini.');
  }
  return { active };
});

exports.finalizeDelivery = onCall(async (request) => {
  await authorize(request, 'kurir');
  const uid = request.auth.uid;
  let input;
  try { input = validateProof(request.data, uid); }
  catch (e) { throw new HttpsError('invalid-argument', e.message); }
  const ref = db.doc(`shipments/${input.shipmentId}`);
  const first = (await ref.get()).data();
  if (!first || first.courierId !== uid) throw new HttpsError('permission-denied', 'Pengiriman bukan tugas Anda.');
  if (first.status === 'Selesai') {
    // Idempotent after a client loses the response to a successful commit.
    if (samePhotos(first.proof?.photos, input.proof.photos)) return { status: 'Selesai' };
    throw new HttpsError('failed-precondition', 'Pengiriman sudah selesai. Bukti tidak dapat diganti.');
  }
  if (first.status !== 'Proses') throw new HttpsError('failed-precondition', 'Pengiriman belum dalam pengantaran.');
  await Promise.all(Object.values(input.proof.photos).map(async (path) => {
    let metadata;
    try { [metadata] = await getStorage().bucket().file(path).getMetadata(); }
    catch (_) { throw new HttpsError('failed-precondition', 'Foto belum lengkap di penyimpanan. Unggah ulang bukti.'); }
    if (!['image/jpeg', 'image/png'].includes(metadata.contentType) || Number(metadata.size) <= 0 || Number(metadata.size) > 5 * 1024 * 1024) {
      throw new HttpsError('invalid-argument', 'Format atau ukuran foto tidak sesuai.');
    }
    const [header] = await getStorage().bucket().file(path).download({ start: 0, end: 7 });
    const jpeg = header[0] === 255 && header[1] === 216 && header[2] === 255;
    const png = header.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]));
    if ((!jpeg && !png) || (jpeg && metadata.contentType !== 'image/jpeg') || (png && metadata.contentType !== 'image/png')) {
      throw new HttpsError('invalid-argument', 'Isi foto bukan JPG/PNG yang valid.');
    }
  }));
  await db.runTransaction(async (tx) => {
    const [snapshot, profile] = await Promise.all([tx.get(ref), tx.get(db.doc(`users/${uid}`))]);
    const data = snapshot.data();
    if (profile.data()?.active !== true || profile.data()?.role !== 'kurir') throw new HttpsError('permission-denied', 'Akun sudah tidak aktif.');
    if (data?.courierId === uid && data.status === 'Selesai' && samePhotos(data.proof?.photos, input.proof.photos)) return;
    if (!data || data.courierId !== uid || data.status !== 'Proses') throw new HttpsError('failed-precondition', 'Status pengiriman telah berubah. Muat ulang data.');
    tx.update(ref, { status: 'Selesai', proof: input.proof, completedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(), updatedBy: uid });
  });
  return { status: 'Selesai' };
});

// Server-owned audit trail cannot be forged or removed by a mobile/web client.
exports.auditShipment = onDocumentWritten({ document: 'shipments/{shipmentId}', retry: true }, async (event) => {
  const after = event.data.after.data(), before = event.data.before.data();
  if (!after) return;
  const actorId = after.updatedBy || after.createdBy || after.courierId || '';
  const actor = actorId ? (await db.doc(`users/${actorId}`).get()).data() : null;
  let note = !before ? 'Pengiriman dibuat dan ditugaskan' : after.status !== before.status
    ? ({ Pending: `Pengantaran ulang: ${after.resolutionNote || ''}`, Proses: 'Kurir memulai pengantaran', Tertunda: `Pengantaran ditunda: ${after.issue || ''}`, Retur: `Barang diretur: ${after.resolutionNote || ''}`, Selesai: 'Barang diserahterimakan kepada penerima', Batal: `Dibatalkan: ${after.cancelReason || ''}` }[after.status] || 'Status diperbarui')
    : after.issue !== before.issue ? `Kendala: ${after.issue}` : 'Informasi / penugasan pengiriman diperbarui';
  await db.doc(`shipments/${event.params.shipmentId}/events/${event.id}`).set({
    status: after.status, note, actorId, actorEmail: actor?.email || '', createdAt: after.updatedAt || FieldValue.serverTimestamp(),
  });
});
