# API Haryata Cargo

Node.js 22, Express, PostgreSQL, dan pemrosesan foto Sharp. Server menangani autentikasi, otorisasi per kurir, status pengiriman, riwayat, lokasi, serta tiga bukti foto.

## Menjalankan

```sh
npm ci
npm test
node --env-file=.env src/server.js
```

Salin `.env.example` menjadi `.env` dan gunakan database PostgreSQL yang tersedia. Migrasi berjalan saat startup dan aman dijalankan ulang. Deployment Railway cukup mengunggah direktori ini; database tidak perlu dijalankan di laptop.

## Pembagian kode

- `auth.js`: hash scrypt, sesi, reautentikasi, dan role.
- `records.js`: kueri terpilih, batas akses, transaksi, audit, dan kebijakan status.
- `server.js`: kontrak HTTP, pembatasan permintaan, serta penanganan error.
- `photos.js`: decode penuh, batas dimensi, normalisasi orientasi, dan penghapusan metadata gambar.
- `db.js` dan `migrations/`: koneksi serta skema database.
- `tracking.js`: server push SSE terautentikasi, berbagi snapshot database antardashboard, dan pencabutan sesi streaming.
- `catalog.js`: penyusunan contoh pengiriman dan lima kurir.
- `maintenance.js`: operasi penggantian data, nonaktif secara default.

## Kontrak utama

| Endpoint | Fungsi |
|---|---|
| `GET /health` | Kesehatan API dan koneksi database |
| `POST /v1/auth/login` | Login akun aplikasi |
| `GET /v1/auth/me` | Identitas sesi |
| `GET /v1/tracking/stream` | Stream lokasi langsung untuk admin |
| `GET /v1/dashboard` | Ringkasan status berdasarkan hak akses |
| `POST /v1/query`, `/v1/record` | Membaca koleksi atau dokumen yang diizinkan |
| `POST /v1/transactions` | Perubahan data dengan pemeriksaan versi |
| `POST /v1/actions/createCourier` | Membuat kurir oleh admin |
| `POST /v1/actions/finalizeDelivery` | Menyelesaikan pengiriman dengan tiga foto |
| `POST /v1/photos/upload`, `GET /v1/photos` | Menyimpan dan membaca foto terautentikasi |

Kata sandi menerima karakter bebas, termasuk satu karakter; hanya isian kosong yang tidak dapat digunakan. Batas input server 4.096 karakter melindungi pemrosesan permintaan. Email tetap unik. Foto JPG/PNG maksimal 5 MB harus bisa didekode seluruhnya dan berukuran minimal 32 × 32 piksel.

Operasi penggantian katalog tidak tersedia tanpa `MAINTENANCE_RESET_TOKEN`, sesi admin, kata sandi saat ini, dan konfirmasi eksplisit. Setelah operasi yang disetujui selesai, cabut variabel tersebut dan redeploy API agar proses berjalan tanpa akses pemeliharaan.

`test/live-smoke.mjs` mengubah data dan hanya boleh dijalankan dengan `LIVE_SMOKE_CONFIRM=RUN_HARYATA_CHECKS` pada dataset yang memang disiapkan untuk integrasi. `npm test` tidak menghubungi Railway atau mengubah database pengguna.
