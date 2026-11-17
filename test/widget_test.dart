import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haryata_cargo/screens/login_page.dart';
import 'package:haryata_cargo/core/shipment_policy.dart';
import 'package:haryata_cargo/core/ui.dart';

void main() {
  test('Resi dinormalisasi dan tidak menerima spasi / path', () {
    expect(normalizeResi('  hc-1234  '), 'HC-1234');
    expect(validResi('HC-1234'), isTrue);
    for (final invalid in ['abc', 'HC/1234', 'HC 1234', '', 'A' * 41]) {
      expect(validResi(invalid), isFalse);
    }
  });
  test('Status tidak dapat melompati atau mengulang penyelesaian', () {
    expect(canTransition('Pending', 'Proses'), isTrue);
    expect(canTransition('Pending', 'Batal'), isTrue);
    expect(canTransition('Proses', 'Selesai'), isTrue);
    expect(canTransition('Pending', 'Selesai'), isFalse);
    expect(canTransition('Selesai', 'Proses'), isFalse);
    expect(canTransition('Selesai', 'Selesai'), isFalse);
    expect(canTransition('Batal', 'Proses'), isFalse);
    expect(canTransition('Proses', 'Tertunda'), isTrue);
    expect(canTransition('Tertunda', 'Pending'), isTrue);
    expect(canTransition('Tertunda', 'Retur'), isTrue);
    expect(canTransition('Tertunda', 'Selesai'), isFalse);
    expect(canTransition('Retur', 'Proses'), isFalse);
  });
  test('Ketiga kategori foto wajib ada', () {
    expect(completeProof({'receipt': 'a', 'recipient': 'b'}), isFalse);
    expect(
      completeProof({'receipt': 'a', 'recipient': 'b', 'parcel': ''}),
      isFalse,
    );
    expect(
      completeProof({'receipt': 'a', 'recipient': 'b', 'parcel': 'c'}),
      isTrue,
    );
  });
  testWidgets('Login memvalidasi input sebelum mengakses API', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.tap(find.text('Masuk'));
    await tester.pump();
    expect(find.text('Masukkan email yang valid'), findsOneWidget);
    expect(find.text('Kata sandi wajib diisi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Login tetap terbaca pada layar sempit dengan teks besar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const LoginPage(),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Status memiliki label yang jelas', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: StatusBadge('Selesai'))),
    );
    expect(find.text('Selesai'), findsOneWidget);
  });
}
