import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:haryata_cargo/core/ui.dart';
import 'package:haryata_cargo/screens/admin_home.dart';
import 'package:haryata_cargo/screens/login_page.dart';
import 'package:haryata_cargo/screens/preview_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final root = Platform.environment['FLUTTER_ROOT'] ?? '../.tools/flutter';
    final file = File(
      '$root/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
    );
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      final loader = FontLoader('Roboto')
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    final icons = File(
      '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    );
    if (icons.existsSync()) {
      final loader = FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(await icons.readAsBytes())));
      await loader.load();
    }
  });
  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_UI')) return;
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build/review').createSync(recursive: true);
      File(
        'build/review/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final width in [360.0, 1280.0]) {
    testWidgets('Dashboard adaptif pada lebar $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: cargoTheme(),
            home: const AdminHome(preview: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ruang kerja admin'), findsOneWidget);
      expect(find.text('Buat pengiriman'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, key, 'dashboard-${width.round()}');
    });
  }
  testWidgets('Pratinjau tidak memerlukan API dan menandai mode baca saja', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(theme: cargoTheme(), home: const PreviewPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('PRATINJAU LOKAL'), findsOneWidget);
    await tester.tap(find.text('Serah terima'));
    await tester.pumpAndSettle();
    expect(find.text('Bukti serah terima'), findsOneWidget);
    expect(find.text('Foto tanda terima'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'delivery-mobile');
  });
  testWidgets('Login pada layar desktop', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(theme: cargoTheme(), home: const LoginPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'login-desktop');
  });
}
