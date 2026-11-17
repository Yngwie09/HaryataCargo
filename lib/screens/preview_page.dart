import 'package:flutter/material.dart';
import '../core/ui.dart';
import 'admin_home.dart';
import 'login_page.dart';
import 'delivery_proof_page.dart';

/// Explicitly read-only: no API login, uploads, or live location.
class PreviewPage extends StatefulWidget {
  const PreviewPage({super.key});
  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  int _index = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        SafeArea(
          bottom: false,
          child: Material(
            color: const Color(0xFFFFF2CA),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined, color: brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'PRATINJAU LOKAL • Tampilan saja. Login, pengiriman, unggah foto, dan pelacakan tidak aktif.\nHubungkan layanan aplikasi untuk penggunaan operasional.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: switch (_index) {
            0 => const AdminHome(preview: true),
            1 => const LoginPage(preview: true),
            _ => const DeliveryProofPage(
              shipmentId: 'preview',
              resi: 'HC-PRATINJAU',
              preview: true,
            ),
          },
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (index) => setState(() => _index = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Dashboard',
        ),
        NavigationDestination(icon: Icon(Icons.login), label: 'Login'),
        NavigationDestination(
          icon: Icon(Icons.camera_alt_outlined),
          label: 'Serah terima',
        ),
      ],
    ),
  );
}
