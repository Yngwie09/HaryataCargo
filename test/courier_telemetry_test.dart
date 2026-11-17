import 'package:flutter_test/flutter_test.dart';
import 'package:haryata_cargo/models/courier_telemetry.dart';

void main() {
  final now = DateTime.utc(2026, 10, 27, 8);
  Map<String, dynamic> data() => {
    'latitude': -5.1,
    'longitude': 119.4,
    'accuracy': 8,
    'isTracking': true,
    'fixAt': now,
    'updatedAt': now,
  };
  test('posisi baru dianggap terkini hanya setelah server mengonfirmasi', () {
    final p = CourierTelemetry.fromMap('k1', data());
    expect(p.signal(now), CourierSignal.live);
    expect(p.signal(now, fromCache: true), CourierSignal.cached);
    expect(p.signal(now.add(const Duration(minutes: 3))), CourierSignal.stale);
  });
  test('koordinat tidak valid tidak pernah menjadi marker', () {
    for (final value in [double.nan, double.infinity, 91, '-5.1', null]) {
      expect(
        CourierTelemetry.fromMap('k1', {
          ...data(),
          'latitude': value,
        }).hasPosition,
        false,
      );
    }
  });
  test(
    'jam perangkat melenceng ke masa depan tidak menghasilkan indikator live',
    () {
      final p = CourierTelemetry.fromMap('k1', {
        ...data(),
        'fixAt': now.add(const Duration(minutes: 10)),
      });
      expect(p.signal(now), CourierSignal.stale);
    },
  );
  test('posisi lama tetap tersedia setelah pelacakan berhenti', () {
    final p = CourierTelemetry.fromMap('k1', {...data(), 'isTracking': false});
    expect(p.hasPosition, true);
    expect(p.signal(now), CourierSignal.stopped);
  });
  test('timestamp atau koordinat yang hilang ditangani dengan aman', () {
    expect(
      CourierTelemetry.fromMap('k1', {}).signal(now),
      CourierSignal.missing,
    );
    expect(
      CourierTelemetry.fromMap('k1', {
        ...data(),
        'updatedAt': null,
      }).signal(now),
      CourierSignal.stale,
    );
  });
  test('akurasi NaN tidak membuat radius atau teks peta rusak', () {
    final p = CourierTelemetry.fromMap('k1', {
      ...data(),
      'accuracy': double.nan,
    });
    expect(p.hasPosition, true);
    expect(p.hasAccuracy, false);
  });
}
