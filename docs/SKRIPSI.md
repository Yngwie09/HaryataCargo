# Panduan Haryata Cargo Android

Versi 1.3.0 memakai API dan PostgreSQL Railway. APK Firebase versi 1.1.0 tidak otomatis berpindah database: pasang APK PostgreSQL terbaru. Tidak perlu emulator atau server/database di laptop untuk memakai APK online.

## Akun dan pemasangan

Email/sandi admin dan kurir contoh tersimpan di `config/railway.private.json`, serta berkas akun yang menyertai APK dalam Downloads. Masuk menggunakan akun aplikasi tersebut, bukan akun Google/Railway. Admin dapat membuat kurir baru dan mereset sandinya. Pengguna dapat mengubah sandi sendiri dari pengaturan.

Pasang APK pada HP ARM64 Android 7+. Sertifikat debug laptop tetap memakai package `id.haryata.cargo`, SHA-1:

`33:C4:3F:AA:63:CD:19:AB:F5:0C:B0:C6:DB:2B:28:16:C2:8B:2C:6F`

Key Maps Android harus mengizinkan package/SHA-1 tersebut dan Maps SDK for Android harus aktif pada proyek pemilik key. Backend/database tidak membutuhkan Firebase lagi.

## Urutan uji seluruh menu

1. Login admin → Buat pengiriman dengan resi baru, penerima, telepon, alamat, berat/koli dan kurir aktif.
2. Pengiriman → cari resi lengkap, filter status, edit paket Pending, dan batalkan paket contoh bila perlu.
3. Kelola kurir → tambah akun, edit profil, reset sandi dan aktif/nonaktif. Penonaktifan ditolak ketika masih ada tugas Pending/Proses.
4. Login kurir pada HP lain → mulai tugas Pending → izinkan lokasi akurat/GPS. Gunakan data/foto contoh untuk demonstrasi.
5. Admin → Pantau kurir → lokasi baru diterima melalui sambungan server push SSE. Android meminta GPS sekitar setiap 2 detik dan heartbeat setiap 15 detik saat diam; kondisi OS/internet menentukan waktu aktual.
6. Kurir → Periksa pelacakan → uji GPS dan sinkronisasi server. Periksa koordinat serta jam fix/sinkron, termasuk setelah layar dikunci.
7. Serah terima → isi penerima dan tiga foto. Tutup/buka formulir untuk memeriksa draft lokal, lalu selesaikan. Foto disimpan sebagai BYTEA PostgreSQL dan dibaca melalui API terautentikasi.
8. Uji paket lain: tunda → admin antar ulang atau retur. Riwayat ditulis server dalam transaksi yang sama.
9. Laporan → pilih periode WITA/dasar tanggal → ekspor CSV melalui dialog Simpan sebagai di Android.
10. Pengaturan → ubah sandi sendiri, izin lokasi dan keluar. Kurir tidak dapat keluar ketika masih memiliki tugas Proses.

## Data contoh

Tersedia lima kurir: princeugha, chasy, wonzz, yngganz, dan neoaja. Sebanyak 15 pengiriman memiliki resi HC, informasi penerima, alamat Manado, pengirim, berat, koli, serta catatan penanganan. Sebelas Pending, dua Tertunda, satu Retur, dan satu Batal. Foto serta lokasi pengantaran diisi melalui aktivitas nyata pengguna; tidak ada gambar mini rusak atau marker GPS buatan yang ditampilkan sebagai lokasi aktif.

## Yang sudah dan belum dibuktikan

71 tes Flutter lulus; 14 pemeriksaan langsung Railway lulus, termasuk penyimpanan/pembacaan foto dan posisi admin. Build/signature APK diperiksa pada laporan versi terkait. Kamera, izin native, Google Maps di HP, CSV native, dan tracking layar terkunci masih memerlukan pengujian fisik. Jangan menyimpulkan semuanya berhasil hanya dari build atau koordinat contoh.
