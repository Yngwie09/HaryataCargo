import '../widgets/password_dialog.dart';
import '../services/backend_client.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/ui.dart';
import '../services/session_service.dart';
import 'tracking_diagnostics_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, this.courier = false});
  final bool courier;
  @override
  Widget build(BuildContext context) {
    final user = CargoAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil & pengaturan')),
      body: PageBody(
        width: 760,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(user?.email ?? 'Akun'),
                subtitle: Text(
                  courier
                      ? 'Kurir Haryata Cargo'
                      : 'Administrator Haryata Cargo',
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Keamanan akun',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.lock_reset),
                title: const Text('Ubah kata sandi'),
                subtitle: const Text('Ganti kata sandi akun Anda'),
                onTap: () => showPasswordDialog(context),
              ),
            ),
            if (courier) ...[
              const SizedBox(height: 20),
              Text(
                'Lokasi & pengantaran',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.troubleshoot),
                      title: const Text('Periksa pelacakan'),
                      subtitle: const Text(
                        'Uji GPS, akses server, dan posisi yang diterima server',
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TrackingDiagnosticsPage(),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: const Text('Izin lokasi aplikasi'),
                      subtitle: const Text(
                        'Aktifkan lokasi akurat. Izinkan akses sepanjang waktu agar pengantaran dapat dipantau di latar belakang.',
                      ),
                      onTap: () => Geolocator.openAppSettings(),
                    ),
                    ListTile(
                      leading: const Icon(Icons.gps_fixed),
                      title: const Text('Pengaturan GPS perangkat'),
                      onTap: () => Geolocator.openLocationSettings(),
                    ),
                  ],
                ),
              ),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Saat mengantar, biarkan aplikasi berjalan dan koneksi internet aktif. Jangan paksa berhenti aplikasi. Jika perangkat membatasi baterai, izinkan aktivitas latar belakang. Gunakan Pulihkan pada beranda bila pelacakan bermasalah.',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Panduan operasional',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  courier
                      ? '1. Buka paket yang ditugaskan kepada Anda.\n2. Pilih Mulai pengantaran dan izinkan lokasi.\n3. Tunda dan laporkan kendala jika terjadi hambatan.\n4. Saat tiba, lengkapi nama penerima serta foto tanda terima, penerima, dan barang.\n5. Simpan bukti untuk menyelesaikan pengiriman.'
                      : '1. Buat akun kurir melalui Kelola kurir.\n2. Buat pengiriman dan pilih kurir penanggung jawab.\n3. Pantau lokasi melalui Pantau kurir.\n4. Periksa status, riwayat, dan bukti foto pada detail pengiriman.\n5. Gunakan Laporan untuk rekap dan ekspor periode.',
                ),
              ),
            ),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Pengiriman dalam satu genggaman\n\nKelola penugasan, pantau perjalanan kurir, dan simpan bukti serah terima dengan mudah. Pastikan informasi penerima dan alamat selalu lengkap sebelum memulai pengantaran.',
                ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => showAboutDialog(
                context: context,
                applicationName: 'Haryata Cargo',
                applicationVersion: '1.3.0',
                applicationLegalese: '© 2026 PT. Haryata Cargo',
                children: const [
                  Text(
                    'Sistem penugasan, pelacakan kurir, dan dokumentasi serah terima pengiriman.',
                  ),
                ],
              ),
              icon: const Icon(Icons.info_outline),
              label: const Text('Tentang aplikasi'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                try {
                  await SessionService.logout();
                  if (context.mounted) {
                    Navigator.popUntil(context, (r) => r.isFirst);
                  }
                } catch (e) {
                  if (context.mounted) {
                    notify(context, errorText(e), error: true);
                  }
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Keluar dari akun'),
            ),
          ],
        ),
      ),
    );
  }
}
