import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:haryata_cargo/services/backend_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.testingBaseUrl = 'https://api.example.test';
    await CargoAuth.instance.clearSession();
  });
  tearDown(() {
    ApiClient.transport.close();
    ApiClient.token = null;
    ApiClient.testingBaseUrl = null;
  });
  test(
    'timestamp dan sentinel server melewati JSON tanpa kehilangan waktu',
    () {
      final date = DateTime.utc(2026, 10, 31, 8, 30, 1, 123, 456);
      expect(encodeApiData(DataTimestamp.fromDate(date)), {
        r'$date': date.toIso8601String(),
      });
      expect(encodeApiData(DataValue.serverTimestamp()), {
        r'$serverTimestamp': true,
      });
      final decoded =
          decodeApiData({'createdAt': date.toIso8601String()}) as Map;
      expect((decoded['createdAt'] as DataTimestamp).toDate(), date);
      final beforeEpoch = DateTime.fromMicrosecondsSinceEpoch(-1, isUtc: true);
      expect(DataTimestamp.fromDate(beforeEpoch).toDate(), beforeEpoch);
    },
  );
  test(
    'kueri dan hasil PostgreSQL memakai filter, urutan, versi dan tanggal bertipe',
    () async {
      ApiClient.token = 'session';
      ApiClient.transport = MockClient((request) async {
        expect(request.url.path, '/v1/query');
        expect(request.headers['Authorization'], 'Bearer session');
        final body = jsonDecode(request.body) as Map;
        expect(body['filters'], [
          ['courierId', 'eq', 'k1'],
        ]);
        expect(body['order'], [
          ['createdAt', true],
        ]);
        expect(body['limit'], 50);
        return http.Response(
          jsonEncode({
            'docs': [
              {
                'id': 's1',
                'version': '7',
                'data': {
                  'status': 'Pending',
                  'createdAt': '2026-10-31T08:00:00.000Z',
                },
              },
            ],
          }),
          200,
        );
      });
      final result = await CargoStore.instance
          .collection('shipments')
          .where('courierId', isEqualTo: 'k1')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      expect(result.docs.single.id, 's1');
      expect(result.docs.single.version, '7');
      expect(result.docs.single.data()['createdAt'], isA<DataTimestamp>());
      expect(result.metadata.isFromCache, false);
    },
  );
  test('transaksi membaca ulang saat versi server berubah', () async {
    var reads = 0, commits = 0;
    ApiClient.transport = MockClient((request) async {
      if (request.url.path == '/v1/record') {
        reads++;
        return http.Response(
          jsonEncode({
            'doc': {
              'id': 's1',
              'version': '$reads',
              'data': {'status': 'Pending'},
            },
          }),
          200,
        );
      }
      commits++;
      final body = jsonDecode(request.body) as Map;
      expect(body['reads'], [
        {'path': 'shipments/s1', 'version': '$reads'},
      ]);
      expect(body['writes'][0]['data']['updatedAt'], {
        r'$serverTimestamp': true,
      });
      return commits == 1
          ? http.Response(
              jsonEncode({'code': 'conflict', 'message': 'berubah'}),
              409,
            )
          : http.Response('{"committed":true}', 200);
    });
    final ref = CargoStore.instance.collection('shipments').doc('s1');
    final result = await CargoStore.instance.runTransaction((tx) async {
      await tx.get(ref);
      tx.update(ref, {
        'status': 'Proses',
        'updatedAt': DataValue.serverTimestamp(),
      });
      return 'ok';
    });
    expect(result, 'ok');
    expect(reads, 2);
    expect(commits, 2);
  });
  test('401 dari sesi lama tidak menghapus login sesi baru', () async {
    final started = Completer<void>(), response = Completer<http.Response>();
    ApiClient.token = 'old-session';
    ApiClient.transport = MockClient((request) {
      expect(request.headers['Authorization'], 'Bearer old-session');
      started.complete();
      return response.future;
    });
    final pending = ApiClient.request('/v1/auth/me', get: true);
    final assertion = expectLater(pending, throwsA(isA<ApiException>()));
    await started.future;
    ApiClient.token = 'new-session';
    response.complete(http.Response('{"code":"unauthenticated"}', 401));
    await assertion;
    expect(ApiClient.token, 'new-session');
  });
  test('sesi kedaluwarsa menghapus token dan profil lokal', () async {
    SharedPreferences.setMockInitialValues({
      'cargo_api_token': 'expired',
      'cargo_api_user': '{"uid":"u1","email":"a@example.test"}',
    });
    await CargoAuth.instance.initialize();
    expect(CargoAuth.instance.currentUser?.uid, 'u1');
    ApiClient.transport = MockClient(
      (_) async => http.Response('{"code":"unauthenticated"}', 401),
    );
    await expectLater(
      ApiClient.request('/v1/auth/me', get: true),
      throwsA(isA<ApiException>()),
    );
    expect(ApiClient.token, isNull);
    expect(CargoAuth.instance.currentUser, isNull);
    expect(
      (await SharedPreferences.getInstance()).getString('cargo_api_token'),
      isNull,
    );
  });
  test('gangguan jaringan tidak diubah menjadi sesi tidak valid', () async {
    ApiClient.token = 'valid-session';
    ApiClient.transport = MockClient(
      (_) async => throw http.ClientException('offline'),
    );
    await expectLater(
      ApiClient.request('/v1/query'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          'network-request-failed',
        ),
      ),
    );
    expect(ApiClient.token, 'valid-session');
  });
  test('snapshot offline mempertahankan data dengan label cache', () async {
    var calls = 0;
    ApiClient.transport = MockClient((_) async {
      if (++calls == 1) {
        return http.Response(
          '{"docs":[{"id":"k1","version":"1","data":{"latitude":-5.1,"longitude":119.4}}]}',
          200,
        );
      }
      throw http.ClientException('offline');
    });
    final snapshots = await CargoStore.instance
        .collection('courier_locations')
        .snapshots()
        .take(2)
        .toList();
    expect(snapshots.first.metadata.isFromCache, false);
    expect(snapshots.last.metadata.isFromCache, true);
    expect(snapshots.last.docs.single.data()['latitude'], -5.1);
  }, timeout: const Timeout(Duration(seconds: 12)));
  test('foto diunduh dengan autentikasi dan batas ukuran', () async {
    ApiClient.token = 'session';
    ApiClient.transport = MockClient((request) async {
      expect(
        request.url.queryParameters['path'],
        'proofs/k1/s1/123/receipt.png',
      );
      expect(request.headers['Authorization'], 'Bearer session');
      return http.Response.bytes([1, 2, 3], 200);
    });
    final file = CargoFiles.instance.ref('proofs/k1/s1/123/receipt.png');
    expect(await file.getData(5), [1, 2, 3]);
    await expectLater(file.getData(2), throwsA(isA<ApiException>()));
  });
}
