import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:haryata_cargo/services/backend_client.dart';
import 'package:haryata_cargo/services/live_tracking.dart';
import 'package:haryata_cargo/models/courier_motion.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  setUp(() {
    ApiClient.testingBaseUrl = 'https://api.example.test';
    ApiClient.token = 'session';
  });
  tearDown(() {
    ApiClient.testingBaseUrl = null;
    ApiClient.token = null;
    ApiClient.transport.close();
  });
  test(
    'server push menerima beberapa koordinat pada satu sambungan dengan bearer token',
    () async {
      final bytes = StreamController<List<int>>(),
          received = <RecordSet<Map<String, dynamic>>>[];
      final client = MockClient.streaming((request, _) async {
        expect(request.url.path, '/v1/tracking/stream');
        expect(request.headers['Authorization'], 'Bearer session');
        return http.StreamedResponse(bytes.stream, 200);
      });
      final subscription = watchCourierLocations(
        clientFactory: () => client,
      ).listen(received.add);
      await Future<void>.delayed(Duration.zero);
      for (final lat in [-5.1, -5.2]) {
        final payload =
            'event: locations\ndata: ${jsonEncode({
              'docs': [
                {
                  'id': 'k1',
                  'version': '1',
                  'data': {'latitude': lat, 'longitude': 119.4, 'fixAt': '2026-10-31T11:00:00.000Z'},
                },
              ],
            })}\n\n';
        final encoded = utf8.encode(payload);
        bytes.add(encoded.sublist(0, 17));
        bytes.add(encoded.sublist(17));
        await Future<void>.delayed(Duration.zero);
      }
      expect(received.length, 2);
      expect(received.last.docs.single.data()['latitude'], -5.2);
      expect(received.last.docs.single.data()['fixAt'], isA<DataTimestamp>());
      await subscription.cancel();
      await bytes.close();
    },
  );
  test(
    'gangguan push memulihkan snapshot REST tanpa menghapus posisi terakhir',
    () async {
      final bytes = StreamController<List<int>>(),
          received = <RecordSet<Map<String, dynamic>>>[];
      ApiClient.transport = MockClient(
        (request) async => http.Response('{"docs":[]}', 200),
      );
      final client = MockClient.streaming(
        (_, _) async => http.StreamedResponse(bytes.stream, 200),
      );
      final sub = watchCourierLocations(
        clientFactory: () => client,
      ).listen(received.add);
      await Future<void>.delayed(Duration.zero);
      bytes.add(
        utf8.encode(
          'data: {"docs":[{"id":"k1","version":"1","data":{"latitude":-5,"longitude":119}}]}\n\n',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await bytes.close();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        received.any((s) => s.metadata.isFromCache && s.docs.isNotEmpty),
        isTrue,
      );
      expect(received.last.docs, isEmpty);
      await sub.cancel();
    },
  );
  test(
    'respons sesi lama tidak memasukkan lokasi ke akun yang baru login',
    () async {
      final bytes = StreamController<List<int>>(),
          received = <RecordSet<Map<String, dynamic>>>[];
      final client = MockClient.streaming(
        (_, _) async => http.StreamedResponse(bytes.stream, 200),
      );
      final sub = watchCourierLocations(
        clientFactory: () => client,
      ).listen(received.add);
      await Future<void>.delayed(Duration.zero);
      ApiClient.token = 'new-session';
      bytes.add(utf8.encode('data: {"docs":[]}\n\n'));
      await Future<void>.delayed(Duration.zero);
      expect(received, isEmpty);
      await sub.cancel();
      await bytes.close();
    },
  );
  test('marker berjalan di antara dua GPS dan tidak melewati tujuan', () {
    const start = LatLng(-5.1, 119.4), end = LatLng(-5.102, 119.402);
    final half = interpolatePosition(start, end, .5);
    expect(half.latitude, closeTo(-5.101, 1e-9));
    expect(half.longitude, closeTo(119.401, 1e-9));
    expect(interpolatePosition(start, end, 2).latitude, end.latitude);
    expect(interpolatePosition(start, end, -1).latitude, start.latitude);
    expect(positionDistance(start, end), greaterThan(300));
  });
  test('arah marker melintasi utara memakai putaran terpendek', () {
    expect(interpolateHeading(350, 10, .5), closeTo(0, 1e-9));
    expect(interpolateHeading(10, 350, .5), closeTo(0, 1e-9));
    expect(interpolateHeading(90, 180, .5), 135);
  });
  test('interpolasi garis tanggal tidak melintasi seluruh dunia', () {
    final point = interpolatePosition(
      const LatLng(0, 179.9),
      const LatLng(0, -179.9),
      .5,
    );
    expect(point.longitude.abs(), closeTo(180, 1e-9));
  });
}
