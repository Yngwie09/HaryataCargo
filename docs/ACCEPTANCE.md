# Penerimaan aplikasi pada lingkungan nyata

Catat tanggal, versi APK, model HP, versi Android, URL web, ID proyek, dan hasil setiap pemeriksaan. Gunakan akun admin + dua kurir. Hindari foto/data pribadi sungguhan pada proyek uji.

## Akun dan keamanan

- [ ] Admin dapat login, reload browser tetap memiliki sesi, dan keluar dari pengaturan/beranda.
- [ ] Email/password salah menghasilkan pesan yang dapat dipahami; pemulihan sandi sampai di email.
- [ ] Akun tanpa profil, role tidak valid, dan akun nonaktif ditolak.
- [ ] Admin membuat kurir tanpa mengubah sesi login admin.
- [ ] Akun kurir lain tidak bisa membaca/mengubah tugas, lokasi, ataupun foto yang bukan haknya.
- [ ] Kurir tidak dapat mengubah role, menulis audit, atau menulis status Selesai langsung.
- [ ] Menonaktifkan kurir dengan paket Pending/Proses ditolak; setelah tugas selesai atau dialihkan, akses berhasil ditutup.

## Pengiriman

- [ ] Resi kosong, hanya spasi, format salah, berat/koli tidak valid, dan telepon salah ditolak.
- [ ] Dua admin yang membuat resi sama secara bersamaan hanya menghasilkan satu pengiriman.
- [ ] Paket hanya tampil pada akun kurir yang dipilih. Paket Pending dapat diedit/dialihkan/dibatalkan oleh admin.
- [ ] Mulai pengantaran memerlukan GPS dan izin lokasi; tidak bisa menyelesaikan Pending atau mengulang Selesai.
- [ ] Kendala tersimpan dan terlihat di admin; riwayat berasal dari server.
- [ ] Filter status, pencarian data termuat, dan Muat berikutnya bekerja.

## Tiga foto bukti

- [ ] Kurang salah satu foto atau nama/persetujuan penerima ditolak.
- [ ] Kamera dan galeri berfungsi, preview/ganti foto bekerja, ukuran >5 MB ditolak.
- [ ] Saat Android menghentikan activity pemilih foto, buka kembali bukti pengiriman yang sama untuk pemulihan foto yang dikembalikan picker.
- [ ] Progress unggah terlihat dan tombol simpan tidak dapat ditekan berulang selama proses.
- [ ] Status Selesai baru tersimpan setelah semua objek foto diverifikasi server.
- [ ] Admin/kurir pemilik dapat memperbesar foto, melihat penerima aktual dan lokasi serah terima.
- [ ] Foto dan bukti selesai tidak dapat diganti lewat klien.
- [ ] Gangguan internet tidak menghilangkan foto yang masih ada pada formulir; percobaan ulang tidak menggandakan penyelesaian.

## Tracking HP fisik → web admin

- [ ] Maps tampil tanpa error API/billing/referrer pada domain rilis dan localhost.
- [ ] Key Android dibatasi ke package + SHA-1 APK terpasang yang benar.
- [ ] Setelah mulai, lokasi kurir tampil pada dashboard dengan koordinat dan waktu aktual.
- [ ] Saat kurir bergerak, marker mengikuti pembaruan; ketuk daftar untuk memusatkan peta.
- [ ] Kurir diam >3 menit tetap tampil; refresh GPS dan waktu pembaruan dapat diperiksa.
- [ ] Kurir kehilangan internet/GPS tidak hilang: posisi terakhir dan indikator terlambat tetap terlihat.
- [ ] Pindah aplikasi dan kunci layar selama 10–15 menit; periksa notifikasi foreground dan update lokasi pada HP yang akan dipakai.
- [ ] Uji izin hanya saat digunakan / sepanjang waktu / ditolak / diblokir dan GPS dimatikan.
- [ ] Pulihkan lokasi dan kembali dari background memulihkan stream tanpa listener ganda.
- [ ] Selesaikan paket terakhir: tracking berhenti. Jika ada paket Proses lain: tracking tetap berjalan.
- [ ] Logout pada semua menu ditolak selama ada paket Proses.
- [ ] Uji force-stop secara terpisah: lokasi menjadi terlambat, bukan ditampilkan sebagai live; buka lagi aplikasi untuk memulihkan.

## Laporan dan rilis

- [ ] Periode laporan dihitung WITA, termasuk batas pergantian hari.
- [ ] Perubahan dasar tanggal dibuat/selesai menghasilkan rekap sesuai data.
- [ ] CSV dapat dibuka, Unicode tampil benar, dan data yang diawali formula tidak dieksekusi.
- [ ] Tidak ada placeholder Maps, konfigurasi proyek lama, atau signing debug dalam artefak release.
- [ ] Aplikasi release memiliki akses internet dan foto/GPS berfungsi pada build release, bukan hanya debug.
- [ ] Tampilan 360 px, tablet, desktop, dan teks besar tetap terbaca.
