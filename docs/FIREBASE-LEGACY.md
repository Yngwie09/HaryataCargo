# Haryata Cargo

**Fokus saat ini: demonstrasi skripsi di Android untuk admin dan kurir.** Mulai dari [panduan skripsi](docs/SKRIPSI.md). APK pengujian dapat dipasang langsung ke HP; publikasi Play Store tidak diperlukan.

Aplikasi skripsi **Android untuk admin dan kurir**, dengan **web admin sebagai pilihan tambahan**, dengan Firebase Authentication, Firestore, Cloud Storage, Cloud Functions, dan Google Maps.

## Fitur

- Sesi login otomatis, pemeriksaan role dan akun aktif, pemulihan kata sandi.
- Admin membuat akun kurir melalui fungsi server, mengedit profil, mengaktifkan/menonaktifkan akses.
- Resi unik dalam transaksi, data pengirim/penerima, telepon, alamat, berat, koli, catatan, penugasan kurir.
- Kurir hanya melihat pengirimannya; transisi Pending → Proses → Selesai; admin dapat membatalkan Pending.
- Bukti pengiriman wajib: **foto tanda terima, foto penerima, foto barang**, nama penerima aktual, catatan, persetujuan, dan koordinat serah terima.
- Server memeriksa keberadaan dan metadata ketiga objek foto sebelum menerima status Selesai. Klien tidak dapat menulis penyelesaian langsung.
- Lokasi kurir saat pengantaran: stream GPS, foreground notification Android, refresh berkala saat diam, pemulihan saat kembali ke aplikasi, indikator lokasi terakhir / koneksi terlambat di dashboard.
- Riwayat perubahan milik server; kendala pengiriman; arah dan panggilan penerima.
- Laporan per periode WITA berdasarkan tanggal dibuat/selesai dan ekspor CSV yang menetralkan formula spreadsheet.
- UI adaptif, validasi formulir, status loading/error/kosong, pagination daftar.

## Mode paling ringan untuk laptop 6 GB RAM

**Rekomendasi:** Firebase di cloud, admin di browser, kurir di HP Android fisik. Tidak perlu Android emulator, Docker, database lokal, atau Firebase Emulator Suite untuk penggunaan sehari-hari.

1. Penggunaan paling ringan: buka URL Firebase Hosting setelah rilis. Tidak ada proses build/server di laptop.
2. Lokal bila dibutuhkan: jalankan `tools/local.ps1` sekali untuk membuat build web, kemudian server Node menyajikan file statis pada `http://localhost:8085`.
3. Setelah pernah build, langsung jalankan `node tools/serve.cjs 8085` tanpa build ulang. Hentikan dengan Ctrl+C.
4. Pembuatan APK bisa dijalankan melalui workflow GitHub Actions, agar kompilasi Android tidak membebani laptop.
5. Gradle dibatasi satu worker, heap 1.536 MB, tanpa daemon dan build paralel. Tes Flutter dijalankan `--concurrency=1`.

Mode lokal ini tetap menggunakan Firebase cloud; bukan mode operasional offline sepenuhnya. Data cache bisa ditampilkan ketika koneksi terputus, tetapi perubahan status dan pengunggahan foto memerlukan internet. Tracking tidak boleh dianggap terkini ketika indikator sudah terlambat.

## Prasyarat pengembangan

- Flutter **3.47.8 stable / Dart 3.13.7** (versi verifikasi workspace), Node.js 22.
- SDK Flutter yang diunduh dalam pengerjaan ini tersedia di `../.tools/flutter`. Atau set `FLUTTER_ROOT` ke SDK Anda.
- Android SDK + JDK 17 untuk build Android lokal; HP fisik dengan USB debugging untuk pengujian.
- Firebase CLI dijalankan melalui `npx firebase-tools@15` (atau instal CLI yang sesuai Node 22).

Jika `flutter pub get` pada Windows mengeluh tentang symlink desktop, gunakan Developer Mode Windows **hanya bila diperlukan untuk target desktop**; target produk adalah Android dan web. Perintah dapat selesai mengambil dependensi meskipun registrasi plugin Windows gagal. Jangan menganggap error build lain sebagai sukses. Workflow Linux menjalankan langkah ini tanpa batasan Windows.

