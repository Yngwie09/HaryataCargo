import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:haryata_cargo/services/drafts/draft_store_io.dart';

void main() {
  late Directory root;
  late FileDraftStore store;
  setUp(() async {
    final parent = await Directory(
      'build/test-drafts',
    ).absolute.create(recursive: true);
    root = await parent.createTemp('case-');
    store = FileDraftStore(() async => root);
  });
  tearDown(() async {
    final parent = await Directory('build/test-drafts').resolveSymbolicLinks();
    final target = await root.resolveSymbolicLinks();
    if (!target.startsWith(parent + Platform.pathSeparator)) {
      throw StateError('Unexpected cleanup target');
    }
    await root.delete(recursive: true);
  });
  test(
    'nama, catatan, dan tiga foto pulih setelah store dibuat ulang',
    () async {
      await store.saveFields('kurir1', 'S1', {
        'receivedBy': 'Budi',
        'note': 'Diterima di rumah',
        'consent': true,
      });
      for (final slot in ['receipt', 'recipient', 'parcel']) {
        await store.savePhoto(
          'kurir1',
          'S1',
          slot,
          Uint8List.fromList([255, 216, 1, 2]),
        );
      }
      final restored = await FileDraftStore(
        () async => root,
      ).read('kurir1', 'S1');
      expect(restored.fields['receivedBy'], 'Budi');
      expect(restored.photos.length, 3);
      expect(restored.photos['parcel'], [255, 216, 1, 2]);
    },
  );
  test('draft terpisah per akun dan pengiriman', () async {
    await store.saveFields('kurir1', 'S1', {'note': 'Satu'});
    await store.saveFields('kurir2', 'S1', {'note': 'Dua'});
    await store.saveFields('kurir1', 'S2', {'note': 'Tiga'});
    expect((await store.read('kurir1', 'S1')).fields['note'], 'Satu');
    expect((await store.read('kurir2', 'S1')).fields['note'], 'Dua');
    expect((await store.read('kurir1', 'S2')).fields['note'], 'Tiga');
  });
  test(
    'autosave berurutan tidak merusak metadata atau menimpa foto lain',
    () async {
      await Future.wait([
        store.saveFields('u', 's', {'note': 'Awal'}),
        store.savePhoto('u', 's', 'receipt', Uint8List.fromList([1, 2, 3])),
        store.savePhoto('u', 's', 'parcel', Uint8List.fromList([4, 5, 6])),
        store.saveFields('u', 's', {'note': 'Terakhir'}),
      ]);
      final d = await store.read('u', 's');
      expect(d.fields['note'], 'Terakhir');
      expect(d.photos.length, 2);
    },
  );
  test(
    'backup dipulihkan jika aplikasi terhenti saat pergantian file',
    () async {
      await store.saveFields('u', 's', {'note': 'Tersimpan'});
      final file = (await root.list(recursive: true).toList())
          .whereType<File>()
          .firstWhere((f) => f.path.endsWith('fields.json'));
      await file.rename('${file.path}.bak');
      expect(
        (await FileDraftStore(() async => root).read('u', 's')).fields['note'],
        'Tersimpan',
      );
    },
  );
  test(
    'metadata rusak tidak menghilangkan foto yang masih dapat dipulihkan',
    () async {
      await store.saveFields('u', 's', {'note': 'Ada'});
      await store.savePhoto('u', 's', 'receipt', Uint8List.fromList([1, 2]));
      final file = (await root.list(recursive: true).toList())
          .whereType<File>()
          .firstWhere((f) => f.path.endsWith('fields.json'));
      await file.writeAsString('{');
      final d = await store.read('u', 's');
      expect(d.fields, isEmpty);
      expect(d.photos['receipt'], [1, 2]);
    },
  );
  test('hapus satu draft tidak menyentuh draft akun lain', () async {
    await store.saveFields('a', 's', {'note': 'A'});
    await store.saveFields('b', 's', {'note': 'B'});
    await store.clear('a', 's');
    expect((await store.read('a', 's')).fields, isEmpty);
    expect((await store.read('b', 's')).fields['note'], 'B');
  });
  test(
    'slot tidak sah dan foto kebesaran ditolak; antrean tetap dapat dipakai',
    () async {
      await expectLater(
        store.savePhoto('a', 's', '../hack', Uint8List.fromList([1])),
        throwsArgumentError,
      );
      await expectLater(
        store.savePhoto('a', 's', 'receipt', Uint8List(5 * 1024 * 1024 + 1)),
        throwsArgumentError,
      );
      await store.saveFields('a', 's', {'note': 'Tetap bisa'});
      expect((await store.read('a', 's')).fields['note'], 'Tetap bisa');
    },
  );
  test(
    'karakter path pada identifier tidak keluar dari penyimpanan draft',
    () async {
      await store.saveFields('../a', '../../s', {'note': 'Aman'});
      expect((await store.read('../a', '../../s')).fields['note'], 'Aman');
      final directories = (await root.list().toList())
          .whereType<Directory>()
          .toList();
      expect(directories.length, 1);
    },
  );
}
