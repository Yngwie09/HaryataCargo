# Migrasi PostgreSQL — 31 Oktober 2026

Pengguna menyatakan Firebase masih kosong/hanya percobaan. Tidak ada data nyata yang diekspor, dihapus atau ditimpa pada proyek Firebase lama. PostgreSQL baru menjadi penyimpanan aktif aplikasi versi 1.2.0.

## Deployment nyata

- Proyek Railway `haryata-cargo-skripsi`, ID `85a417e2-6383-4c82-bc13-0e50eee6647a`.
- Service PostgreSQL `fd413b1f-b1ed-4cf6-a685-1b213cb95d42`.
- Service API `aae8fc4a-9fb4-482c-8d89-80bbf256ffc7`.
- Endpoint HTTPS `https://haryata-api-production.up.railway.app`.
- PostgreSQL volume `postgres-volume`, `/var/lib/postgresql/data`, 5000 MB, status Ready.
- Health menjalankan query PostgreSQL. Skema dipasang otomatis dan restart deployment tidak menimpa admin yang sudah ada.

## Pengujian

49 tes Flutter lulus, termasuk 8 tes adapter API dan 2 tes dialog sandi. Analyzer bersih. Backend unit test dan pemeriksaan sintaks tersedia. `docs/POSTGRES-LIVE-TEST.json` mencatat 14 kelompok pemeriksaan langsung ke Railway: autentikasi, pembatasan role, resi unik bersamaan, pengiriman, foto BYTEA, status, audit, laporan, GPS/server, dan pencabutan sesi.

Akun admin dan dua kurir contoh dibuat dengan password acak, tersimpan pada `config/railway.private.json` yang diabaikan Git serta tidak masuk paket sumber. Data UJI-PG adalah fixture; koordinat contoh bukan GPS perangkat dan sudah ditandai berhenti.

## Perubahan klien

SDK Firebase dihapus dari dependency aplikasi dan registrasi plugin Android. Semua menu memakai `lib/services/backend_client.dart`, dengan API_BASE_URL pada konfigurasi build. Password dapat diubah sendiri atau direset admin; email Firebase tidak lagi digunakan. Draft tiga foto tetap disimpan lokal sebelum upload. Google Maps memakai key/keystore yang sama dengan versi Android sebelumnya.

Pengambilan snapshot API setiap 5 detik mempertahankan data terakhir sebagai cache ketika offline. Transaksi membawa versi record dan mengulang pembacaan pada konflik. Respons 401 dari permintaan sesi lama tidak menghapus sesi login baru.

## Batas pembuktian

Belum ada HP fisik tersambung. Kamera/galeri native, rendering Maps di HP, dialog ekspor CSV Android dan pelacakan layar terkunci memerlukan uji perangkat. API dengan koordinat fixture dan tes adapter membuktikan jalur data, bukan GPS fisik.

## APK selesai

Build Android berhasil dalam 8 menit 18 detik. APK 1.2.0+3, 91.440.918 byte, signature valid. API Railway dan key Maps ditemukan dalam APK; plugin Firebase dan FirebaseInitProvider tidak ditemukan. MainActivity tersedia pada DEX. Engine Flutter ARM64, min SDK 24/target 36. SHA-1 tetap sama dengan APK sebelumnya. Lihat POSTGRES-APK-VERIFICATION.json untuk hash dan hasil pemeriksaan. Kamera/Maps/GPS HP fisik belum diuji.
