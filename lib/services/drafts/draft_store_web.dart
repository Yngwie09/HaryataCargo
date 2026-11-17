import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'draft_types.dart';

DeliveryDraftStore createDraftStore() => WebDraftStore();

/// The Android implementation persists full photos. Web retains form metadata only.
class WebDraftStore implements DeliveryDraftStore {
  String _key(String uid, String id) =>
      'deliveryDraft:${jsonEncode([uid, id])}';
  @override
  Future<DeliveryDraft> read(String uid, String shipmentId) async {
    final value = (await SharedPreferences.getInstance()).getString(
      _key(uid, shipmentId),
    );
    if (value == null) return const DeliveryDraft();
    return DeliveryDraft(
      fields: Map<String, dynamic>.from(jsonDecode(value) as Map),
    );
  }

  @override
  Future<void> saveFields(
    String uid,
    String shipmentId,
    Map<String, dynamic> fields,
  ) async {
    final ok = await (await SharedPreferences.getInstance()).setString(
      _key(uid, shipmentId),
      jsonEncode(fields),
    );
    if (!ok) throw StateError('Draft belum dapat disimpan pada browser ini.');
  }

  @override
  Future<void> savePhoto(
    String uid,
    String shipmentId,
    String slot,
    Uint8List bytes,
  ) async {}
  @override
  Future<void> clear(String uid, String shipmentId) async {
    await (await SharedPreferences.getInstance()).remove(_key(uid, shipmentId));
  }
}
