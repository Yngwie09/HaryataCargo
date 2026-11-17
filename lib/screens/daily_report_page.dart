import '../widgets/shipment_status_summary.dart';
import 'shipment_detail_page.dart';
import '../services/backend_client.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../core/ui.dart';
import '../core/shipment_policy.dart';

class DailyReportPage extends StatefulWidget {
  const DailyReportPage({super.key});
  @override
  State<DailyReportPage> createState() => _DailyReportPageState();
}

class _DailyReportPageState extends State<DailyReportPage> {
  late DateTimeRange _range;
  String _basis = 'createdAt';
  bool _exporting = false;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final day = DateTime(now.year, now.month, now.day);
    _range = DateTimeRange(start: day, end: day);
  }

  DateTime _utc(DateTime date) => DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).subtract(const Duration(hours: 8));
  String _day(DateTime d) => '${d.day}/${d.month}/${d.year}';
  String _csvCell(dynamic value) {
    final text = value?.toString() ?? '';
    return RegExp(r'^[=+@\-\t\r\n]').hasMatch(text) ? "'$text" : text;
  }

  Future<void> _export(List<RecordDocument<Map<String, dynamic>>> docs) async {
    setState(() => _exporting = true);
    try {
      final rows = <List<dynamic>>[
        [
          'Resi',
          'Penerima',
          'Telepon',
          'Alamat',
          'Kurir',
          'Status',
          'Berat kg',
          'Koli',
          'Dibuat (waktu perangkat)',
          'Selesai (waktu perangkat)',
          'Penerima aktual',
          'Kendala',
        ],
        ...docs.map((doc) {
          final d = doc.data();
          return [
            d['resi'],
            d['penerima'],
            d['phone'],
            d['alamat'],
            d['courierEmail'],
            d['status'],
            d['weight'],
            d['pieces'],
            dateText(d['createdAt']),
            d['completedAt'] == null ? '' : dateText(d['completedAt']),
            (d['proof'] as Map?)?['receivedBy'],
            d['issue'],
          ].map(_csvCell).toList();
        }),
      ];
      final csv = const ListToCsvConverter().convert(rows);
      final name =
          'haryata-laporan-${_range.start.year}-${_range.start.month}-${_range.start.day}';
      final bytes = Uint8List.fromList(utf8.encode('\uFEFF$csv'));
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final saved = await FileSaver.instance.saveAs(
          name: name,
          bytes: bytes,
          ext: 'csv',
          mimeType: MimeType.csv,
        );
        if (saved == null) {
          if (mounted) notify(context, 'Penyimpanan laporan dibatalkan.');
          return;
        }
      } else {
        await FileSaver.instance.saveFile(
          name: name,
          bytes: bytes,
          ext: 'csv',
          mimeType: MimeType.csv,
        );
      }
      if (mounted) notify(context, 'Laporan CSV berhasil diekspor.');
    } catch (e) {
      if (mounted) notify(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = CargoStore.instance
        .collection('shipments')
        .where(
          _basis,
          isGreaterThanOrEqualTo: DataTimestamp.fromDate(_utc(_range.start)),
        )
        .where(
          _basis,
          isLessThan: DataTimestamp.fromDate(
            _utc(_range.end.add(const Duration(days: 1))),
          ),
        )
        .orderBy(_basis, descending: true)
        .limit(5000);
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan pengiriman')),
      body: PageBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                        initialDateRange: _range,
                      );
                      if (picked != null && mounted) {
                        setState(() => _range = picked);
                      }
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      '${_day(_range.start)} — ${_day(_range.end)} (WITA)',
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _basis,
                      decoration: const InputDecoration(
                        labelText: 'Dasar periode',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'createdAt',
                          child: Text('Tanggal dibuat'),
                        ),
                        DropdownMenuItem(
                          value: 'completedAt',
                          child: Text('Tanggal selesai'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _basis = v!),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<RecordSet<Map<String, dynamic>>>(
                stream: query.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return EmptyState(
                      'Laporan tidak dapat dimuat',
                      errorText(snapshot.error!),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  final counts = <String, int>{
                    for (final status in shipmentStatuses) status: 0,
                  };
                  for (final doc in docs) {
                    final status = doc.data()['status'];
                    if (counts.containsKey(status)) {
                      counts[status as String] = counts[status]! + 1;
                    }
                  }
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Card(
                        color: brand,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PENGIRIMAN DALAM PERIODE',
                                style: TextStyle(
                                  color: Colors.white70,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${docs.length} paket',
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ShipmentStatusSummary(counts: counts),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: docs.isEmpty || _exporting
                              ? null
                              : () => _export(docs),
                          icon: const Icon(Icons.download_outlined),
                          label: Text(
                            _exporting ? 'Mengekspor…' : 'Ekspor CSV',
                          ),
                        ),
                      ),
                      if (docs.length >= 5000)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Batas 5.000 data tercapai. Persempit periode untuk mendapatkan laporan lengkap.',
                          ),
                        ),
                      if (snapshot.data!.metadata.isFromCache)
                        const Text(
                          'Data belum tersinkron dengan server. Periksa koneksi sebelum menggunakan laporan.',
                        ),
                      const SizedBox(height: 24),
                      Text(
                        'Rincian periode',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (docs.isEmpty)
                        const EmptyState(
                          'Tidak ada pengiriman',
                          'Pilih periode atau dasar tanggal yang berbeda.',
                        ),
                      ...docs.map((doc) {
                        final d = doc.data();
                        return Card(
                          child: ListTile(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ShipmentDetailPage(docId: doc.id),
                              ),
                            ),
                            title: Text('${d['resi']} • ${d['penerima']}'),
                            subtitle: Text(
                              '${d['courierEmail'] ?? 'Belum ditugaskan'}\n${dateText(d[_basis])}',
                            ),
                            isThreeLine: true,
                            trailing: StatusBadge(d['status'] ?? 'Pending'),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
