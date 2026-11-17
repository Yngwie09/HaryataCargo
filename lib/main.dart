import 'package:flutter/material.dart';
import 'app.dart';
import 'services/backend_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('PREVIEW_MODE')) {
    runApp(const CargoApp(preview: true));
    return;
  }
  try {
    await CargoAuth.instance.initialize();
    runApp(const CargoApp());
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: SelectableText(
                'Aplikasi belum dapat dimulai.\nPeriksa koneksi internet dan konfigurasi layanan.\n\n$error',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
