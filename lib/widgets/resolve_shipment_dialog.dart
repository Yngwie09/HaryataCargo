import 'package:flutter/material.dart';
import '../core/ui.dart';

class CourierChoice {
  const CourierChoice(this.id, this.name);
  final String id, name;
}

class ShipmentResolution {
  const ShipmentResolution({
    required this.retry,
    required this.reason,
    this.courierId,
  });
  final bool retry;
  final String reason;
  final String? courierId;
}

class ResolveShipmentDialog extends StatefulWidget {
  const ResolveShipmentDialog({
    super.key,
    required this.couriers,
    this.initialCourierId,
  });
  final Stream<List<CourierChoice>> couriers;
  final String? initialCourierId;
  @override
  State<ResolveShipmentDialog> createState() => _ResolveShipmentDialogState();
}

class _ResolveShipmentDialogState extends State<ResolveShipmentDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  bool _retry = true;
  String? _courierId;
  @override
  void initState() {
    super.initState();
    _courierId = widget.initialCourierId;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tindak lanjut pengiriman'),
    content: SizedBox(
      width: 460,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<bool>(
                initialValue: _retry,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tindakan'),
                items: const [
                  DropdownMenuItem(
                    value: true,
                    child: Text('Jadwalkan pengantaran ulang'),
                  ),
                  DropdownMenuItem(
                    value: false,
                    child: Text('Tandai barang diretur'),
                  ),
                ],
                onChanged: (value) => setState(() => _retry = value ?? true),
              ),
              const SizedBox(height: 16),
              if (_retry)
                StreamBuilder<List<CourierChoice>>(
                  stream: widget.couriers,
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? [];
                    final selected = items.any((c) => c.id == _courierId)
                        ? _courierId
                        : null;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(items.map((c) => c.id).join(',')),
                        initialValue: selected,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Kurir penanggung jawab',
                        ),
                        hint: Text(
                          snapshot.hasError
                              ? errorText(snapshot.error!)
                              : snapshot.hasData
                              ? 'Pilih kurir aktif'
                              : 'Memuat kurir…',
                        ),
                        items: items
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(
                                  c.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _courierId = value),
                        validator: (_) => selected == null
                            ? 'Pilih kurir aktif terlebih dahulu'
                            : null,
                      ),
                    );
                  },
                ),
              TextFormField(
                controller: _reason,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Catatan tindak lanjut',
                ),
                validator: (value) => (value?.trim().length ?? 0) < 5
                    ? 'Catatan minimal 5 karakter'
                    : null,
              ),
              const Text(
                'Pengantaran ulang mengembalikan status ke Pending. Kurir yang dipilih memulai pengantaran kembali.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Kembali'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(
              context,
              ShipmentResolution(
                retry: _retry,
                reason: _reason.text.trim(),
                courierId: _retry ? _courierId : null,
              ),
            );
          }
        },
        child: const Text('Simpan tindak lanjut'),
      ),
    ],
  );
}
