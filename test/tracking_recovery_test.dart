import 'package:haryata_cargo/services/backend_client.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:haryata_cargo/services/courier_location_service.dart';
import 'package:haryata_cargo/models/courier_telemetry.dart';

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
  foregroundRecoveryTests();
  test(
    'koneksi terputus tidak membatalkan GPS atau foreground stream',
    () async {
      final stream = StreamController<Position>.broadcast();
      final blocked = Completer<void>();
      final service = CourierLocationService.testing(
        () async => fix(0),
        (_) => stream.stream,
        (_, _, _) => blocked.future,
        writeTimeout: const Duration(milliseconds: 5),
      );
      await service.start(courierId: 'k1', email: 'k1@example.com');
      expect(service.running, true);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect(service.running, true);
      expect(service.lastSyncedAt.value, isNull);
      expect(service.message.value, contains('belum tersinkron'));
      await service.stopLocal();
      await service.pendingWrites;
      blocked.complete();
      await stream.close();
    },
  );
  test(
    'sinkronisasi pulih setelah write pertama gagal tanpa menyalakan stream baru',
    () async {
      final stream = StreamController<Position>.broadcast();
      var read = 0, writes = 0, subscriptions = 0;
      final service = CourierLocationService.testing(
        () async => fix(read++ * 45),
        (_) {
          subscriptions++;
          return stream.stream;
        },
        (_, _, _) async {
          writes++;
          if (writes == 1) throw StateError('offline');
        },
      );
      await service.start(courierId: 'k1', email: 'k1@example.com');
      await service.pendingWrites;
      expect(service.running, true);
      await service.synchronize(email: 'k1@example.com');
      expect(writes, 2);
      expect(subscriptions, 1);
      expect(service.lastSyncedAt.value, isNotNull);
      await service.stopLocal();
      await stream.close();
    },
  );
  test(
    'antrean koneksi lambat hanya mempertahankan posisi paling baru',
    () async {
      final stream = StreamController<Position>.broadcast();
      final firstWrite = Completer<void>();
      final saved = <DataTimestamp>[];
      final service = CourierLocationService.testing(
        () async => fix(0),
        (_) => stream.stream,
        (_, d, _) async {
          saved.add(d['fixAt'] as DataTimestamp);
          if (saved.length == 1) await firstWrite.future;
        },
      );
      await service.start(courierId: 'k1', email: 'k1@example.com');
      for (final second in [15, 30, 45, 60]) {
        stream.add(fix(second));
      }
      await Future<void>.delayed(Duration.zero);
      firstWrite.complete();
      await service.pendingWrites;
      expect(saved.length, 2);
      expect(saved.last.toDate().toUtc(), fix(60).timestamp.toUtc());
      await service.stopLocal();
      await stream.close();
    },
  );
  test(
    'GPS sesi lama yang lambat tidak menghalangi atau menghentikan sesi baru',
    () async {
      final firstGps = Completer<Position>();
      final stream = StreamController<Position>.broadcast();
      var reads = 0;
      final uids = <String>[];
      final service = CourierLocationService.testing(
        () {
          reads++;
          return reads == 1 ? firstGps.future : Future.value(fix(45));
        },
        (_) => stream.stream,
        (uid, _, _) async {
          uids.add(uid);
        },
      );
      final old = service.start(courierId: 'old', email: 'old@example.com');
      await Future<void>.delayed(Duration.zero);
      await service.start(courierId: 'new', email: 'new@example.com');
      firstGps.complete(fix(0));
      await old;
      await service.pendingWrites;
      await service.stop(courierId: 'old');
      expect(service.running, true);
      expect(uids, ['new']);
      await service.stopLocal();
      await stream.close();
    },
  );
  test(
    'lokasi dikonversi menjadi marker live dan tetap tersimpan setelah stop',
    () async {
      final stream = StreamController<Position>.broadcast();
      final server = <String, dynamic>{};
      final now = fix(0).timestamp;
      final service = CourierLocationService.testing(
        () async => fix(0),
        (_) => stream.stream,
        (_, d, merge) async {
          if (!merge) server.clear();
          server.addAll(d);
          if (d.containsKey('updatedAt')) {
            server['updatedAt'] = DataTimestamp.fromDate(now);
          }
        },
      );
      await service.start(courierId: 'k1', email: 'k1@example.com');
      await service.pendingWrites;
      expect(
        CourierTelemetry.fromMap('k1', server).signal(now),
        CourierSignal.live,
      );
      await service.stop(courierId: 'k1');
      final stopped = CourierTelemetry.fromMap('k1', server);
      expect(stopped.signal(now), CourierSignal.stopped);
      expect(stopped.hasPosition, true);
      await stream.close();
    },
  );
}

void foregroundRecoveryTests() {
  test(
    'pindah ke background saat menunggu GPS tidak memulai foreground service secara ilegal',
    () async {
      final delayed = Completer<Position>();
      var visible = true, subscriptions = 0;
      final stream = StreamController<Position>.broadcast();
      final service = CourierLocationService.testing(
        () => delayed.future,
        (_) {
          subscriptions++;
          return stream.stream;
        },
        (_, _, _) async {},
        canStartForeground: () => visible,
      );
      final starting = service.start(courierId: 'k1', email: 'k1@example.com');
      await Future<void>.delayed(Duration.zero);
      visible = false;
      delayed.complete(fix(0));
      await expectLater(starting, throwsStateError);
      expect(subscriptions, 0);
      expect(service.running, false);
      await service.stopLocal();
      await stream.close();
    },
  );
  test(
    'dua permintaan mulai bersamaan memakai satu permintaan GPS dan satu stream',
    () async {
      final delayed = Completer<Position>();
      var reads = 0, subscriptions = 0;
      final stream = StreamController<Position>.broadcast();
      final service = CourierLocationService.testing(
        () {
          reads++;
          return delayed.future;
        },
        (_) {
          subscriptions++;
          return stream.stream;
        },
        (_, _, _) async {},
      );
      final a = service.start(courierId: 'k1', email: 'k1@example.com');
      final b = service.start(courierId: 'k1', email: 'k1@example.com');
      await Future<void>.delayed(Duration.zero);
      delayed.complete(fix(0));
      await Future.wait([a, b]);
      await service.pendingWrites;
      expect(reads, 1);
      expect(subscriptions, 1);
      await service.stopLocal();
      await stream.close();
    },
  );
}
