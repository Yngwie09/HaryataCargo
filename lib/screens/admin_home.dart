import 'package:flutter/material.dart';
import '../widgets/operations_overview.dart';
import '../core/ui.dart';
import 'add_shipment_page.dart';
import 'shipment_list_page.dart';
import 'manage_couriers_page.dart';
import 'daily_report_page.dart';
import 'settings_page.dart';
import 'courier_tracking_page.dart';
import '../services/session_service.dart';

class AdminHome extends StatelessWidget {
  const AdminHome({super.key, this.preview = false});
  final bool preview;
  @override
  Widget build(BuildContext context) {
    final menus = <(IconData, String, String, Widget)>[
      (
        Icons.add_box_outlined,
        'Buat pengiriman',
        'Catat paket dan tentukan kurir',
        const AddShipmentPage(),
      ),
      (
        Icons.inventory_2_outlined,
        'Pengiriman',
        'Cari resi, status, dan bukti serah terima',
        const ShipmentListPage(),
      ),
      (
        Icons.map_outlined,
        'Pantau kurir',
        'Lihat lokasi terakhir dan status koneksi',
        const CourierTrackingPage(),
      ),
      (
        Icons.people_outline,
        'Kelola kurir',
        'Akun, profil, dan akses operasional',
        const ManageCouriersPage(),
      ),
      (
        Icons.insights_outlined,
        'Laporan',
        'Rekap periode dan ekspor CSV',
        const DailyReportPage(),
      ),
      (
        Icons.settings_outlined,
        'Pengaturan',
        'Profil, keamanan, dan panduan',
        const SettingsPage(),
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Haryata Cargo'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: preview
                ? null
                : () async {
                    try {
                      await SessionService.logout();
                    } catch (e) {
                      if (context.mounted) {
                        notify(context, errorText(e), error: true);
                      }
                    }
                  },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [brand, accent]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PUSAT OPERASIONAL',
                    style: TextStyle(
                      color: Colors.white70,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Setiap kiriman, dalam kendali.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Kelola penugasan, pantau perjalanan kurir, dan pastikan bukti serah terima tercatat.',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (!preview) ...[
              const OperationsOverview(),
              const SizedBox(height: 28),
            ],
            Text(
              'Ruang kerja admin',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 850
                    ? 3
                    : constraints.maxWidth > 520
                    ? 2
                    : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 16) / columns;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: menus
                      .map(
                        (menu) => SizedBox(
                          width: width,
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: preview
                                  ? null
                                  : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => menu.$4,
                                      ),
                                    ),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: accent.withValues(
                                        alpha: .1,
                                      ),
                                      child: Icon(menu.$1, color: accent),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      menu.$2,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      menu.$3,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Align(
                                      alignment: Alignment.centerRight,
                                      child: Icon(
                                        Icons.arrow_forward,
                                        color: accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
