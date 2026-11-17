import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haryata_cargo/widgets/resolve_shipment_dialog.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    void Function(ShipmentResolution?) result, {
    String? initial,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result(
                  await showDialog<ShipmentResolution>(
                    context: context,
                    builder: (_) => ResolveShipmentDialog(
                      couriers: Stream.value(const [
                        CourierChoice('k1', 'Kurir Satu'),
                      ]),
                      initialCourierId: initial,
                    ),
                  ),
                );
              },
              child: const Text('Buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
  }

  testWidgets('pengantaran ulang memerlukan alasan dan kurir aktif', (
    tester,
  ) async {
    ShipmentResolution? result;
    await open(tester, (r) => result = r);
    await tester.tap(find.text('Simpan tindak lanjut'));
    await tester.pumpAndSettle();
    expect(find.text('Catatan minimal 5 karakter'), findsOneWidget);
    expect(find.text('Pilih kurir aktif terlebih dahulu'), findsOneWidget);
    expect(result, isNull);
  });
  testWidgets('pengantaran ulang menyimpan kurir dan catatan', (tester) async {
    ShipmentResolution? result;
    await open(tester, (r) => result = r, initial: 'k1');
    await tester.enterText(find.byType(TextFormField), 'Antar kembali besok');
    await tester.tap(find.text('Simpan tindak lanjut'));
    await tester.pumpAndSettle();
    expect(result?.retry, true);
    expect(result?.courierId, 'k1');
    expect(result?.reason, 'Antar kembali besok');
  });
  testWidgets('retur dapat dicatat tanpa memilih kurir', (tester) async {
    ShipmentResolution? result;
    await open(tester, (r) => result = r);
    await tester.tap(find.byType(DropdownButtonFormField<bool>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tandai barang diretur').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'Penerima menolak paket',
    );
    await tester.tap(find.text('Simpan tindak lanjut'));
    await tester.pumpAndSettle();
    expect(result?.retry, false);
    expect(result?.courierId, isNull);
    expect(tester.takeException(), isNull);
  });
}
