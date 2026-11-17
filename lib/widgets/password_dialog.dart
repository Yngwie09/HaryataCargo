import 'password_field.dart';
import 'package:flutter/material.dart';
import '../services/backend_client.dart';
import '../core/ui.dart';

Future<void> showPasswordDialog(
  BuildContext context, {
  String? courierId,
  String? courierName,
}) async {
  final current = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController();
  final form = GlobalKey<FormState>();
  var busy = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => PopScope(
        canPop: !busy,
        child: AlertDialog(
          title: Text(
            courierId == null
                ? 'Ubah kata sandi'
                : 'Reset sandi ${courierName ?? 'kurir'}',
          ),
          content: SizedBox(
            width: 420,
            child: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (courierId == null) ...[
                      PasswordField(
                        controller: current,
                        enabled: !busy,
                        label: 'Kata sandi saat ini',
                        validator: (v) => (v?.isEmpty ?? true)
                            ? 'Isi kata sandi saat ini'
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    PasswordField(
                      controller: password,
                      enabled: !busy,
                      label: 'Kata sandi baru',
                      helperText: 'Bebas menggunakan huruf, angka, atau simbol',
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Isi kata sandi' : null,
                    ),
                    const SizedBox(height: 16),
                    PasswordField(
                      controller: confirmation,
                      enabled: !busy,
                      label: 'Ulangi kata sandi baru',
                      validator: (v) =>
                          v == password.text ? null : 'Konfirmasi tidak sesuai',
                    ),
                    if (courierId != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Berikan sandi baru kepada kurir. Sesi login kurir pada perangkat lain akan diakhiri.',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setState(() => busy = true);
                      try {
                        if (courierId == null) {
                          await CargoAuth.instance.changePassword(
                            current.text,
                            password.text,
                          );
                        } else {
                          await CargoActions.instance
                              .httpsCallable('resetCourierPassword')
                              .call({
                                'uid': courierId,
                                'password': password.text,
                              });
                        }
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (context.mounted) {
                          notify(context, 'Kata sandi berhasil diperbarui.');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          notify(context, errorText(e), error: true);
                        }
                      } finally {
                        if (context.mounted) setState(() => busy = false);
                      }
                    },
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 300));
  current.dispose();
  password.dispose();
  confirmation.dispose();
}
