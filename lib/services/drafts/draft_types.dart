import 'dart:typed_data';

class DeliveryDraft {
  const DeliveryDraft({this.fields = const {}, this.photos = const {}});
  final Map<String, dynamic> fields;
  final Map<String, Uint8List> photos;
}

abstract interface class DeliveryDraftStore {
  Future<DeliveryDraft> read(String uid, String shipmentId);
  Future<void> saveFields(
    String uid,
    String shipmentId,
    Map<String, dynamic> fields,
  );
  Future<void> savePhoto(
    String uid,
    String shipmentId,
    String slot,
    Uint8List bytes,
  );
  Future<void> clear(String uid, String shipmentId);
}