## Siapkan proyek Firebase BARU

Proyek lama tidak digunakan sebagai default. Tidak ada `.firebaserc` produksi dalam repo.

1. Buat proyek melalui Firebase Console dengan ID yang Anda pilih; aktifkan paket penagihan yang disyaratkan layanan Storage/Functions. Atur budget alerts di Google Cloud.
2. Buat Firestore database `(default)` di lokasi yang sesuai operasional. Functions menggunakan `asia-southeast2`.
3. Authentication → Sign-in method → aktifkan **Email/Password**. Tambahkan domain Hosting dan `localhost` pada Authorized domains bila diperlukan.
4. Aktifkan Cloud Storage. Catat nama bucket dari console, jangan menebak suffix bucket.
5. Daftarkan aplikasi Android dengan package **`id.haryata.cargo`**, unduh `google-services.json` ke `android/app/google-services.json`.
6. Daftarkan aplikasi Web. Salin `config/local.example.json` menjadi `config/local.json`, isi seluruh konfigurasi Web dari Firebase Console dan nama bucket yang benar.
7. Konfigurasi lokal dan kredensial/signing diabaikan Git. API key Web/Maps yang dibundel aplikasi bukan pengganti Security Rules.
8. Jalankan `firebase login` atau `npx firebase-tools@15 login` di terminal Anda; gunakan proyek baru secara eksplisit pada setiap deployment dengan `--project PROJECT_ID`.

Tidak diperlukan service account dalam aplikasi Flutter. **Jangan menaruh service account, password, atau kunci signing ke Git.**

## Google Maps

Buat dua API key terpisah pada proyek Google Cloud yang sama dan aktifkan billing:

- **Web:** aktifkan Maps JavaScript API; batasi key ke API tersebut dan HTTP referrers domain Hosting + `http://localhost:8085/*`. Masukkan ke `GOOGLE_MAPS_WEB_API_KEY`.
- **Android:** aktifkan Maps SDK for Android; batasi ke package `id.haryata.cargo` dan SHA-1 sertifikat debug/release yang benar. Masukkan ke `GOOGLE_MAPS_ANDROID_API_KEY`. Tambahkan SHA-1 Play App Signing jika distribusi melalui Play.
- Key Android dibaca Gradle dari environment `GOOGLE_MAPS_API_KEY`; skrip build mengisinya dari konfigurasi lokal. Key Web disisipkan pada hasil build oleh skrip.

`flutter run -d chrome` langsung tidak menyisipkan key Maps pada HTML. Gunakan skrip lokal atau workflow agar peta web dikonfigurasi dengan benar. Peta kosong / For development purposes only biasanya perlu pemeriksaan billing, API aktif, pembatasan key, dan log browser.

## Backend dan admin pertama

```powershell
cd functions
npm ci
npm run check
npm test
cd ..
npx firebase-tools@15 deploy --only firestore,storage,functions --project PROJECT_ID
```

Saat deploy aturan Storage yang mengakses Firestore, berikan izin integrasi lintas layanan yang diminta Firebase. Tunggu indeks selesai dibuat sebelum menguji query gabungan.

Untuk admin pertama:

1. Buat akun Authentication Email/Password lewat Firebase Console.
2. Salin UID akun itu.
3. Buat dokumen Firestore `users/UID` dari console dengan field `email` (email akun), `name` (nama admin), `role` = `admin`, `active` = `true` (boolean).
4. Login melalui dashboard web. Buat kurir dari menu Kelola kurir.

Klien tidak dapat membuat atau menaikkan role sendiri. Pembuatan admin selanjutnya adalah tindakan administratif melalui console / Admin SDK dengan akses pemilik proyek.

## Lokal

```powershell
# Dari folder HaryataCargo, setelah mengisi konfigurasi proyek baru
..\.tools\flutter\bin\flutter.bat pub get
powershell -ExecutionPolicy Bypass -File tools/local.ps1
```

Terminal menampilkan URL lokal. Menjalankan server ini hanya membuka antarmuka loopback laptop (`127.0.0.1`), bukan mempublikasikan aplikasi ke jaringan.

## Android

