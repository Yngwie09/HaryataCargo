import 'backend_client.dart';
import '../core/shipment_policy.dart';

class ShipmentService {
  static final db = CargoStore.instance;
  static CargoUser get user => CargoAuth.instance.currentUser!;
  static Future<String?> findByResi(
    String input, {
    bool courier = false,
  }) async {
    final resi = normalizeResi(input);
    if (!validResi(resi)) {
      throw StateError(
        'Masukkan nomor resi lengkap untuk mencari seluruh data.',
      );
    }
    RecordQuery<Map<String, dynamic>> query = db
        .collection('shipments')
        .where('resi', isEqualTo: resi);
    if (courier) query = query.where('courierId', isEqualTo: user.uid);
    final result = await query
        .limit(1)
        .get(const ReadOptions(source: ReadSource.server))
        .timeout(const Duration(seconds: 15));
    return result.docs.isEmpty ? null : result.docs.first.id;
  }

  static Future<void> resolveIssue(
    String id, {
    required bool retry,
    required String reason,
    String? courierId,
  }) async {
    if (reason.trim().length < 5) {
      throw StateError('Catatan tindak lanjut minimal 5 karakter.');
    }
    final ref = db.collection('shipments').doc(id);
    await db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!['Proses', 'Tertunda'].contains(doc.data()?['status'])) {
        throw StateError('Status telah berubah. Muat ulang pengiriman.');
      }
      final update = <String, dynamic>{
        'status': retry ? 'Pending' : 'Retur',
        'resolutionNote': reason.trim(),
        'issueResolvedAt': DataValue.serverTimestamp(),
        'updatedAt': DataValue.serverTimestamp(),
        'updatedBy': user.uid,
      };
      if (retry) {
        if (courierId == null) {
          throw StateError('Pilih kurir aktif untuk pengantaran ulang.');
        }
        final courier = await tx.get(db.collection('users').doc(courierId));
        if (courier.data()?['role'] != 'kurir' ||
            courier.data()?['active'] != true) {
          throw StateError('Kurir tidak aktif.');
        }
        update.addAll({
          'courierId': courierId,
          'courierEmail': courier.data()?['email'] ?? '',
          'startedAt': null,
          'issue': '',
        });
      }
      tx.update(ref, update);
    });
  }

  static Future<String> create(Map<String, dynamic> fields) async {
    final resi = normalizeResi(fields['resi'] as String);
    if (!validResi(resi)) {
      throw StateError(
        'Resi harus 4–40 karakter: huruf, angka, atau tanda hubung.',
      );
    }
    final ref = db.collection('shipments').doc();
    final index = db.collection('resi_index').doc(resi);
    await db.runTransaction((tx) async {
      final found = await tx.get(index);
      if (found.exists) throw StateError('Nomor resi sudah digunakan.');
      final courier = await tx.get(
        db.collection('users').doc(fields['courierId'] as String),
      );
      if (courier.data()?['role'] != 'kurir' ||
          courier.data()?['active'] == false) {
        throw StateError('Pilih kurir yang aktif.');
      }
      tx.set(index, {
        'shipmentId': ref.id,
        'createdAt': DataValue.serverTimestamp(),
      });
      tx.set(ref, {
        ...fields,
        'resi': resi,
        'courierEmail': courier.data()?['email'] ?? '',
        'status': 'Pending',
        'createdBy': user.uid,
        'createdAt': DataValue.serverTimestamp(),
        'updatedAt': DataValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
    });
    return ref.id;
  }

  static Future<void> transition(
    String id,
    String to, {
    Map<String, dynamic>? proof,
  }) async {
    if (to == 'Selesai') {
      await CargoActions.instance.httpsCallable('finalizeDelivery').call({
        'shipmentId': id,
        'proof': proof,
      });
      return;
    }
    final ref = db.collection('shipments').doc(id);
    await db.runTransaction((tx) async {
      final snapshot = await tx.get(ref);
      final data = snapshot.data();
      if (data == null) throw StateError('Pengiriman tidak ditemukan.');
      final from = data['status'] as String? ?? 'Pending';
      if (!canTransition(from, to)) {
        throw StateError('Status sudah berubah. Muat ulang pengiriman.');
      }
      if (data['courierId'] != user.uid) {
        throw StateError('Pengiriman ini bukan tugas Anda.');
      }
      tx.update(ref, {
        'status': to,
        'updatedAt': DataValue.serverTimestamp(),
        'updatedBy': user.uid,
        if (to == 'Proses') 'startedAt': DataValue.serverTimestamp(),
      });
    });
  }

  static Future<void> editPending(
    String id,
    Map<String, dynamic> fields,
  ) async {
    final ref = db.collection('shipments').doc(id);
    await db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (doc.data()?['status'] != 'Pending') {
        throw StateError('Hanya pengiriman Pending yang dapat diedit.');
      }
      final courier = await tx.get(
        db.collection('users').doc(fields['courierId'] as String),
      );
      if (courier.data()?['role'] != 'kurir' ||
          courier.data()?['active'] == false) {
        throw StateError('Kurir tidak aktif.');
      }
      tx.update(ref, {
        ...fields,
        'courierEmail': courier.data()?['email'] ?? '',
        'updatedAt': DataValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
    });
  }

  static Future<void> cancel(String id, String reason) async {
    if (reason.trim().length < 5) {
      throw StateError('Tuliskan alasan pembatalan minimal 5 karakter.');
    }
    final ref = db.collection('shipments').doc(id);
    await db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (doc.data()?['status'] != 'Pending') {
        throw StateError('Hanya pengiriman Pending yang dapat dibatalkan.');
      }
      tx.update(ref, {
        'status': 'Batal',
        'cancelReason': reason.trim(),
        'updatedAt': DataValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
    });
  }

  static Future<void> reportIssue(String id, String note) async {
    if (note.trim().length < 5) {
      throw StateError('Tuliskan kendala minimal 5 karakter.');
    }
    final ref = db.collection('shipments').doc(id);
    await db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (doc.data()?['courierId'] != user.uid ||
          doc.data()?['status'] != 'Proses') {
        throw StateError('Pengiriman tidak sedang Anda antar.');
      }
      tx.update(ref, {
        'issue': note.trim(),
        'status': 'Tertunda',
        'updatedAt': DataValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
    });
  }
}
