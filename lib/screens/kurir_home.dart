import '../services/backend_client.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/ui.dart';
import '../services/courier_location_service.dart';
import '../services/session_service.dart';
import 'settings_page.dart';
import 'tracking_diagnostics_page.dart';
import 'shipment_list_page.dart';

class KurirHome extends StatefulWidget {
  const KurirHome({super.key});
  @override
  State<KurirHome> createState() => _KurirHomeState();
}

class _KurirHomeState extends State<KurirHome> with WidgetsBindingObserver {
  final _location = CourierLocationService.instance;
  StreamSubscription<RecordSet<Map<String, dynamic>>>? _tasks;
  bool _hasActive = false;
  bool _recoveryBusy = false;
  Timer? _watchdog;
  int _taskRevision = 0;
  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycle =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    _watchdog = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_hasActive &&
          !_location.running &&
          _lifecycle == AppLifecycleState.resumed) {
        _recover();
      }
    });
    final uid = CargoAuth.instance.currentUser!.uid;
    _tasks = CargoStore.instance
        .collection('shipments')
        .where('courierId', isEqualTo: uid)
        .where('status', isEqualTo: 'Proses')
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) async {
            if (!mounted) return;
            // An empty offline cache is not proof that the active assignment ended.
            if (snapshot.metadata.isFromCache && snapshot.docs.isEmpty) return;
            final revision = ++_taskRevision;
            final wasActive = _hasActive;
            if (mounted) setState(() => _hasActive = snapshot.docs.isNotEmpty);
            if (_hasActive) {
              await _recover();
            } else if (wasActive || _location.running) {
              try {
                await _location.stop(courierId: uid);
              } catch (_) {
                if (mounted && revision == _taskRevision) {
                  _location.message.value =
                      'GPS berhenti; status server menunggu koneksi.';
                }
              }
            }
          },
          onError: (Object error) {
            _location.message.value =
                'Tugas tidak dapat disinkronkan. Periksa internet dan akses akun.';
          },
        );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    if (state == AppLifecycleState.resumed && _hasActive) _recover();
  }

  Future<void> _recover({bool force = false}) async {
    if (_recoveryBusy ||
        !_hasActive ||
        _lifecycle != AppLifecycleState.resumed) {
      return;
    }
    _recoveryBusy = true;
    try {
      if (force) await _location.stopLocal();
      final user = CargoAuth.instance.currentUser;
      if (user != null) {
        if (_location.running) {
          await _location.refresh(email: user.email ?? '');
        } else {
          await _location.start(courierId: user.uid, email: user.email ?? '');
        }
      }
    } catch (e) {
      if (mounted && _hasActive) notify(context, errorText(e), error: true);
    } finally {
      _recoveryBusy = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchdog?.cancel();
    _tasks?.cancel();
    _location.stopLocal();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_hasActive,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && _hasActive) {
        notify(
          context,
          'Pengantaran masih aktif. Gunakan tombol Beranda perangkat agar aplikasi tetap berjalan di latar belakang.',
        );
      }
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Tugas pengiriman'),
        actions: [
          IconButton(
            tooltip: 'Periksa pelacakan',
            icon: const Icon(Icons.troubleshoot),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TrackingDiagnosticsPage(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Profil & pengaturan',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SettingsPage(courier: true),
              ),
            ),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await SessionService.logout();
              } catch (e) {
                if (context.mounted) notify(context, errorText(e), error: true);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (kIsWeb)
            const MaterialBanner(
              content: Text(
                'Gunakan aplikasi Android untuk pelacakan selama aplikasi berada di latar belakang.',
              ),
              actions: [SizedBox.shrink()],
            ),
          if (_hasActive)
            Material(
              color: const Color(0xFFE5F4F2),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ValueListenableBuilder<String>(
                            valueListenable: _location.message,
                            builder: (_, message, _) => Text(message),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _recover(force: true),
                          child: const Text('Pulihkan'),
                        ),
                      ],
                    ),
                    const Text(
                      'Izinkan lokasi akurat dan akses latar belakang. Tetap jalankan aplikasi selama pengantaran.',
                      style: TextStyle(fontSize: 12),
                    ),
                    TextButton(
                      onPressed: () => Geolocator.openAppSettings(),
                      child: const Text('Buka izin lokasi'),
                    ),
                  ],
                ),
              ),
            ),
          const Expanded(
            child: ShipmentListPage(courier: true, embedded: true),
          ),
        ],
      ),
    ),
  );
}
