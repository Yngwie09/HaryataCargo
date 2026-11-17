# Pelacakan kurir: konfigurasi dan pembuktian

Pelacakan operasional menghubungkan GPS HP Android, dokumen `courier_locations/UID` di Firestore, dan Google Maps pada web admin. Pratinjau lokal tidak menjalankan ketiga layanan tersebut.

## Alur yang diperkuat

- GPS dan foreground notification dimulai tanpa menunggu penulisan pertama ke server. Koneksi putus tidak membatalkan stream.
- Refresh GPS berkala membantu pembaruan saat kurir diam. Posisi lama tidak menimpa sampel lebih baru; antrean menyimpan posisi terbaru.
- Pemulihan berjalan saat aplikasi kembali ke depan. Watchdog memeriksa stream yang berhenti. Startup foreground service ditahan bila aplikasi masuk background selama menunggu GPS.
- Cache kosong tidak dianggap sebagai konfirmasi tugas selesai. Pelacakan berhenti setelah tidak ada paket Proses pada snapshot server.
- Sesi lama tidak boleh menghidupkan kembali atau menghentikan stream sesi baru.
- Admin melihat waktu GPS, sinkronisasi, akurasi, dan koordinat. Cache, fix terlambat, dan jam perangkat melenceng tidak ditampilkan sebagai lokasi terkini.
- Kamera peta dapat mengikuti kurir terpilih. Pencarian dan tombol seluruh posisi tersedia.
- Maps dimuat asinkron. Key kosong, penolakan otorisasi, jaringan gagal, dan timeout ditampilkan tanpa menghilangkan daftar koordinat.

## Persiapan operasional

1. Hubungkan Firebase baru: Authentication Email/Password, Firestore, Storage, Rules/indeks, Functions, dan profil kurir aktif.
2. Aktifkan Maps JavaScript API, billing, dan key yang dibatasi ke domain Hosting serta localhost yang digunakan.
3. APK memakai package `id.haryata.cargo`, konfigurasi Firebase Android yang sesuai, izin lokasi presisi, dan foreground notification. Halaman Maps Android memerlukan Maps SDK for Android dan key dengan package + SHA-1 release yang sesuai.
4. Aktifkan jam otomatis dan internet pada HP/laptop.

## Uji dua perangkat

1. Admin membuat kurir dan paket yang ditugaskan kepadanya.
2. Kurir login di HP fisik; buka paket dan Mulai pengantaran saat aplikasi terbuka. Izinkan GPS.
3. Buka **Periksa pelacakan**. Periksa GPS, izin, akses server; ketuk **Sinkronkan lokasi**.
4. Cocokkan koordinat dan waktu posisi server pada HP dengan daftar/marker di admin. Pilih kurir dan aktifkan Ikuti pergerakan.
5. Bergerak, lalu diam beberapa menit. Matikan internet 3–5 menit: posisi terakhir tetap terlihat dan berubah menjadi terlambat. Nyalakan internet: pastikan fix terbaru tampil kembali.
6. Uji layar terkunci 10–15 menit dan berpindah aplikasi. Periksa foreground notification serta pembaruan pada merek/versi Android yang akan digunakan.
7. Dengan dua paket Proses, selesaikan satu: lokasi tetap aktif. Selesaikan paket terakhir: pelacakan berhenti dan posisi terakhir dipertahankan.
8. Uji izin ditolak, GPS mati, dan force-stop secara terpisah. Kondisi sebenarnya harus ditampilkan; setelah force-stop buka aplikasi untuk memulihkan.

Catat hasil perangkat nyata sebelum menyatakan pelacakan produksi berhasil. Billing, domain/package, runtime permissions, pembatasan foreground service, dan kebijakan baterai perangkat tidak dapat dibuktikan hanya dari kompilasi atau tes mock.

Referensi resmi:
- https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- https://developers.google.com/maps/documentation/javascript/error-messages
