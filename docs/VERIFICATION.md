# Hasil verifikasi — 27 Oktober 2026

Pembaruan 31 Oktober 2026: backend aktif sudah PostgreSQL Railway. Lihat [laporan migrasi](POSTGRES-MIGRATION-2026-10-31.md) dan [14 pemeriksaan server](POSTGRES-LIVE-TEST.json). Isi Firebase di bawah merupakan catatan historis.

Pembaruan 29 Oktober 2026: APK Android 1.1.0+2 berhasil dibangun dan tanda tangannya valid. Lihat [laporan Android terbaru](ANDROID-TEST-2026-10-29.md). Pernyataan lingkungan/perangkat di bawah mencatat pemeriksaan sebelumnya.

Lingkungan: Flutter 3.47.8 stable, Dart 3.13.7, Node.js 22.21.0, Windows. Target: Android admin/kurir; web admin tambahan.

## Hasil terbaru

- `flutter analyze --no-pub`: **No issues found**.
- `flutter test --no-pub --concurrency=1`: **39 tes lulus**.
- `node --test functions/test/validation.test.js functions/test/maps-loader.test.js`: **14 tes lulus**.
- `flutter build web --release --no-pub --optimization-level=2 --no-wasm-dry-run --no-web-resources-cdn`: **berhasil**, 106,4 detik. Termasuk kompilasi runtime JS interop untuk Google Maps.
- Pemeriksaan sintaks JavaScript/PowerShell, JSON/XML, dan whitespace diff: lulus.
- Render UI dashboard desktop/ponsel, login, dan formulir serah terima diperiksa. Screenshot tersedia di `docs/screenshots/`.

## Cakupan tes tracking

- Stream GPS tetap aktif ketika write pertama offline/timeout.
- Sinkronisasi pulih setelah gagal tanpa membuat listener ganda.
- Antrean lambat menyimpan posisi terbaru; sampel lama tidak menimpa sampel baru.
- GPS tertunda dari sesi lama tidak menghidupkan kembali atau menghentikan sesi baru.
- Dua permintaan mulai bersamaan hanya membuat satu stream GPS.
- Beralih ke background selama menunggu GPS tidak memulai foreground service secara ilegal.
- Adapter pengiriman lokasi → dokumen server → model marker menghasilkan status terkini; stop mempertahankan koordinat terakhir.
- Koordinat invalid, NaN/Infinity, cache, timestamp hilang, dan jam perangkat melenceng ditangani dengan aman.
- Maps loader: key kosong, jaringan gagal, timeout, callback terlambat, dan penolakan otorisasi.

Tes di atas memakai adapter GPS/penyimpanan terkontrol dan VM JavaScript. Ini belum membuktikan koneksi perangkat fisik ke Google/Firebase produksi.

## Belum dibuktikan pada cloud/perangkat

- 19 tes Firestore/Storage Rules disiapkan pada CI terpisah. Emulator tidak dijalankan pada laptop 6 GB; job CI belum dijalankan dari sesi ini.
- Firebase baru, billing, bucket, Authentication, Maps keys, domain, dan admin pertama belum dihubungkan sesuai keputusan pengguna.
- APK release belum dibangun: Android SDK, signing, dan konfigurasi proyek baru belum tersedia. Workflow APK disiapkan untuk tahap tersebut.
- Kamera native, Maps produksi, izin background, dan pembaruan lokasi saat layar terkunci perlu diuji menggunakan HP fisik.

Gunakan `docs/TRACKING.md` dan `docs/ACCEPTANCE.md` untuk pembuktian HP → Firestore → web admin. Panduan rilis berada di `docs/DEPLOYMENT.md`.

Build pratinjau lokal terbaru: **berhasil**, 118,2 detik. Loader Maps tidak dipanggil pada pratinjau; artefak tetap bertanda PREVIEW_ONLY.


## Penyempurnaan menu Android untuk skripsi

Draft nama/catatan/tiga foto diuji dengan penyimpanan file nyata, termasuk pemulihan backup, isolasi akun/pengiriman, dan autosave. Dialog pengantaran ulang/retur diuji. Pencarian resi lengkap memakai server; status Tertunda dan Retur masuk ke filter serta laporan. Ekspor Android memakai dialog Simpan sebagai. APK skripsi disiapkan melalui tools/build-skripsi.ps1 atau workflow APK skripsi tanpa keystore release. APK native belum dibangun/diuji pada HP sampai konfigurasi Firebase/Maps serta lingkungan Android tersedia.
