import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:haryata_cargo/services/courier_location_service.dart';

Position fix(int seconds) => Position(
  latitude: -5.1,
  longitude: 119.4,
  timestamp: DateTime.utc(2026, 10, 27).add(Duration(seconds: seconds)),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);
void main() {
  test(
    'tracking menulis posisi awal dan menerima stream tanpa listener ganda',
    () async {
      final stream = StreamController<Position>.broadcast();
      final writes = <Map<String, dynamic>>[];
      var subscriptions = 0;
      final service = CourierLocationService.testing(
        () async => fix(0),
        (_) {
          subscriptions++;
          return stream.stream;
        },
        (_, data, _) async {
          writes.add(data);
        },
      );
      await service.start(courierId: 'k1', email: 'k1@example.com');
      await service.start(courierId: 'k1', email: 'k1@example.com');
      expect(service.running, isTrue);
      expect(subscriptions, 1);
      expect(writes.length, 1);
      stream.add(fix(15));
      await Future<void>.delayed(Duration.zero);
      await service.pendingWrites;
      expect(writes.length, 2);
      expect(writes.last['isTracking'], isTrue);
      await service.stop(courierId: 'k1');
      expect(writes.last['isTracking'], isFalse);
      expect(service.running, isFalse);
      await stream.close();
    },
  );
  test('heartbeat memperbarui lokasi ketika kurir diam', () async {
    final stream = StreamController<Position>.broadcast();
    var read = 0;
    final writes = <Map<String, dynamic>>[];
    final service = CourierLocationService.testing(
      () async => fix(read++ * 45),
      (_) => stream.stream,
      (_, data, _) async {
        writes.add(data);
      },
    );
    await service.start(courierId: 'k1', email: 'k1@example.com');
    await service.refresh(email: 'k1@example.com');
    await service.pendingWrites;
    expect(writes.length, 2);
    expect(read, 2);
    await service.stopLocal();
    await stream.close();
  });
  test(
    'stop saat permintaan GPS belum selesai mencegah tracking hidup kembali',
    () async {
      final delayed = Completer<Position>();
      var writes = 0, subscriptions = 0;
      final service = CourierLocationService.testing(
        () => delayed.future,
        (_) {
          subscriptions++;
          return const Stream.empty();
        },
        (_, _, _) async {
          writes++;
        },
      );
      final start = service.start(courierId: 'k1', email: 'k1@example.com');
      await Future<void>.delayed(Duration.zero);
      await service.stopLocal();
      delayed.complete(fix(0));
      await start;
      expect(writes, 0);
      expect(subscriptions, 0);
      expect(service.running, isFalse);
    },
  );
  test('sampel GPS lama tidak menimpa sampel lebih baru', () async {
    final stream = StreamController<Position>.broadcast();
    final writes = <Map<String, dynamic>>[];
    final service = CourierLocationService.testing(
      () async => fix(20),
      (_) => stream.stream,
      (_, data, _) async {
        writes.add(data);
      },
    );
    await service.start(courierId: 'k1', email: 'k1@example.com');
    stream.add(fix(5));
    await Future<void>.delayed(Duration.zero);
    await service.pendingWrites;
    expect(writes.length, 1);
    await service.stopLocal();
    await stream.close();
  });
  test('GPS gagal tidak membuat stream atau status tracking palsu', () async {
    var writes = 0;
    final service = CourierLocationService.testing(
      () async => throw StateError('GPS mati'),
      (_) => const Stream.empty(),
      (_, _, _) async {
        writes++;
      },
    );
    await expectLater(
      service.start(courierId: 'k1', email: 'k1@example.com'),
      throwsStateError,
    );
    expect(service.running, isFalse);
    expect(writes, 0);
    await service.stopLocal();
  });
}
