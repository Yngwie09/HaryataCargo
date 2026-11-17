import '../services/backend_client.dart';
import 'dart:async';
import 'package:flutter/material.dart';

const brand = Color(0xFF123E52);
const accent = Color(0xFF087F8C);

ThemeData cargoTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: brand,
    primary: brand,
    secondary: accent,
  ),
  scaffoldBackgroundColor: const Color(0xFFF3F6F8),
  appBarTheme: const AppBarTheme(
    backgroundColor: brand,
    foregroundColor: Colors.white,
    centerTitle: false,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
);

String errorText(Object error) {
  if (error is TimeoutException) {
    return 'Koneksi terlalu lama. Periksa internet lalu coba lagi.';
  }
  if (error is ApiException && error.message != null) {
    return error.message!;
  }
  if (error is ApiException) {
    return switch (error.code) {
      'permission-denied' ||
      'unauthorized' => 'Akses ditolak. Periksa akun dan izin Anda.',
      'unavailable' || 'network-request-failed' =>
        'Koneksi terputus. Periksa internet lalu coba lagi.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Email atau kata sandi tidak sesuai.',
      'email-already-in-use' => 'Email sudah digunakan oleh akun lain.',
      'weak-password' => 'Gunakan kata sandi yang lebih kuat.',
      'invalid-email' => 'Format email tidak valid.',
      'too-many-requests' =>
        'Terlalu banyak percobaan. Silakan coba beberapa saat lagi.',
      'user-disabled' => 'Akun dinonaktifkan. Hubungi administrator.',
      'failed-precondition' =>
        'Layanan belum siap. Hubungi administrator untuk memeriksa konfigurasi.',
      _ => 'Operasi gagal (${error.code}). Silakan coba lagi.',
    };
  }
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}

void notify(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red.shade800 : brand,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

String dateText(dynamic value) {
  final date = value is DataTimestamp
      ? value.toDate().toLocal()
      : value is DateTime
      ? value.toLocal()
      : null;
  if (date == null) return 'Menunggu sinkronisasi';
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${pad(date.day)}/${pad(date.month)}/${date.year} ${pad(date.hour)}:${pad(date.minute)}';
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child, this.width = 1100});
  final Widget child;
  final double width;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: child,
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.title,
    this.message, {
    super.key,
    this.icon = Icons.inbox_outlined,
    this.action,
  });
  final String title, message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: accent),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          if (action != null)
            Padding(padding: const EdgeInsets.only(top: 16), child: action!),
        ],
      ),
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Selesai' => Colors.green,
      'Proses' => Colors.blue,
      'Batal' => Colors.red,
      'Retur' => Colors.purple,
      'Tertunda' => Colors.deepOrange,
      _ => Colors.orange,
    };
    return Chip(
      label: Text(
        status,
        style: TextStyle(color: color.shade800, fontWeight: FontWeight.w600),
      ),
      backgroundColor: color.shade50,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    ) ??
    false;
