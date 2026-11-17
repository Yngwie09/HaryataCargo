import '../services/backend_client.dart';

enum CourierSignal { missing, live, stale, stopped, cached }

class CourierTelemetry {
  const CourierTelemetry({
    required this.courierId,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.fixAt,
    this.updatedAt,
    this.tracking = false,
    this.heading = 0,
    this.speed = 0,
  });
  final String courierId;
  final double? latitude, longitude, accuracy;
  final DateTime? fixAt, updatedAt;
  final bool tracking;
  final double heading, speed;
  static double? _number(dynamic value) =>
      value is num && value.toDouble().isFinite ? value.toDouble() : null;
  static DateTime? _date(dynamic value) => value is DataTimestamp
      ? value.toDate()
      : value is DateTime
      ? value
      : null;
  factory CourierTelemetry.fromMap(String id, Map<String, dynamic> data) =>
      CourierTelemetry(
        courierId: id,
        latitude: _number(data['latitude']),
        longitude: _number(data['longitude']),
        accuracy: _number(data['accuracy']),
        fixAt: _date(data['fixAt']),
        updatedAt: _date(data['updatedAt']),
        tracking: data['isTracking'] == true,
        heading: (_number(data['heading']) ?? 0) % 360,
        speed: (_number(data['speed']) ?? 0).clamp(0, 100),
      );
  bool get hasPosition =>
      latitude != null &&
      longitude != null &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180;
  bool get hasAccuracy => accuracy != null && accuracy! >= 0;
  CourierSignal signal(DateTime now, {bool fromCache = false}) {
    if (!hasPosition) return CourierSignal.missing;
    if (!tracking) return CourierSignal.stopped;
    if (fromCache) return CourierSignal.cached;
    if (fixAt == null || updatedAt == null) return CourierSignal.stale;
    final fixAge = now.difference(fixAt!).inSeconds,
        updateAge = now.difference(updatedAt!).inSeconds;
    if (fixAge < -120 || updateAge < -120 || fixAge >= 45 || updateAge >= 45) {
      return CourierSignal.stale;
    }
    return CourierSignal.live;
  }

  String label(DateTime now, {bool fromCache = false}) =>
      switch (signal(now, fromCache: fromCache)) {
        CourierSignal.missing => 'Belum ada lokasi',
        CourierSignal.live => 'Lokasi terkini',
        CourierSignal.stale => 'Koneksi/GPS terlambat',
        CourierSignal.stopped => 'Pelacakan berhenti',
        CourierSignal.cached => 'Data tersimpan • belum terhubung server',
      };
}
