# Haryata Cargo

Aplikasi manajemen pengiriman untuk admin dan kurir Android. Backend menggunakan Node.js dan PostgreSQL. Peta menggunakan Google Maps.

## Arsitektur

Android/web Flutter → API Node.js → PostgreSQL. Foto tanda terima, penerima, dan barang disimpan sebagai BYTEA di tabel `proof_photos`, dengan metadata yang tercatat pada pengiriman.

Login memakai akun aplikasi, hash scrypt, dan token sesi yang disimpan sebagai digest pada server. Perubahan status/penugasan/resi diperiksa dalam transaksi PostgreSQL dan riwayat ditulis pada transaksi yang sama. Lokasi terbaru dipublikasikan kurir melalui API; peta menerima pembaruan melalui sambungan server push SSE. Sampel GPS lama tidak dapat menimpa posisi baru.

## Mulai menguji

- Lihat [panduan Android skripsi](docs/SKRIPSI.md).
- Akun admin dan lima kurir sudah tersedia: princeugha, chasy, wonzz, yngganz, dan neoaja. Kredensial lokal tersimpan di `config/railway.private.json` dan tidak dimasukkan ke Git/paket sumber.
- Tersedia 15 contoh pengiriman dengan resi `HC-...`, alamat Manado, serta catatan operasional. Lokasi mulai muncul setelah kurir memulai tugas dari HP.
- Akun Firebase lama tidak dipakai. Pengguna menyatakan proyek lama kosong/hanya percobaan; tidak ada data nyata yang disalin atau dihapus dari Firebase.

## Menjalankan Android dari GitHub

Siapkan Flutter, Android SDK, JDK 17, Node.js 22, dan PostgreSQL. Untuk repo yang sudah di-clone, jalankan perintah berikut dari folder `HaryataCargo`.

```powershell
git pull --ff-only origin main
if (!(Test-Path config/local.json)) { Copy-Item config/local.example.json config/local.json }
if (!(Test-Path backend/.env)) { Copy-Item backend/.env.example backend/.env }
```

Isi `backend/.env` dengan `DATABASE_URL` untuk database PostgreSQL yang sudah dibuat serta `ADMIN_EMAIL` dan `ADMIN_PASSWORD` untuk login awal. Jalankan API dari folder `backend`.

```powershell
npm ci
node --env-file=.env src/server.js
```

Isi `config/local.json` dengan `API_BASE_URL` dan `GOOGLE_MAPS_ANDROID_API_KEY`. Untuk HP di Wi-Fi yang sama, gunakan alamat IP LAN komputer backend, misalnya `http://192.168.1.20:3000`. Untuk server publik gunakan URL HTTPS tanpa `/v1`. Key Android harus mengizinkan Maps SDK for Android, package `id.haryata.cargo`, dan SHA-1 sertifikat APK. `GOOGLE_MAPS_WEB_API_KEY` hanya diperlukan untuk admin web.

`google-services.json` tidak diperlukan oleh versi PostgreSQL. Berkas Firebase/rules/functions lama dipisahkan ke `legacy/firebase/` sebagai arsip, bukan backend aktif. Panduan sebelumnya ada di [arsip Firebase](docs/FIREBASE-LEGACY.md).

## Build Android tanpa emulator

```powershell
flutter pub get
powershell -ExecutionPolicy Bypass -File tools/build-skripsi.ps1
```

Hasil: `build/app/outputs/flutter-apk/app-debug.apk`. Target ARM64, Android 7 ke atas. Desktop Windows/Linux/macOS dinonaktifkan pada konfigurasi proyek agar target Android/web tidak membutuhkan symlink desktop Windows. Templat platform tetap tersimpan.

Workflow GitHub **APK skripsi** hanya membutuhkan secret `GOOGLE_MAPS_ANDROID_API_KEY`; `API_BASE_URL` dapat diatur sebagai repository variable. SHA-1 APK runner berbeda dari keystore laptop dan perlu didaftarkan pada key Maps yang digunakan.

## Backend dan deployment

Lihat [deployment PostgreSQL](docs/DEPLOYMENT.md) dan [struktur database](docs/POSTGRESQL.md).

```powershell
cd backend
npm ci
npm test
# Deployment dari direktori backend yang sudah terhubung ke proyek Railway:
railway up . --path-as-root --service haryata-api
```

Untuk deployment Railway, isi `DATABASE_URL` melalui referensi layanan Postgres dan atur `ADMIN_EMAIL` serta `ADMIN_PASSWORD` melalui variabel layanan API.

## Lokal yang ringan

Jika sudah memiliki server API yang aktif, isi URL server tersebut pada `API_BASE_URL`. Di komputer yang sama, jalankan `tools/local.ps1` untuk mengakses admin web di localhost dengan key Maps web tersendiri.

Hubungkan HP dan komputer backend ke jaringan yang sama untuk pengujian lokal. APK debug mendukung HTTP LAN. Gunakan HTTPS untuk APK rilis.

## Verifikasi

- 71 tes Flutter lulus; mencakup adapter API, konflik transaksi, sesi kedaluwarsa, cache offline, foto, draft, sandi, tampilan dan pemulihan tracking.
- 18 tes backend lulus, termasuk validasi foto, aturan akses dan riwayat kurir.
- 14 pengujian langsung ke Railway lulus: [laporan aktual](docs/POSTGRES-LIVE-TEST.json).
- Kamera fisik, tampilan Maps asli, dan tracking layar terkunci tetap perlu diuji pada HP. Data koordinat uji server bukan bukti GPS perangkat.

## Struktur sumber

| Folder | Tanggung jawab |
|---|---|
| `lib/screens` | Halaman dan alur admin/kurir |
| `lib/widgets` | Komponen UI bersama: sandi, ringkasan status, foto, dan dialog |
| `lib/services` | API, sesi, pelacakan, transaksi pengiriman, dan draft perangkat |
| `lib/core`, `lib/models`, `lib/platform` | Tema, kebijakan status, model telemetri, dan integrasi platform |
| `backend/src` | API, autentikasi, aturan data, pemrosesan foto, dan pemeliharaan |
| `backend/migrations` | Skema database yang dapat dijalankan ulang |
| `test`, `backend/test` | Pengujian UI, unit, dan integrasi |
| `tools`, `.github/workflows` | Build, pengecekan, paket sumber, dan CI |
| `config`, `docs` | Contoh konfigurasi dan dokumentasi; rahasia lokal diabaikan Git |
| `legacy/firebase` | Arsip backend terdahulu; tidak dipakai build aktif |

Perubahan versi terbaru dan batas pengujian dicatat pada [catatan rilis 1.3.0](docs/RELEASE-1.3.0.md).
