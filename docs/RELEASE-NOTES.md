# Paket rilis: Haryata Cargo

Target: Android kurir dan web admin. Penggunaan lokal paling ringan: browser + server file statis Node, tanpa emulator atau database lokal. Backend baru dihubungkan setelah paket aplikasi diserahkan.

## Batas konfigurasi

`config/local.json`, `android/app/google-services.json`, keystore, dan akun Firebase baru belum diisi. Ini disengaja: pengguna memilih menghubungkan cloud nanti. Jangan menggunakan file konfigurasi proyek Firebase lama.

## Jalankan pratinjau tanpa cloud

```powershell
powershell -ExecutionPolicy Bypass -File tools/local.ps1 -Preview
```

Build dilakukan sekali. Setelahnya cukup `node tools/serve.cjs 8085`. Pratinjau hanya menampilkan UI; tidak memproses transaksi atau lokasi. Untuk operasional, build ulang menggunakan konfigurasi Firebase baru tanpa `-Preview`.

## Hubungkan aplikasi operasional

Ikuti README → Siapkan proyek Firebase BARU → Google Maps → Backend dan admin pertama. Untuk APK, gunakan workflow GitHub Actions agar laptop tidak menjalankan build Android yang berat.

## Sifat pengujian

Analisis dan unit/widget test memeriksa kode dan UI. Build web memeriksa kompilasi. Uji Security Rules disiapkan dalam CI agar tidak menjalankan Firebase emulator di laptop 6 GB. Uji lokasi di HP fisik dan proyek baru tetap diperlukan; ikuti `docs/ACCEPTANCE.md`. Jangan mengartikan artefak pratinjau atau kompilasi sebagai bukti bahwa Maps key, izin OS, dan backend produksi sudah aktif.

## Membuka ulang dengan beban minimum

Setelah build lokal tersedia:

```powershell
powershell -ExecutionPolicy Bypass -File tools/local.ps1 -ServeOnly
```

Perintah ini langsung menjalankan server file Node, tanpa Flutter compiler. Pratinjau memakai aset renderer lokal, sehingga tampilan dasarnya tidak perlu mengambil renderer dari CDN. Operasi Firebase/Maps pada mode operasional tetap memerlukan internet.

## Artefak penyerahan

- `dist/HaryataCargo-source.zip`: source, aturan Firebase, backend, tes, panduan, skrip lokal, dan workflow CI. Tidak menyertakan SDK, `node_modules`, kredensial, atau keystore.
- `dist/HaryataCargo-preview.zip`: build pratinjau siap disajikan dengan Node.js. Ekstrak lalu jalankan `node tools/serve.cjs 8085`; tidak memerlukan Flutter SDK untuk membuka tampilannya.

Hosting memiliki hook predeploy yang menjalankan preflight. Build pratinjau dan konfigurasi cloud yang belum lengkap ditolak sebelum deployment hosting.

## Pembaruan tracking lanjutan

GPS tidak lagi menunggu server sebelum foreground stream berjalan. Antrean offline dibatasi satu write yang belum dikonfirmasi dan satu fix terbaru. Sesi/startup/background dijaga, cache kosong tidak mematikan tracking, dan watchdog memulihkan stream saat aplikasi terbuka. Dashboard memiliki follow-camera, pencarian, status cache/freshness, koordinat, serta error SDK Maps yang jelas. Menu Periksa pelacakan membantu uji GPS dan lokasi yang diterima server.

Verifikasi terbaru: 28 tes Flutter dan 14 tes JavaScript lulus; analyzer bersih; build web operasional berhasil. Koneksi cloud/HP nyata tetap menunggu konfigurasi proyek baru.

## Fokus skripsi Android

Admin dan kurir sama-sama dapat menggunakan Android. Penambahan terakhir: draft tiga foto tersimpan lokal, pencarian resi lengkap lintas data, status Tertunda, penanganan pengantaran ulang/retur, laporan enam status, dan pemilihan lokasi ekspor CSV Android. Panduan praktis: docs/SKRIPSI.md. APK pengujian dapat dibuat dengan tools/build-skripsi.ps1 atau workflow APK skripsi; tidak membutuhkan rilis Play Store.
