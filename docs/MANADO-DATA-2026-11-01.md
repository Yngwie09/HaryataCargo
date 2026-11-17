# Pembaruan penerima dan alamat Manado

Sumber katalog contoh di `backend/src/catalog.js` menggunakan 15 nama penerima fiktif serta alamat di Kota Manado, Sulawesi Utara. Nama dan nomor rumah merupakan contoh aplikasi, bukan daftar pelanggan nyata.

Migrasi `002_manado_example_contacts.sql` memperbarui nama serta alamat pada pengiriman contoh yang masih persis cocok dengan data lama. ID pengiriman, resi, kurir, status, foto, koordinat, dan waktu operasional dipertahankan. Pengiriman tambahan serta kontak yang sudah diubah pengguna tidak ditimpa oleh migrasi ini.

Migrasi ditandai sebagai versi 2 dan dijalankan satu kali. Katalog baru juga memakai Manado apabila operator membuat ulang contoh data pada masa mendatang. Tidak perlu membangun atau memasang ulang APK untuk menerima pembaruan data server.

Salinan sebelum perubahan disimpan pada `config/migration-export/before-manado-2026-11-01.private.json` dan dikecualikan dari Git serta paket sumber. Hasil pemeriksaan database setelah deployment dicatat pada `MANADO-DATA-2026-11-01.json`.
