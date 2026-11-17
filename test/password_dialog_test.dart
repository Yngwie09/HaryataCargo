import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:haryata_cargo/services/backend_client.dart';
import 'package:haryata_cargo/widgets/password_dialog.dart';

void main() {
  tearDown(() {
    ApiClient.transport.close();
    ApiClient.testingBaseUrl = null;
  });
  testWidgets('ubah sandi memvalidasi sandi lama, isian, dan konfirmasi', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPasswordDialog(context),
              child: const Text('Buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Isi kata sandi saat ini'), findsOneWidget);
    expect(find.text('Isi kata sandi'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
  });
  testWidgets('admin mereset sandi kurir melalui API PostgreSQL', (
    tester,
  ) async {
    ApiClient.testingBaseUrl = 'https://api.example.test';
    var called = false;
    ApiClient.transport = MockClient((request) async {
      called = true;
      expect(request.url.path, '/v1/actions/resetCourierPassword');
      expect(jsonDecode(request.body), {'uid': 'k1', 'password': 'a'});
      return http.Response('{"ok":true}', 200);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPasswordDialog(
                context,
                courierId: 'k1',
                courierName: 'Kurir Uji',
              ),
              child: const Text('Buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'a');
    await tester.enterText(fields.at(1), 'a');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(called, true);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
