import '../services/backend_client.dart';
import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../core/shipment_policy.dart';
import '../services/shipment_service.dart';
import 'shipment_detail_page.dart';
import 'add_shipment_page.dart';

class ShipmentListPage extends StatefulWidget {
  const ShipmentListPage({
    super.key,
    this.courier = false,
    this.embedded = false,
    this.initialStatus = 'Semua',
  });
  final bool courier, embedded;
  final String initialStatus;
  @override
  State<ShipmentListPage> createState() => _ShipmentListPageState();
}

class _ShipmentListPageState extends State<ShipmentListPage> {
  String _search = '', _status = 'Semua';
  int _limit = 50;
  bool _finding = false;
  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
  }

  Future<void> _lookup() async {
    if (_finding) return;
    setState(() => _finding = true);
    try {
      final id = await ShipmentService.findByResi(
        _search,
        courier: widget.courier,
      );
      if (!mounted) return;
      if (id == null) {
        notify(
          context,
          'Nomor resi tidak ditemukan pada pengiriman yang dapat Anda akses.',
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ShipmentDetailPage(docId: id, courier: widget.courier),
        ),
      );
    } catch (e) {
      if (mounted) notify(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _finding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    RecordQuery<Map<String, dynamic>> query = CargoStore.instance.collection(
      'shipments',
    );
    if (widget.courier) {
      query = query.where(
        'courierId',
        isEqualTo: CargoAuth.instance.currentUser!.uid,
      );
    }
    if (_status != 'Semua') query = query.where('status', isEqualTo: _status);
    final body = PageBody(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _lookup(),
              decoration: InputDecoration(
                labelText: 'Cari pengiriman',
                hintText: 'Resi, penerima, atau alamat',
                helperText: 'Ikon panah mencari resi lengkap di seluruh data.',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _finding
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Cari resi di seluruh data',
                        onPressed: _lookup,
                        icon: const Icon(Icons.arrow_forward),
                      ),
              ),
              onChanged: (v) =>
                  setState(() => _search = v.trim().toLowerCase()),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['Semua', ...shipmentStatuses]
                  .map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s),
                        selected: _status == s,
                        onSelected: (_) => setState(() {
                          _status = s;
                          _limit = 50;
                        }),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<RecordSet<Map<String, dynamic>>>(
              stream: query
                  .orderBy('createdAt', descending: true)
                  .limit(_limit)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return EmptyState(
                    'Data tidak dapat dimuat',
                    errorText(snapshot.error!),
                    icon: Icons.cloud_off_outlined,
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs.where((doc) {
                  final d = doc.data();
                  return '${d['resi']} ${d['penerima']} ${d['alamat']}'
                      .toLowerCase()
                      .contains(_search);
                }).toList();
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (snapshot.data!.metadata.isFromCache)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Menampilkan data tersimpan. Perubahan memerlukan koneksi internet.',
                        ),
                      ),
                    if (docs.isEmpty)
                      const EmptyState(
                        'Belum ada pengiriman yang sesuai',
                        'Coba filter lain atau muat lebih banyak data.',
                      ),
                    ...docs.map((doc) {
                      final d = doc.data();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ShipmentDetailPage(
                                docId: doc.id,
                                courier: widget.courier,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        d['resi'] ?? doc.id,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ),
                                    StatusBadge(d['status'] ?? 'Pending'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  d['penerima'] ?? 'Penerima belum diisi',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(d['alamat'] ?? ''),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      dateText(d['createdAt']),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    if (!widget.courier)
                                      Text(
                                        'Kurir: ${d['courierEmail'] ?? 'Belum ditugaskan'}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                  ],
                                ),
                                if ((d['issue'] ?? '').toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Kendala: ${d['issue']}',
                                      style: TextStyle(
                                        color: Colors.orange.shade900,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (snapshot.data!.docs.length >= _limit)
                      OutlinedButton(
                        onPressed: () => setState(() => _limit += 50),
                        child: const Text('Muat 50 pengiriman berikutnya'),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Data pengiriman')),
      body: body,
      floatingActionButton: widget.courier
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddShipmentPage()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Pengiriman'),
            ),
    );
  }
}