1. Unduh `google-services.json` proyek baru seperti di atas.
2. Buat release keystore, misalnya `keytool -genkeypair -v -keystore C:\secure\haryata-release.jks -alias haryata -keyalg RSA -keysize 2048 -validity 10000`.
3. Salin `android/key.properties.example` ke `android/key.properties` lalu isi dengan lokasi serta password keystore lokal. Simpan cadangan keystore dengan aman.
4. Jalankan `powershell -ExecutionPolicy Bypass -File tools/build-android.ps1`.
5. Pasang `build/app/outputs/flutter-apk/app-release.apk` ke HP ARM64. Untuk perangkat lain, ubah target ABI pada skrip. Untuk Play, gunakan `flutter build appbundle --release` dengan konfigurasi dan signing yang sama.

Release sengaja gagal bila signing atau Maps key kosong. Tidak ada fallback signing debug untuk release.

## Deploy web

Setelah `tools/local.ps1` menyelesaikan build, hentikan server dengan Ctrl+C, lalu:

```powershell
npx firebase-tools@15 deploy --only hosting --project PROJECT_ID
```

Jangan memakai `flutter build web` langsung untuk deployment tanpa mengganti placeholder Maps. `tools/preflight.cjs` memeriksa konfigurasi, package Android, dan placeholder yang belum diisi sebelum rilis. Deployment memerlukan akses akun proyek; kode repo tidak otomatis membuat resource / billing cloud.

## CI yang mengurangi beban laptop

- `quality.yml`: format, analyzer, tes Flutter, unit test backend, build web; serta security rules pada runner terpisah.
- `android-release.yml`: manual workflow untuk APK release. Secret yang diperlukan dijelaskan di `docs/DEPLOYMENT.md`.
- APK dapat diunduh dari artefak workflow; workflow tidak otomatis mengunggah aplikasi ke Play Store.

## Verifikasi operasional wajib

Lihat `docs/ACCEPTANCE.md`: gunakan dua akun kurir dan satu admin, uji pengiriman nyata, tiga foto, GPS saat diam/bergerak, layar terkunci, kehilangan internet, sesi, dan penolakan akses silang. Build sukses belum membuktikan izin GPS perangkat dan API key produksi sudah benar.

Android membatasi aplikasi yang dipaksa berhenti atau dihentikan sistem. Jangan menjanjikan tracking setelah force-stop atau saat HP mati. Dashboard mempertahankan posisi terakhir dengan penanda terlambat; kurir memulihkan tracking saat aplikasi kembali aktif. Uji kebijakan baterai pada merek HP yang benar-benar digunakan.

## Platform lain

iOS memerlukan macOS/Xcode, aplikasi Firebase iOS tersendiri, nilai `FIREBASE_*` untuk aplikasi iOS melalui dart define, konfigurasi Maps iOS, signing Apple, serta pengujian izin lokasi/kamera. iOS/desktop bukan target rilis utama dan belum dinyatakan lolos pengujian perangkat.
# Mode pratinjau tanpa Firebase

Bila cloud belum dihubungkan:

```powershell
powershell -ExecutionPolicy Bypass -File tools/local.ps1 -Preview
```

Pratinjau menampilkan dashboard, login, dan formulir serah terima secara baca saja. Tidak ada data pelanggan, proses login, upload, atau tracking. Penanda PRATINJAU LOKAL selalu terlihat. Untuk penggunaan nyata, isi konfigurasi proyek baru lalu jalankan skrip tanpa `-Preview`.

Setelah build pratinjau tersedia, membuka ulang hanya memerlukan `node tools/serve.cjs 8085`. Ini tidak menjalankan compiler atau emulator. Jangan deploy build pratinjau; preflight menolaknya.

Untuk membuka build yang sudah tersedia tanpa kompilasi ulang:

```powershell
powershell -ExecutionPolicy Bypass -File tools/local.ps1 -ServeOnly
```

Penanda DEBUG pada gambar di `docs/screenshots` berasal dari harness tes widget. Aplikasi menggunakan `debugShowCheckedModeBanner: false`.

## Penyempurnaan pelacakan

Lihat `docs/TRACKING.md` untuk menu Periksa pelacakan, pemulihan koneksi, indikator cache/jam perangkat, mode mengikuti kurir, diagnostik Maps, dan pembuktian HP → Firestore → peta admin.
