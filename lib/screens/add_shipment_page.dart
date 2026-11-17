import '../services/backend_client.dart';
import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../core/shipment_policy.dart';
import '../services/shipment_service.dart';

class AddShipmentPage extends StatefulWidget {
  const AddShipmentPage({super.key, this.docId, this.initial});
  final String? docId;
  final Map<String, dynamic>? initial;
  @override
  State<AddShipmentPage> createState() => _AddShipmentPageState();
}

class _AddShipmentPageState extends State<AddShipmentPage> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  String? _courier;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    for (final key in [
      'resi',
      'penerima',
      'phone',
      'alamat',
      'sender',
      'weight',
      'pieces',
      'notes',
    ]) {
      _fields[key] = TextEditingController(
        text: widget.initial?[key]?.toString() ?? (key == 'pieces' ? '1' : ''),
      );
    }
    _courier = widget.initial?['courierId'];
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final fields = <String, dynamic>{
        for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
        'courierId': _courier,
      };
      fields['weight'] = double.parse(
        _fields['weight']!.text.replaceAll(',', '.'),
      );
      fields['pieces'] = int.parse(_fields['pieces']!.text);
      if (widget.docId == null) {
        await ShipmentService.create(fields);
      } else {
        fields.remove('resi');
        await ShipmentService.editPending(widget.docId!, fields);
      }
      if (mounted) {
        notify(context, 'Pengiriman berhasil disimpan.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) notify(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String key,
    String label, {
    int lines = 1,
    bool required = true,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: _fields[key],
      maxLines: lines,
      readOnly: key == 'resi' && widget.docId != null,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label),
      validator: (v) {
        final value = v?.trim() ?? '';
        if (required && value.isEmpty) return 'Kolom ini wajib diisi';
        if (value.length > (key == 'notes' || key == 'alamat' ? 1000 : 120)) {
          return 'Teks terlalu panjang';
        }
        if (key == 'resi' && !validResi(normalizeResi(value))) {
          return 'Gunakan 4–40 huruf, angka, atau tanda hubung';
        }
        if (key == 'weight' &&
            (!(double.tryParse(value.replaceAll(',', '.')) ?? 0).isFinite ||
                (double.tryParse(value.replaceAll(',', '.')) ?? 0) <= 0 ||
                (double.tryParse(value.replaceAll(',', '.')) ?? 0) > 100000)) {
          return 'Berat harus lebih dari 0 dan maksimal 100.000 kg';
        }
        if (key == 'pieces' &&
            ((int.tryParse(value) ?? 0) < 1 ||
                (int.tryParse(value) ?? 0) > 10000)) {
          return 'Jumlah koli harus 1–10.000';
        }
        if (key == 'phone' &&
            !RegExp(r'^\+?[0-9 ()-]{8,20}$').hasMatch(value)) {
          return 'Nomor telepon tidak valid';
        }
        return null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.docId == null ? 'Buat pengiriman' : 'Edit pengiriman'),
    ),
    body: PageBody(
      width: 720,
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Informasi pengiriman',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Pastikan data penerima benar. Kurir hanya dapat melihat paket yang ditugaskan kepadanya.',
            ),
            const SizedBox(height: 24),
            _field('resi', 'Nomor resi'),
            _field('sender', 'Nama pengirim'),
            _field('penerima', 'Nama penerima'),
            _field('phone', 'Telepon penerima', keyboard: TextInputType.phone),
            _field('alamat', 'Alamat lengkap & patokan', lines: 3),
            Row(
              children: [
                Expanded(
                  child: _field(
                    'weight',
                    'Berat (kg)',
                    keyboard: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _field(
                    'pieces',
                    'Jumlah koli',
                    keyboard: TextInputType.number,
                  ),
                ),
              ],
            ),
            StreamBuilder<RecordSet<Map<String, dynamic>>>(
              stream: CargoStore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'kurir')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(errorText(snapshot.error!)),
                  );
                }
                final docs =
                    snapshot.data?.docs
                        .where((d) => d.data()['active'] != false)
                        .toList() ??
                    [];
                final selected = docs.any((d) => d.id == _courier)
                    ? _courier
                    : null;
                return DropdownButtonFormField<String>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Kurir penanggung jawab',
                  ),
                  hint: Text(
                    snapshot.hasData ? 'Pilih kurir aktif' : 'Memuat kurir…',
                  ),
                  items: docs
                      .map(
                        (d) => DropdownMenuItem(
                          value: d.id,
                          child: Text(
                            '${d.data()['name'] ?? d.data()['email']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _busy ? null : (v) => setState(() => _courier = v),
                  validator: (_) =>
                      _courier == null || !docs.any((d) => d.id == _courier)
                      ? 'Pilih kurir aktif terlebih dahulu'
                      : null,
                );
              },
            ),
            const SizedBox(height: 16),
            _field(
              'notes',
              'Catatan pengiriman (opsional)',
              lines: 3,
              required: false,
            ),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_busy ? 'Menyimpan…' : 'Simpan pengiriman'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}
