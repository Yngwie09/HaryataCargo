import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:haryata_cargo/services/backend_client.dart';
import 'package:haryata_cargo/widgets/proof_photo.dart';

void main() {
  tearDown(() {
    ApiClient.transport.close();
    ApiClient.testingBaseUrl = null;
  });
  testWidgets(
    'Foto dapat dimuat ulang setelah gangguan jaringan dan diperbesar',
    (tester) async {
      final bytes = await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 64, 64),
          Paint()..color = Colors.teal,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(64, 64);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        picture.dispose();
        return bytes;
      });
      ApiClient.testingBaseUrl = 'https://api.example.test';
      var calls = 0;
      ApiClient.transport = MockClient((request) async {
        calls++;
        return calls == 1
            ? http.Response('{"code":"unavailable"}', 503)
            : http.Response.bytes(
                bytes!.buffer.asUint8List(),
                200,
                headers: {'content-type': 'image/png'},
              );
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProofPhoto(
              path: 'proofs/k/s/1/receipt.png',
              label: 'Foto tanda terima',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Coba lagi'), findsOneWidget);
      await tester.tap(find.text('Coba lagi'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
