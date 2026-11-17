import '../services/backend_client.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/ui.dart';
import '../core/shipment_policy.dart';
import '../services/shipment_service.dart';
import '../services/courier_location_service.dart';
import '../widgets/proof_photo.dart';
import '../widgets/resolve_shipment_dialog.dart';
import 'delivery_proof_page.dart';
import 'add_shipment_page.dart';

class ShipmentDetailPage extends StatefulWidget {
  const ShipmentDetailPage({
    super.key,
    required this.docId,
    this.courier = false,
  });
  final String docId;
  final bool courier;
  @override
  State<ShipmentDetailPage> createState() => _ShipmentDetailPageState();
}

class _ShipmentDetailPageState extends State<ShipmentDetailPage> {
  bool _busy = false;
  Future<void> _resolve(Map<String, dynamic> data) async {
    final stream = CargoStore.instance
        .collection('users')
        .where('role', isEqualTo: 'kurir')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .where((d) => d.data()['active'] == true)
              .map(
                (d) => CourierChoice(
                  d.id,
                  d.data()['name'] ?? d.data()['email'] ?? 'Kurir',
                ),
              )
              .toList(),
        );
    final result = await showDialog<ShipmentResolution>(
      context: context,
      builder: (_) => ResolveShipmentDialog(
        couriers: stream,
        initialCourierId: data['courierId'],
      ),
    );
    if (result == null || !mounted) return;
    await ShipmentService.resolveIssue(
      widget.docId,
      retry: result.retry,
      reason: result.reason,
      courierId: result.courierId,
    );
    if (mounted) {
      notify(
        context,
        result.retry
            ? 'Pengantaran ulang sudah ditugaskan.'
            : 'Pengiriman ditandai sebagai retur.',
      );
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) notify(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _note(String title) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Keterangan (minimal 5 karakter)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().length >= 5) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    // The dialog's closing animation may still reference its controller.
    Future.delayed(const Duration(seconds: 1), controller.dispose);
    return result;
  }

  Future<void> _open(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      notify(context, 'Tidak dapat membuka aplikasi tujuan.', error: true);
    }
  }

  Widget _info(String label, Object? value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value == null || value.toString().isEmpty ? '—' : value.toString(),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detail pengiriman')),
    body: StreamBuilder<RecordSnapshot<Map<String, dynamic>>>(
      stream: CargoStore.instance
          .collection('shipments')
          .doc(widget.docId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return EmptyState(
            'Pengiriman tidak dapat dimuat',
            errorText(snapshot.error!),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snapshot.data!.data();
        if (d == null) {
          return const EmptyState(
            'Pengiriman tidak ditemukan',
            'Kembali ke daftar untuk melihat data terbaru.',
          );
        }
        final status = d['status'] as String? ?? 'Pending';
        final resi = d['resi'] as String? ?? widget.docId;
        final proof = Map<String, dynamic>.from(d['proof'] as Map? ?? {});
        final photos = Map<String, dynamic>.from(proof['photos'] as Map? ?? {});
        return PageBody(
          width: 880,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      resi,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  StatusBadge(status),
                ],
              ),
              const SizedBox(height: 8),
              Text('Dibuat ${dateText(d['createdAt'])}'),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Tujuan pengiriman',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      _info('Nama penerima', d['penerima']),
                      _info('Alamat', d['alamat']),
                      _info('Telepon', d['phone']),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          if ((d['phone'] ?? '').toString().isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () => _run(
                                () =>
                                    _open(Uri(scheme: 'tel', path: d['phone'])),
                              ),
                              icon: const Icon(Icons.call_outlined),
                              label: const Text('Hubungi penerima'),
                            ),
                          OutlinedButton.icon(
                            onPressed: () => _run(
                              () => _open(
                                Uri.https('www.google.com', '/maps/search/', {
                                  'api': '1',
                                  'query': d['alamat'] ?? '',
                                }),
                              ),
                            ),
                            icon: const Icon(Icons.directions_outlined),
                            label: const Text('Buka arah di Maps'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informasi paket',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      _info('Pengirim', d['sender']),
                      _info(
                        'Berat / jumlah koli',
                        '${d['weight'] ?? '—'} kg / ${d['pieces'] ?? '—'} koli',
                      ),
                      _info('Kurir', d['courierEmail']),
                      _info('Catatan', d['notes']),
                      if (d['issue'] != null)
                        _info('Kendala terakhir', d['issue']),
                      if (d['cancelReason'] != null)
                        _info('Alasan pembatalan', d['cancelReason']),
                    ],
                  ),
                ),
              ),
              if (_busy) const LinearProgressIndicator(),
              if (widget.courier && status == 'Pending')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            if (!await confirm(
                              context,
                              'Mulai pengantaran?',
                              'Lokasi Anda akan dibagikan kepada admin selama pengantaran. Izinkan lokasi akurat dan pastikan GPS aktif.',
                            )) {
                              return;
                            }
                            await CourierLocationService.instance
                                .checkLocation();
                            await ShipmentService.transition(
                              widget.docId,
                              'Proses',
                            );
                          }),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Mulai pengantaran'),
                  ),
                ),
              if (widget.courier && status == 'Proses')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DeliveryProofPage(
                                    shipmentId: widget.docId,
                                    resi: resi,
                                  ),
                                ),
                              ),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Serah terima & foto bukti'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                final note = await _note(
                                  'Tunda & laporkan kendala',
                                );
                                if (note != null) {
                                  await ShipmentService.reportIssue(
                                    widget.docId,
                                    note,
                                  );
                                }
                              }),
                        icon: const Icon(Icons.report_problem_outlined),
                        label: const Text('Tunda & laporkan kendala'),
                      ),
                    ],
                  ),
                ),
              if (!widget.courier && status == 'Pending')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddShipmentPage(
                                    docId: widget.docId,
                                    initial: d,
                                  ),
                                ),
                              ),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit / ganti kurir'),
                      ),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                final reason = await _note(
                                  'Batalkan pengiriman',
                                );
                                if (reason != null) {
                                  await ShipmentService.cancel(
                                    widget.docId,
                                    reason,
                                  );
                                }
                              }),
                        child: const Text('Batalkan pengiriman'),
                      ),
                    ],
                  ),
                ),
              if (widget.courier && status == 'Tertunda')
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Pengantaran ditunda. Admin dapat menugaskan pengantaran ulang atau mencatat retur.',
                    ),
                  ),
                ),
              if (!widget.courier && ['Proses', 'Tertunda'].contains(status))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _run(() => _resolve(d)),
                    icon: const Icon(Icons.assignment_return_outlined),
                    label: const Text('Pengantaran ulang / retur'),
                  ),
                ),
              if (d['resolutionNote'] != null)
                _info('Tindak lanjut admin', d['resolutionNote']),
              if (proof.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Bukti serah terima',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _info('Diterima oleh', proof['receivedBy']),
                _info('Waktu penyerahan', dateText(d['completedAt'])),
                _info('Catatan penerimaan', proof['note']),
                if (proof['latitude'] is num && proof['longitude'] is num)
                  TextButton.icon(
                    onPressed: () => _run(
                      () => _open(
                        Uri.https('www.google.com', '/maps/search/', {
                          'api': '1',
                          'query': '${proof['latitude']},${proof['longitude']}',
                        }),
                      ),
                    ),
                    icon: const Icon(Icons.location_on_outlined),
                    label: const Text('Lihat lokasi serah terima'),
                  ),
                ...proofLabels.entries
                    .where((e) => photos[e.key] is String)
                    .map(
                      (e) => ProofPhoto(path: photos[e.key], label: e.value),
                    ),
              ],
              const SizedBox(height: 24),
              Text(
                'Riwayat pengiriman',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              StreamBuilder<RecordSet<Map<String, dynamic>>>(
                stream: CargoStore.instance
                    .collection('shipments')
                    .doc(widget.docId)
                    .collection('events')
                    .orderBy('createdAt', descending: true)
                    .limit(100)
                    .snapshots(),
                builder: (context, events) {
                  if (events.hasError) return Text(errorText(events.error!));
                  if (!events.hasData) return const LinearProgressIndicator();
                  if (events.data!.docs.isEmpty) {
                    return const Text(
                      'Riwayat belum tersedia untuk pengiriman ini.',
                    );
                  }
                  return Column(
                    children: events.data!.docs.map((event) {
                      final e = event.data();
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.history, color: accent),
                          title: Text(e['note'] ?? e['status'] ?? ''),
                          subtitle: Text(
                            '${dateText(e['createdAt'])}\n${e['actorEmail'] ?? ''}',
                          ),
                          isThreeLine: true,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    ),
  );
}
