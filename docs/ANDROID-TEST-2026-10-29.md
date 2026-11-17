# Pemeriksaan Android — 29 Oktober 2026

APK Android berhasil dibangun dan tersedia di `dist/HaryataCargo-1.1.0-skripsi-arm64.apk`, juga disalin ke Downloads pengguna. Versi 1.1.0+2, debug, min SDK 24 (Android 7), target SDK 36. Engine Flutter hanya ARM64; pustaka JNI tambahan juga memuat ABI lain, sehingga APK ini tetap membutuhkan HP ARM64.

## Bukti terbaru

- Gradle `assembleDebug`: **BUILD SUCCESSFUL**, 25 menit 33 detik pada build lanjutan; 503 tugas (348 executed, 155 up-to-date). SDK command-line resmi, platform 34/35/36, build-tools 36.0.0, CMake 3.22.1, NDK 28.2.13676358; tanpa emulator/Android Studio.
- Signature APK diverifikasi dengan `apksigner verify --print-certs`: valid.
- `aapt dump badging`: package `id.haryata.cargo`, versionCode 2, versionName 1.1.0, min SDK 24, target SDK 36.
- Nilai resource Firebase App ID dan project ID cocok dengan google-services.json. Key Maps lokal ditemukan di manifest APK tanpa menampilkan key.
- Izin INTERNET dan kelas `Lid/haryata/cargo/MainActivity;` ditemukan di APK/DEX.
- Ukuran APK 96.615.648 byte. SHA-256: `CFFBF4A1104BE7BA9B2BA03E239ACA893FDF8D8A23C7E881890BD2A36E180FE8`. Salinan Downloads memiliki hash yang sama.
- Sertifikat debug SHA-1: `33:C4:3F:AA:63:CD:19:AB:F5:0C:B0:C6:DB:2B:28:16:C2:8B:2C:6F`.
- Sebelumnya pada pemeriksaan ini: 39 tes Flutter, 14 tes Node lulus; analyzer No issues found. Skrip PowerShell build lolos parser.

## Batas pembuktian

APK belum dipasang pada HP dan tidak ada uji end-to-end ke proyek Firebase/Google Maps baru. Login, akun/role, aktivasi Authentication, Firestore/Storage, deployment Functions/rules/indeks, billing/otorisasi Maps/SHA-1, kamera/galeri, penyimpanan CSV native, serta GPS layar terkunci tetap perlu diuji pada perangkat.

Ikuti `docs/SKRIPSI.md`, `docs/ACCEPTANCE.md`, dan `dist/HaryataCargo-PETUNJUK-UJI.txt`. Keberhasilan build/konfigurasi paket tidak membuktikan seluruh menu berhasil bertransaksi ke cloud.

## Penyesuaian lingkungan build

Gradle menggunakan distribusi bin untuk mengurangi unduhan. Skrip build skripsi menemukan SDK bundled secara otomatis dan memakai satu proses compiler Kotlin. Kendala TLS Maven ditangani dengan TLS 1.2 pada lingkungan build lokal. Engine ARM64 diambil dari storage resmi Flutter, diverifikasi dengan checksum metadata Google, dan dipasok melalui init script lokal yang hanya berlaku bagi proyek aplikasi. Key Maps tidak dicetak dalam log pemeriksaan. File APK debug memakai sertifikat lokal, berbeda dari sertifikat runner GitHub Actions.
