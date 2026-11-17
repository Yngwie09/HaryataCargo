import '../services/backend_client.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/ui.dart';
import '../models/courier_telemetry.dart';
import '../services/courier_location_service.dart';

class TrackingDiagnosticsPage extends StatefulWidget {
  const TrackingDiagnosticsPage({super.key});
  @override
  State<TrackingDiagnosticsPage> createState() =>
      _TrackingDiagnosticsPageState();
}

class _TrackingDiagnosticsPageState extends State<TrackingDiagnosticsPage>
    with WidgetsBindingObserver {
  final _checks = <String, ({bool ok, String detail})>{};
  bool _busy = false;
  Position? _testPosition;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inspect();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _inspect();
  }

  Future<void> _check(
    String key,
    Future<({bool ok, String detail})> Function() action,
  ) async {
    try {
      final value = await action().timeout(const Duration(seconds: 15));
      if (mounted) setState(() => _checks[key] = value);
    } catch (e) {
      if (mounted) {
        setState(() => _checks[key] = (ok: false, detail: errorText(e)));
      }
    }
  }

  Future<void> _inspect() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _check('GPS perangkat', () async {
      final enabled = await Geolocator.isLocationServiceEnabled();
      return (
        ok: enabled,
        detail: enabled
            ? 'Layanan lokasi aktif.'
            : 'GPS tidak aktif. Aktifkan melalui pengaturan lokasi.',
      );
    });
    await _check('Izin lokasi', () async {
      final p = await Geolocator.checkPermission();
      return (
        ok:
            p == LocationPermission.always ||
            p == LocationPermission.whileInUse,
        detail: switch (p) {
          LocationPermission.always => 'Diizinkan sepanjang waktu.',
          LocationPermission.whileInUse =>
            'Diizinkan saat aplikasi digunakan. Mulai pengantaran ketika aplikasi terbuka; periksa izin latar belakang untuk pemulihan.',
          LocationPermission.deniedForever =>
            'Diblokir. Ubah izin melalui pengaturan aplikasi.',
          _ => 'Belum diizinkan. Gunakan Uji GPS untuk meminta izin.',
        },
      );
    });
    final user = CargoAuth.instance.currentUser;
    if (user != null) {
      await _check('Akun dan akses server', () async {
        final p =
            (await CargoStore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get(const ReadOptions(source: ReadSource.server))
                    .timeout(const Duration(seconds: 12)))
                .data();
        return (
          ok: p?['role'] == 'kurir' && p?['active'] == true,
          detail: p?['role'] == 'kurir' && p?['active'] == true
              ? 'Akun kurir aktif. Layanan pelacakan dapat dihubungi.'
              : 'Akun tidak memiliki akses kurir aktif.',
        );
      });
      await _check('Posisi yang diterima server', () async {
        final doc = await CargoStore.instance
            .collection('courier_locations')
            .doc(user.uid)
            .get(const ReadOptions(source: ReadSource.server))
            .timeout(const Duration(seconds: 12));
        final p = CourierTelemetry.fromMap(user.uid, doc.data() ?? {});
        return (
          ok: p.signal(DateTime.now()) == CourierSignal.live,
          detail:
              '${p.label(DateTime.now())}\nGPS: ${dateText(p.fixAt)}\nSinkronisasi: ${dateText(p.updatedAt)}${p.hasPosition ? '\n${p.latitude!.toStringAsFixed(6)}, ${p.longitude!.toStringAsFixed(6)}' : ''}',
        );
      });
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _testGps() async {
    setState(() => _busy = true);
    try {
      final p = await CourierLocationService.instance.checkLocation();
      if (mounted) setState(() => _testPosition = p);
    } catch (e) {
      if (mounted) notify(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sync() async {
    setState(() => _busy = true);
    try {
      final user = CargoAuth.instance.currentUser!;
      final tasks = await CargoStore.instance
          .collection('shipments')
          .where('courierId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'Proses')
          .limit(1)
          .get(const ReadOptions(source: ReadSource.server))
          .timeout(const Duration(seconds: 12));
      if (tasks.docs.isEmpty) {
        throw StateError(
          'Belum ada pengantaran Proses. Mulai pengantaran sebelum membagikan lokasi.',
        );
      }
      final service = CourierLocationService.instance;
      if (!service.running) {
        await service.start(courierId: user.uid, email: user.email ?? '');
      }
      await service
          .synchronize(email: user.email ?? '')
          .timeout(const Duration(seconds: 35));
      if (mounted) {
        notify(
          context,
          'Server sudah menerima lokasi. Periksa koordinat yang sama di dashboard admin.',
        );
      }
    } catch (e) {
      if (mounted) notify(context, errorText(e), error: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _inspect();
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Periksa pelacakan')),
    body: PageBody(
      width: 760,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Pastikan posisi sampai ke admin',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'Uji GPS hanya membaca posisi di perangkat. Sinkronkan lokasi hanya membagikan posisi jika ada pengantaran aktif.',
          ),
          const SizedBox(height: 20),
          if (_busy) const LinearProgressIndicator(),
          ..._checks.entries.map(
            (entry) => Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Icon(
                  entry.value.ok
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  color: entry.value.ok ? accent : Colors.orange.shade800,
                ),
                title: Text(entry.key),
                subtitle: Text(entry.value.detail),
              ),
            ),
          ),
          if (_testPosition != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SelectableText(
                  'Hasil uji GPS\n${_testPosition!.latitude.toStringAsFixed(6)}, ${_testPosition!.longitude.toStringAsFixed(6)}\nAkurasi ±${_testPosition!.accuracy.round()} m\nWaktu ${dateText(_testPosition!.timestamp)}',
                ),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _inspect,
                icon: const Icon(Icons.refresh),
                label: const Text('Periksa ulang'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _testGps,
                icon: const Icon(Icons.gps_fixed),
                label: const Text('Uji GPS'),
              ),
              FilledButton.icon(
                onPressed: _busy ? null : _sync,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Sinkronkan lokasi'),
              ),
              TextButton(
                onPressed: () => Geolocator.openAppSettings(),
                child: const Text('Izin aplikasi'),
              ),
              TextButton(
                onPressed: () => Geolocator.openLocationSettings(),
                child: const Text('Pengaturan GPS'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Mulai pengantaran dari aplikasi yang sedang terbuka. Biarkan notifikasi pelacakan aktif. Izinkan aktivitas latar belakang dan sesuaikan penghemat baterai bila perangkat menghentikan lokasi. Setelah force-stop atau HP mati, buka kembali aplikasi untuk memulihkan pelacakan.',
          ),
        ],
      ),
    ),
  );
}
