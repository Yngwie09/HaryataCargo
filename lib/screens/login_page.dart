import '../services/backend_client.dart';
import 'package:flutter/material.dart';
import '../core/ui.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.preview = false});
  final bool preview;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false, _hidden = true;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await CargoAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
    } catch (error) {
      if (mounted) notify(context, errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pemulihan akun'),
        content: const Text(
          'Hubungi admin Haryata Cargo untuk mereset kata sandi kurir melalui menu Kelola kurir. Jika Anda masih bisa masuk, ubah sandi dari Profil & pengaturan. Pemulihan admin tersedia melalui pengelola server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF102E40), Color(0xFF126774)],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 440,
            child: Column(
              children: [
                const Icon(
                  Icons.local_shipping_rounded,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 20),
                const Text(
                  'HARYATA CARGO',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 30,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pengiriman tertata. Serah terima tercatat.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _form,
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Selamat datang',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Masuk dengan akun yang diberikan administrator.',
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.username],
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                              validator: (v) =>
                                  RegExp(
                                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                  ).hasMatch(v?.trim() ?? '')
                                  ? null
                                  : 'Masukkan email yang valid',
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _password,
                              obscureText: _hidden,
                              autofillHints: const [AutofillHints.password],
                              onFieldSubmitted: (_) {
                                if (!_busy && !widget.preview) _login();
                              },
                              decoration: InputDecoration(
                                labelText: 'Kata sandi',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _hidden
                                      ? 'Tampilkan kata sandi'
                                      : 'Sembunyikan kata sandi',
                                  onPressed: () =>
                                      setState(() => _hidden = !_hidden),
                                  icon: Icon(
                                    _hidden
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (v) => v == null || v.isEmpty
                                  ? 'Kata sandi wajib diisi'
                                  : null,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _busy || widget.preview
                                    ? null
                                    : _reset,
                                child: const Text('Lupa kata sandi?'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: _busy || widget.preview
                                  ? null
                                  : _login,
                              child: _busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Masuk'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'PT. Haryata Cargo • Operasional pengiriman',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
