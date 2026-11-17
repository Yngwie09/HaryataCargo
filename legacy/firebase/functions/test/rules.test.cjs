'use strict';
const { before, after, beforeEach, test } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, getDoc, getDocs, setDoc, updateDoc, collection, query, where, serverTimestamp, writeBatch } = require('firebase/firestore');
const { ref, uploadBytes, getBytes } = require('firebase/storage');
let env;
const root = path.resolve(__dirname, '../..');
before(async () => {
  env = await initializeTestEnvironment({ projectId:'demo-haryata',
    firestore:{host:'127.0.0.1',port:8080,rules:fs.readFileSync(path.join(root,'firestore.rules'),'utf8')},
    storage:{host:'127.0.0.1',port:9199,rules:fs.readFileSync(path.join(root,'storage.rules'),'utf8')},
  });
});
after(async () => { if (env) await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore(); await env.clearStorage();
  await env.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();
    for (const [uid,role,active] of [['admin1','admin',true],['kurir1','kurir',true],['kurir2','kurir',true],['disabled','kurir',false]]) {
      await setDoc(doc(db,`users/${uid}`),{role,active,email:`${uid}@example.com`,name:uid,phone:'08123456789'});
    }
    for (const [id,status] of [['S1','Pending'],['S2','Proses'],['S3','Selesai']]) await setDoc(doc(db,`shipments/${id}`),{
      resi:id,status,courierId:'kurir1',courierEmail:'kurir1@example.com',penerima:'Penerima',alamat:'Alamat',
      sender:'Pengirim',phone:'08123456789',notes:'',weight:2,pieces:1,createdBy:'admin1',updatedBy:'admin1',
      createdAt:serverTimestamp(),updatedAt:serverTimestamp(),
    });
  });
});
const ctx = uid => env.authenticatedContext(uid,{email:`${uid}@example.com`});
const change = (extra, uid = 'kurir1') => ({...extra,updatedAt:serverTimestamp(),updatedBy:uid});
test('anonymous tidak dapat membaca pengiriman', async () => { await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'shipments/S1'))); });
test('admin membaca semua; kurir hanya tugas sendiri', async () => {
  await assertSucceeds(getDocs(collection(ctx('admin1').firestore(),'shipments')));
  await assertSucceeds(getDoc(doc(ctx('kurir1').firestore(),'shipments/S1')));
  await assertFails(getDoc(doc(ctx('kurir2').firestore(),'shipments/S1')));
});
test('query kurir harus dibatasi kepemilikan', async () => {
  await assertFails(getDocs(collection(ctx('kurir1').firestore(),'shipments')));
  await assertSucceeds(getDocs(query(collection(ctx('kurir1').firestore(),'shipments'),where('courierId','==','kurir1'))));
});
test('kurir tidak bisa menaikkan role atau membuat user', async () => {
  await assertFails(updateDoc(doc(ctx('kurir1').firestore(),'users/kurir1'),{role:'admin'}));
  await assertFails(setDoc(doc(ctx('admin1').firestore(),'users/new'),{role:'admin',active:true}));
});
test('akun nonaktif tidak dapat membaca tugas', async () => { await assertFails(getDoc(doc(ctx('disabled').firestore(),'shipments/S1'))); });
test('kurir pemilik dapat memulai Pending', async () => {
  await assertSucceeds(updateDoc(doc(ctx('kurir1').firestore(),'shipments/S1'),change({status:'Proses',startedAt:serverTimestamp()})));
});
test('kurir lain tidak bisa mengambil alih tugas', async () => {
  await assertFails(updateDoc(doc(ctx('kurir2').firestore(),'shipments/S1'),change({status:'Proses',courierId:'kurir2',startedAt:serverTimestamp()},'kurir2')));
});
test('penyelesaian langsung diblokir meski payload mengaku punya bukti', async () => {
  await assertFails(updateDoc(doc(ctx('kurir1').firestore(),'shipments/S2'),change({status:'Selesai',completedAt:serverTimestamp(),proof:{photos:{receipt:'fake'}}})));
});
test('paket selesai tidak dapat dibuka ulang', async () => {
  await assertFails(updateDoc(doc(ctx('kurir1').firestore(),'shipments/S3'),change({status:'Proses',startedAt:serverTimestamp()})));
});
test('kendala boleh dicatat tanpa mengubah penerima', async () => {
  await assertSucceeds(updateDoc(doc(ctx('kurir1').firestore(),'shipments/S2'),change({issue:'Penerima belum di lokasi'})));
  await assertFails(updateDoc(doc(ctx('kurir1').firestore(),'shipments/S2'),change({penerima:'Berubah'})));
});
test('audit hanya boleh ditulis server', async () => { await assertFails(setDoc(doc(ctx('admin1').firestore(),'shipments/S1/events/fake'),{note:'fake'})); });
test('admin dapat membuat paket dan indeks resi secara atomik', async () => {
  const db = ctx('admin1').firestore(), batch = writeBatch(db);
  batch.set(doc(db,'resi_index/HC-0001'),{shipmentId:'NEW1',createdAt:serverTimestamp()});
  batch.set(doc(db,'shipments/NEW1'),{resi:'HC-0001',status:'Pending',courierId:'kurir1',courierEmail:'kurir1@example.com',
    penerima:'Penerima',alamat:'Alamat',sender:'Pengirim',phone:'08123456789',notes:'',weight:1,pieces:1,
    createdBy:'admin1',updatedBy:'admin1',createdAt:serverTimestamp(),updatedAt:serverTimestamp()});
  await assertSucceeds(batch.commit());
  await assertFails(setDoc(doc(db,'resi_index/HC-0001'),{shipmentId:'DUP',createdAt:serverTimestamp()}));
});
test('admin tidak bisa mengubah identitas resi atau paket Proses', async () => {
  const db = ctx('admin1').firestore();
  await assertFails(updateDoc(doc(db,'shipments/S1'),change({resi:'LAIN'},'admin1')));
  await assertFails(updateDoc(doc(db,'shipments/S2'),change({alamat:'Alamat baru'},'admin1')));
});
test('lokasi hanya dapat ditulis kurir pemilik dan dibaca admin', async () => {
  const payload = {courierId:'kurir1',email:'kurir1@example.com',latitude:-5.1,longitude:119.4,accuracy:10,heading:0,speed:0,fixAt:serverTimestamp(),updatedAt:serverTimestamp(),isTracking:true};
  await assertSucceeds(setDoc(doc(ctx('kurir1').firestore(),'courier_locations/kurir1'),payload));
  await assertFails(setDoc(doc(ctx('kurir2').firestore(),'courier_locations/kurir1'),payload));
  await assertSucceeds(getDoc(doc(ctx('admin1').firestore(),'courier_locations/kurir1')));
  await assertFails(getDoc(doc(ctx('kurir2').firestore(),'courier_locations/kurir1')));
});
test('koordinat tidak valid dan field role ditolak', async () => {
  await assertFails(setDoc(doc(ctx('kurir1').firestore(),'courier_locations/kurir1'),{courierId:'kurir1',isTracking:true,role:'admin',latitude:1000}));
});
test('foto hanya untuk paket Proses milik kurir; tidak dapat ditimpa', async () => {
  const storage = ctx('kurir1').storage(); const photo = ref(storage,'proofs/kurir1/S2/123/parcel.jpg');
  const bytes = new Uint8Array([255,216,255,224]);
  await assertSucceeds(uploadBytes(photo,bytes,{contentType:'image/jpeg'}));
  await assertFails(uploadBytes(photo,bytes,{contentType:'image/jpeg'}));
  await assertFails(uploadBytes(ref(storage,'proofs/kurir1/S1/123/parcel.jpg'),bytes,{contentType:'image/jpeg'}));
  await assertFails(uploadBytes(ref(ctx('kurir2').storage(),'proofs/kurir1/S2/123/recipient.jpg'),bytes,{contentType:'image/jpeg'}));
  await assertSucceeds(getBytes(ref(ctx('admin1').storage(),'proofs/kurir1/S2/123/parcel.jpg')));
  await assertFails(getBytes(ref(ctx('kurir2').storage(),'proofs/kurir1/S2/123/parcel.jpg')));
});
test('upload non-foto dan file kebesaran ditolak', async () => {
  const storage = ctx('kurir1').storage();
  await assertFails(uploadBytes(ref(storage,'proofs/kurir1/S2/123/receipt.jpg'),new Uint8Array([1]),{contentType:'text/plain'}));
  await assertFails(uploadBytes(ref(storage,'proofs/kurir1/S2/124/receipt.jpg'),new Uint8Array(5*1024*1024+1),{contentType:'image/jpeg'}));
});

test('kurir dapat menunda pengantaran; admin dapat menugaskan ulang', async () => {
  await assertSucceeds(updateDoc(doc(ctx('kurir1').firestore(),'shipments/S2'),change({status:'Tertunda',issue:'Penerima tidak ada di rumah'})));
  await assertSucceeds(updateDoc(doc(ctx('admin1').firestore(),'shipments/S2'),change({status:'Pending',courierId:'kurir2',courierEmail:'kurir2@example.com',startedAt:null,issue:'',resolutionNote:'Ditugaskan ulang besok',issueResolvedAt:serverTimestamp()},'admin1')));
});
test('admin dapat mencatat retur; kurir tidak dapat menugaskan ulang sendiri', async () => {
  await assertFails(updateDoc(doc(ctx('kurir1').firestore(),'shipments/S2'),change({status:'Pending',resolutionNote:'Coba lagi besok',issueResolvedAt:serverTimestamp()})));
  await assertSucceeds(updateDoc(doc(ctx('admin1').firestore(),'shipments/S2'),change({status:'Retur',resolutionNote:'Barang dikembalikan',issueResolvedAt:serverTimestamp()},'admin1')));
});
