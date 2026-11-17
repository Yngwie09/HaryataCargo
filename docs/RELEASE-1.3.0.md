# Haryata Cargo 1.3.0

## Perubahan

- Ringkasan laporan memakai kartu dengan lebar seimbang: dua kolom pada HP, tiga pada layar lebar, dan satu ketika teks diperbesar. Rincian laporan dapat membuka detail pengiriman.
- Dashboard admin menampilkan hitungan status langsung dari server dan pintasan Pending, Proses, serta Tertunda.
- Pembuatan, reset, dan perubahan sandi menerima karakter bebas tanpa syarat huruf besar, angka, atau panjang minimum. Kolom sandi dapat ditampilkan/disembunyikan dan pesan kesalahan tidak terpotong.
- Riwayat pengiriman kurir memeriksa kepemilikan melalui pengiriman induk. Filter SQL kolom kurir tidak lagi diterapkan pada tabel riwayat.
- Foto diperiksa dengan decoder di aplikasi dan server. Gambar rusak ditolak sebelum disimpan, orientasi dinormalisasi, dan metadata gambar dibuang. Detail foto menyediakan muat ulang, tampilan utuh, serta perbesaran.
- Nama produk tetap Haryata Cargo. Label database dan teks demonstrasi dihapus dari tampilan operasional. Komponen tanggal serta dialog standar memakai bahasa Indonesia.
- Paket Dart dinamai `haryata_cargo`; komponen bersama dipisahkan ke widgets, kode backend diformat konsisten, dan backend Firebase lama diarsipkan ke `legacy/firebase`.

## Pelacakan langsung

Peta menerima snapshot melalui SSE terautentikasi. Satu pembacaan database per detik melayani seluruh dashboard yang terhubung; tidak ada polling SQL terpisah untuk setiap admin. Saat pengantaran aktif, Android meminta sampel GPS setiap dua detik, dengan heartbeat 15 detik. Frekuensi aktual bergantung pada GPS, jaringan, dan sistem Android.

Marker navigasi bergerak halus selama 1,8 detik di antara dua posisi yang sudah diterima, berputar mengikuti heading, dan kamera dapat mengikuti kurir terpilih. Tidak ada prediksi gerak melewati koordinat terakhir. GPS/sinkronisasi yang berusia 45 detik ditandai terlambat. Sambungan pulih otomatis dengan backoff dan snapshot REST bila stream terputus. Saat halaman ditutup, koneksi streaming serta timer dibersihkan.

Sambungan SSE di Railway sudah diuji untuk snapshot awal, penolakan akses tanpa login/kurir, dan pencabutan sesi admin.

## Data

Data lama disalin ke berkas lokal yang diabaikan Git sebelum penggantian. Akun admin dipertahankan. Lima kurir baru: princeugha, chasy, wonzz, yngganz, dan neoaja. Ada 15 contoh pengiriman: 11 Pending, 2 Tertunda, 1 Retur, dan 1 Batal. Tidak ada foto rusak atau lokasi aktif buatan yang ikut dimasukkan. Akun serta kata sandi dibagikan lewat berkas akun terpisah, bukan paket sumber.

## Verifikasi

71 tes Flutter dan 18 tes backend lulus. Analyzer Flutter bersih. Empat belas kelompok pemeriksaan langsung Railway lulus, termasuk riwayat yang dibaca kurir, tiga foto yang dapat didekode, penyelesaian idempoten, lokasi terakhir, dan pembatasan akses. Hasil integrasi ada di `POSTGRES-LIVE-TEST.json`.

Pengujian lokasi melalui API bukan pengganti pengujian GPS perangkat. Kamera, tampilan Maps native, izin HP, ekspor melalui dialog Android, serta pelacakan ketika layar terkunci tetap perlu dicoba pada HP pengguna. Build yang dibagikan ditujukan untuk Android ARM64, minimal Android 7, memakai sertifikat laptop yang sebelumnya didaftarkan pada key Maps.
