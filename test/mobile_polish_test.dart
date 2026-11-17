import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:haryata_cargo/core/ui.dart';
import 'package:haryata_cargo/screens/daily_report_page.dart';
import 'package:haryata_cargo/screens/manage_couriers_page.dart';
import 'package:haryata_cargo/services/backend_client.dart';
import 'package:haryata_cargo/widgets/shipment_status_summary.dart';
import 'package:haryata_cargo/widgets/operations_overview.dart';

const counts = {
  'Pending': 11,
  'Proses': 0,
  'Tertunda': 2,
  'Selesai': 0,
  'Retur': 1,
  'Batal': 1,
};

void main() {
  testWidgets(
    'Ringkasan server membuka daftar dengan filter status yang sesuai',
    (tester) async {
      ApiClient.testingBaseUrl = 'https://api.example.test';
      var filtered = false;
      ApiClient.transport = MockClient((request) async {
        if (request.url.path == '/v1/dashboard') {
          return http.Response(jsonEncode({'counts': counts}), 200);
        }
        final body = jsonDecode(request.body) as Map;
        filtered = (body['filters'] as List).any(
          (dynamic f) => f[0] == 'status' && f[2] == 'Pending',
        );
        return http.Response('{"docs":[]}', 200);
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: cargoTheme(),
          home: const Scaffold(
            body: SingleChildScrollView(child: OperationsOverview()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('11'), findsOneWidget);
      await tester.ensureVisible(find.text('Lihat Pending'));
      await tester.tap(find.text('Lihat Pending'));
      await tester.pumpAndSettle();
      expect(filtered, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  setUpAll(() async {
    for (final entry in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final file = File(
        '../.tools/flutter/bin/cache/artifacts/material_fonts/${entry.value}',
      );
      if (file.existsSync()) {
        await (FontLoader(entry.key)..addFont(
              Future.value(ByteData.sublistView(await file.readAsBytes())),
            ))
            .load();
      }
    }
  });
  tearDown(() {
    ApiClient.transport.close();
    ApiClient.testingBaseUrl = null;
  });
  for (final width in [320.0, 360.0, 412.0, 800.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('Kartu laporan rapi pada lebar $width dan skala $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: cargoTheme(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Scaffold(
                body: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: ShipmentStatusSummary(counts: counts),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(Card), findsNWidgets(6));
        final widths = tester
            .widgetList<SizedBox>(
              find.descendant(
                of: find.byType(ShipmentStatusSummary),
                matching: find.byType(SizedBox),
              ),
            )
            .where((w) => w.width != null)
            .map((w) => w.width)
            .toSet();
        expect(widths.length, 1);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('Laporan di HP dapat dimuat tanpa overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ApiClient.testingBaseUrl = 'https://api.example.test';
    ApiClient.transport = MockClient(
      (request) async => http.Response(jsonEncode({'docs': []}), 200),
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(theme: cargoTheme(), home: const DailyReportPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ShipmentStatusSummary), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('CAPTURE_UI')) {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        Directory('build/review').createSync(recursive: true);
        File(
          'build/review/report-mobile-1.3.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Admin dapat membuat kurir dengan kata sandi satu karakter', (
    tester,
  ) async {
    ApiClient.testingBaseUrl = 'https://api.example.test';
    var created = false;
    ApiClient.transport = MockClient((request) async {
      if (request.url.path.endsWith('/createCourier')) {
        expect(jsonDecode(request.body)['password'], 'a');
        created = true;
        return http.Response('{"uid":"k1"}', 201);
      }
      return http.Response('{"docs":[]}', 200);
    });
    await tester.pumpWidget(
      MaterialApp(theme: cargoTheme(), home: const ManageCouriersPage()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah kurir'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    for (final entry in [
      'Princeugha',
      'princeugha@example.com',
      '08123456789',
      'a',
    ].asMap().entries) {
      await tester.enterText(fields.at(entry.key), entry.value);
    }
    await tester.ensureVisible(find.text('Simpan'));
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(created, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
