import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../../core/shipment_policy.dart';
import 'draft_types.dart';

DeliveryDraftStore createDraftStore() =>
    FileDraftStore(getApplicationSupportDirectory);

class FileDraftStore implements DeliveryDraftStore {
  FileDraftStore(this.rootDirectory);
  final Future<Directory> Function() rootDirectory;
  Future<void> _queue = Future.value();
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Directory> _directory(String uid, String id) async {
    if (uid.isEmpty || id.isEmpty) {
      throw ArgumentError('Akun dan pengiriman wajib diisi.');
    }
    final key = base64Url
        .encode(utf8.encode(jsonEncode([uid, id])))
        .replaceAll('=', '');
    return Directory('${(await rootDirectory()).path}/delivery_drafts/$key');
  }

  Future<File?> _readable(File file) async {
    if (await file.exists()) return file;
    final backup = File('${file.path}.bak');
    return await backup.exists() ? backup : null;
  }

  Future<void> _atomicWrite(File file, List<int> bytes) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp'), backup = File('${file.path}.bak');
    await temp.writeAsBytes(bytes, flush: true);
    if (await file.exists()) {
      if (await backup.exists()) await backup.delete();
      await file.rename(backup.path);
    }
    await temp.rename(file.path);
    if (await backup.exists()) await backup.delete();
  }

  @override
  Future<DeliveryDraft> read(String uid, String shipmentId) =>
      _serial(() async {
        final dir = await _directory(uid, shipmentId);
        Map<String, dynamic> fields = {};
        final metadata = await _readable(File('${dir.path}/fields.json'));
        if (metadata != null) {
          try {
            final decoded = jsonDecode(await metadata.readAsString());
            if (decoded is Map) fields = Map<String, dynamic>.from(decoded);
          } on FormatException {
            /* Keep recoverable photos when only metadata is damaged. */
          }
        }
        final photos = <String, Uint8List>{};
        for (final slot in proofLabels.keys) {
          final file = await _readable(File('${dir.path}/$slot.bin'));
          if (file != null && await file.length() <= 5 * 1024 * 1024) {
            photos[slot] = await file.readAsBytes();
          }
        }
        return DeliveryDraft(fields: fields, photos: photos);
      });
  @override
  Future<void> saveFields(
    String uid,
    String shipmentId,
    Map<String, dynamic> fields,
  ) => _serial(() async {
    final dir = await _directory(uid, shipmentId);
    await _atomicWrite(
      File('${dir.path}/fields.json'),
      utf8.encode(jsonEncode(fields)),
    );
  });
  @override
  Future<void> savePhoto(
    String uid,
    String shipmentId,
    String slot,
    Uint8List bytes,
  ) => _serial(() async {
    if (!proofLabels.containsKey(slot) ||
        bytes.isEmpty ||
        bytes.length > 5 * 1024 * 1024) {
      throw ArgumentError('Foto tidak valid.');
    }
    final dir = await _directory(uid, shipmentId);
    await _atomicWrite(File('${dir.path}/$slot.bin'), bytes);
  });
  @override
  Future<void> clear(String uid, String shipmentId) => _serial(() async {
    final dir = await _directory(uid, shipmentId);
    if (await dir.exists()) await dir.delete(recursive: true);
  });
}
