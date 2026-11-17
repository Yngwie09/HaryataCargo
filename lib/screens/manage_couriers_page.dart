import '../widgets/password_field.dart';
import '../widgets/password_dialog.dart';
import '../services/backend_client.dart';
import 'package:flutter/material.dart';
import '../core/ui.dart';

class ManageCouriersPage extends StatefulWidget {
  const ManageCouriersPage({super.key});
  @override
  State<ManageCouriersPage> createState() => _ManageCouriersPageState();
}

class _ManageCouriersPageState extends State<ManageCouriersPage> {
  String _search = '';
  bool _busy = false;
  final _functions = CargoActions.instance;
  Future<void> _edit({String? id, Map<String, dynamic>? data}) async {
    final form = GlobalKey<FormState>();
    final name = TextEditingController(text: data?['name'] ?? '');
    final email = TextEditingController(text: data?['email'] ?? '');
    final phone = TextEditingController(text: data?['phone'] ?? '');
    final password = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(id == null ? 'Tambah akun kurir' : 'Edit profil kurir'),
        content: SizedBox(
          width: 440,
          child: Form(
            key: form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Nama lengkap',
                    ),
                    maxLength: 120,
                    validator: (v) => (v?.trim().length ?? 0) < 2
                        ? 'Nama minimal 2 karakter'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: email,
                    readOnly: id != null,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) =>
                        RegExp(
                          r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                        ).hasMatch(v?.trim() ?? '')
                        ? null
                        : 'Email tidak valid',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phone,
                    decoration: const InputDecoration(labelText: 'Telepon'),
                    keyboardType: TextInputType.phone,
                    maxLength: 20,
                    validator: (v) =>
                        RegExp(
                          r'^\+?[0-9 ()-]{8,20}$',
                        ).hasMatch(v?.trim() ?? '')
                        ? null
                        : 'Telepon tidak valid',
                  ),
                  if (id == null) ...[
                    const SizedBox(height: 12),
                    PasswordField(
                      controller: password,
                      label: 'Kata sandi awal',
                      helperText: 'Bebas menggunakan huruf, angka, atau simbol',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      setState(() => _busy = true);
      try {
        if (id == null) {
          await _functions.httpsCallable('createCourier').call({
            'name': name.text.trim(),
            'email': email.text.trim(),
            'phone': phone.text.trim(),
            'password': password.text,
          });
        } else {
          await CargoStore.instance.collection('users').doc(id).update({
            'name': name.text.trim(),
            'phone': phone.text.trim(),
            'updatedAt': DataValue.serverTimestamp(),
          });
        }
        if (mounted) notify(context, 'Akun kurir berhasil disimpan.');
      } catch (e) {
        if (mounted) notify(context, errorText(e), error: true);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
  }

  Future<void> _toggle(String id, bool active) async {
    if (!await confirm(
      context,
      active ? 'Aktifkan akun?' : 'Nonaktifkan akun?',
      active
          ? 'Kurir dapat masuk dan menerima tugas kembali.'
          : 'Kurir tidak dapat mengakses aplikasi. Selesaikan atau pindahkan tugas yang masih aktif terlebih dahulu.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await _functions.httpsCallable('setCourierActive').call({
        'uid': id,
        'active': active,
      });
      if (mounted) notify(context, 'Status akun berhasil diperbarui.');
    } catch (e) {
      if (mounted) {
        notify(
          context,
          e is ApiException ? e.message ?? errorText(e) : errorText(e),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kelola kurir')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _busy ? null : () => _edit(),
      icon: const Icon(Icons.person_add_outlined),
      label: const Text('Tambah kurir'),
    ),
    body: PageBody(
      child: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Cari nama atau email',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) =>
                  setState(() => _search = v.toLowerCase().trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<RecordSet<Map<String, dynamic>>>(
              stream: CargoStore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'kurir')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return EmptyState(
                    'Data kurir tidak dapat dimuat',
                    errorText(snapshot.error!),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs
                    .where(
                      (d) => '${d.data()['name']} ${d.data()['email']}'
                          .toLowerCase()
                          .contains(_search),
                    )
                    .toList();
                if (docs.isEmpty) {
                  return const EmptyState(
                    'Belum ada kurir yang sesuai',
                    'Tambahkan akun kurir atau ubah pencarian.',
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  children: docs.map((doc) {
                    final d = doc.data(), active = d['active'] != false;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  child: Icon(Icons.person_outline),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d['name'] ?? 'Kurir',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      Text(d['email'] ?? ''),
                                      Text(d['phone'] ?? ''),
                                    ],
                                  ),
                                ),
                                Chip(
                                  label: Text(active ? 'Aktif' : 'Nonaktif'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                TextButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _edit(id: doc.id, data: d),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Edit profil'),
                                ),
                                TextButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => _toggle(doc.id, !active),
                                  icon: Icon(
                                    active
                                        ? Icons.block
                                        : Icons.check_circle_outline,
                                  ),
                                  label: Text(
                                    active ? 'Nonaktifkan' : 'Aktifkan',
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => showPasswordDialog(
                                          context,
                                          courierId: doc.id,
                                          courierName: d['name'] as String?,
                                        ),
                                  icon: const Icon(Icons.lock_reset),
                                  label: const Text('Reset sandi'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
