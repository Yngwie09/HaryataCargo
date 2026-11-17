import 'dart:async';
import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../services/backend_client.dart';
import '../screens/shipment_list_page.dart';
import 'shipment_status_summary.dart';

class OperationsOverview extends StatefulWidget {
  const OperationsOverview({super.key});
  @override
  State<OperationsOverview> createState() => _OperationsOverviewState();
}

class _OperationsOverviewState extends State<OperationsOverview> {
  Map<String, int>? _counts;
  String? _error;
  Timer? _timer;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy) return;
    _busy = true;
    try {
      final result = await ApiClient.request('/v1/dashboard', get: true);
      if (mounted) {
        setState(() {
          _counts = Map<String, int>.from(result['counts'] as Map);
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = errorText(error));
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Ringkasan operasional',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Perbarui ringkasan',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (_counts == null && _error == null) const LinearProgressIndicator(),
      if (_error != null)
        Text(
          'Ringkasan belum diperbarui. $_error',
          style: const TextStyle(color: Colors.deepOrange),
        ),
      if (_counts != null) ...[
        ShipmentStatusSummary(counts: _counts!),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final status in ['Pending', 'Proses', 'Tertunda'])
              ActionChip(
                label: Text('Lihat $status'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShipmentListPage(initialStatus: status),
                  ),
                ),
              ),
          ],
        ),
      ],
    ],
  );
}
