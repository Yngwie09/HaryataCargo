# Deployment PostgreSQL Railway

## Layanan aktif

Proyek: `haryata-cargo-skripsi` (`85a417e2-6383-4c82-bc13-0e50eee6647a`).

- PostgreSQL: `Postgres`, volume `postgres-volume` pada `/var/lib/postgresql/data`, status Ready.
- API: `haryata-api`.
- Endpoint: `https://haryata-api-production.up.railway.app`.
- Health: `GET /health`, menjalankan `SELECT 1` pada PostgreSQL.

Tidak ada layanan/database proyek Railway lain yang diubah.

## Konfigurasi server

`DATABASE_URL` pada API menggunakan referensi `${{Postgres.DATABASE_URL}}`. Jangan memasukkan URL database ke konfigurasi Flutter. `PORT=3000`, `NODE_ENV=production`. Atur `ADMIN_EMAIL`, `ADMIN_PASSWORD` melalui Railway Variables; password awal dibuat acak dan tersimpan lokal pada `config/railway.private.json`, bukan dalam source/API response.

Saat startup, API menjalankan `backend/migrations/001_initial.sql` dengan advisory lock. Skema dibuat idempoten. Admin awal dibuat hanya bila belum ada; deploy ulang tidak mengubah sandi pengguna.

## Memperbarui API

Dari direktori `backend` yang terhubung ke proyek ini:

```powershell
npm ci
npm test
railway up . --path-as-root --service haryata-api --detach
railway deployment list --service haryata-api --json
```

Tunggu status SUCCESS dan periksa `/health`. Dockerfile menjalankan Node 22 sebagai user non-root. Foto tidak disimpan pada filesystem API; restart/deploy tidak menghapus foto karena bytes berada di PostgreSQL.

Bila komputer belum terhubung, jalankan `railway login` dan `railway link`, pilih proyek Haryata Cargo yang benar. Jangan menyalin konfigurasi proyek lain. CLI Railway saat ini memberi peringatan bahwa Config as Code lama akan dihentikan; gunakan `railway config migrate` ketika memindahkan konfigurasi deployment ke Infrastructure as Code sesuai dokumentasi Railway, tanpa membuat ulang database yang sudah berisi data.

## Pengelolaan akun

Admin membuat kurir melalui Kelola kurir. Kurir dapat diaktifkan/nonaktifkan, dan sandinya direset tanpa layanan email. Pengguna mengubah sandi sendiri dari Profil & pengaturan. Sesi lama dicabut saat reset/nonaktif.

Untuk pemulihan admin oleh pemilik server: ubah variabel `ADMIN_PASSWORD` secara privat lalu jalankan `node src/reset-admin.js` di container API melalui fasilitas SSH/console Railway. Skrip memakai koneksi database server, memperbarui hash admin yang sesuai `ADMIN_EMAIL`, dan mencabut sesi lama. Tidak ada endpoint publik untuk mereset admin tanpa autentikasi.

## Admin web dan CORS

Android menggunakan API langsung. Untuk web, tambahkan origin web sebenarnya pada `CORS_ORIGINS`, dipisahkan koma. Localhost/127.0.0.1 untuk pengembangan sudah diperbolehkan. Isi key Maps JavaScript terpisah pada konfigurasi web; key Android tidak dapat dipakai dengan pembatasan HTTP referrer.

## Data uji dan verifikasi

`docs/POSTGRES-LIVE-TEST.json` mencatat pengujian langsung ke server. Prefix resi `UJI-PG-...`, nama penerima/kurir, PNG kecil, dan koordinat contoh hanya fixture skripsi. Lokasi contoh sudah dihentikan agar tidak ditampilkan sebagai GPS live.

Pengujian live `node backend/test/live-smoke.mjs` secara sengaja membuat data/akun contoh. Jangan menjalankannya otomatis pada setiap deploy. Workflow `PostgreSQL backend checks` memakai database CI sementara untuk unit test dan menjalankan migrasi dua kali.
