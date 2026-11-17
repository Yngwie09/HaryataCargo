import '../services/backend_client.dart';
import '../services/live_tracking.dart';
import '../widgets/animated_courier_map.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/ui.dart';
import '../models/courier_telemetry.dart';
import '../platform/maps_runtime_stub.dart'
    if (dart.library.js_interop) '../platform/maps_runtime_web.dart'
    as maps;

class CourierTrackingPage extends StatefulWidget {
  const CourierTrackingPage({super.key});
  @override
  State<CourierTrackingPage> createState() => _CourierTrackingPageState();
}

class _CourierTrackingPageState extends State<CourierTrackingPage> {
  late final _couriers = CargoStore.instance
      .collection('users')
      .where('role', isEqualTo: 'kurir')
      .snapshots();
  late final _locations = watchCourierLocations();
  GoogleMapController? _map;
  Timer? _timer;
  String? _selected;
  String _search = '';
  bool _initialFit = false, _ready = false, _follow = true;
  DateTime? _lastFollowFix;
  String? _mapError;
  final _mapRequestedAt = DateTime.now();
  maps.MapsLoadStatus get _sdkState {
    final status = maps.mapsLoadStatus();
    if (status == maps.MapsLoadStatus.loading &&
        DateTime.now().difference(_mapRequestedAt).inSeconds >= 30) {
      return maps.MapsLoadStatus.networkError;
    }
    return status;
  }

  @override
  void initState() {
    super.initState();
    _poll();
  }

  void _poll() {
    _timer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {});
        _poll();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    // GoogleMap owns and disposes its controller when removed from the tree.
    super.dispose();
  }

  LatLng _point(CourierTelemetry p) => LatLng(p.latitude!, p.longitude!);
  Future<void> _focus(CourierTelemetry p, {bool zoom = true}) async {
    if (!p.hasPosition) return;
    try {
      await _map?.animateCamera(
        zoom
            ? CameraUpdate.newLatLngZoom(_point(p), 16)
            : CameraUpdate.newLatLng(_point(p)),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _mapError =
              'Peta belum siap. Muat ulang halaman setelah memeriksa koneksi.',
        );
      }
    }
  }

  void _select(String uid, CourierTelemetry? p) {
    setState(() {
      _selected = uid;
      _lastFollowFix = p?.fixAt;
      _follow = true;
    });
    if (p != null) _focus(p);
  }

  Future<void> _fit(List<CourierTelemetry> all) async {
    final positions = all.where((p) => p.hasPosition).map(_point).toList();
    if (positions.isEmpty || _map == null) return;
    if (positions.length == 1) {
      await _map?.animateCamera(
        CameraUpdate.newLatLngZoom(positions.first, 14),
      );
      return;
    }
    final minLat = positions.map((p) => p.latitude).reduce(math.min),
        maxLat = positions.map((p) => p.latitude).reduce(math.max);
    final minLng = positions.map((p) => p.longitude).reduce(math.min),
        maxLng = positions.map((p) => p.longitude).reduce(math.max);
    try {
      await _map!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              (minLat - .001).clamp(-90, 90),
              (minLng - .001).clamp(-180, 180),
            ),
            northeast: LatLng(
              (maxLat + .001).clamp(-90, 90),
              (maxLng + .001).clamp(-180, 180),
            ),
          ),
          60,
        ),
      );
    } catch (_) {
      /* The map may still be laying out. The fit button remains available. */
    }
  }

  Widget _sdkUnavailable(maps.MapsLoadStatus status) {
    final (title, message) = switch (status) {
      maps.MapsLoadStatus.missingKey => (
        'Google Maps belum dikonfigurasi',
        'Isi key Maps JavaScript API pada konfigurasi proyek baru, lalu build ulang. Posisi kurir tetap tersedia pada daftar.',
      ),
      maps.MapsLoadStatus.authorizationError => (
        'Google Maps menolak akses',
        'Periksa billing, Maps JavaScript API, dan pembatasan domain pada API key di Google Cloud. Posisi kurir tetap tersedia pada daftar.',
      ),
      _ => (
        'Google Maps belum dapat dimuat',
        'Periksa koneksi internet. Muat ulang halaman untuk mencoba lagi. Posisi terakhir kurir tetap tersedia pada daftar.',
      ),
    };
    return EmptyState(
      title,
      message,
      icon: Icons.map_outlined,
      action: OutlinedButton.icon(
        onPressed: kIsWeb ? maps.reloadMaps : null,
        icon: const Icon(Icons.refresh),
        label: const Text('Muat ulang halaman'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pantau kurir')),
    body: StreamBuilder<RecordSet<Map<String, dynamic>>>(
      stream: _couriers,
      builder: (context, users) {
        if (users.hasError) {
          return EmptyState(
            'Daftar kurir tidak dapat dimuat',
            errorText(users.error!),
          );
        }
        if (!users.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return StreamBuilder<RecordSet<Map<String, dynamic>>>(
          stream: _locations,
          builder: (context, locations) {
            if (locations.hasError) {
              return EmptyState(
                'Lokasi tidak dapat dimuat',
                errorText(locations.error!),
              );
            }
            if (!locations.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = {
              for (final doc in locations.data!.docs)
                doc.id: CourierTelemetry.fromMap(doc.id, doc.data()),
            };
            final now = DateTime.now(),
                cached = locations.data!.metadata.isFromCache;
            final markers = <Marker>{};
            final positions = <CourierTelemetry>[];
            for (final courier in users.data!.docs) {
              final p = data[courier.id];
              if (p == null || !p.hasPosition) continue;
              positions.add(p);
              final live =
                  p.signal(now, fromCache: cached) == CourierSignal.live;
              markers.add(
                Marker(
                  markerId: MarkerId(courier.id),
                  position: _point(p),
                  rotation: p.heading,
                  alpha: live
                      ? 1
                      : p.tracking
                      ? .65
                      : .45,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    live
                        ? BitmapDescriptor.hueAzure
                        : p.tracking
                        ? BitmapDescriptor.hueOrange
                        : BitmapDescriptor.hueViolet,
                  ),
                  infoWindow: InfoWindow(
                    title:
                        courier.data()['name'] ??
                        courier.data()['email'] ??
                        'Kurir',
                    snippet:
                        '${p.label(now, fromCache: cached)} • ${dateText(p.fixAt)}',
                  ),
                  onTap: () => _select(courier.id, p),
                ),
              );
            }
            if (!_initialFit && _ready && positions.isNotEmpty) {
              _initialFit = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _fit(positions);
              });
            }
            final selected = data[_selected];
            if (_ready &&
                _follow &&
                selected?.hasPosition == true &&
                selected!.fixAt != _lastFollowFix) {
              _lastFollowFix = selected.fixAt;
              final selectedId = _selected;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _follow && _selected == selectedId) {
                  _focus(selected, zoom: false);
                }
              });
            }
            final sdk = _sdkState;
            if (sdk != maps.MapsLoadStatus.ready) {
              _map = null;
              _ready = false;
              _initialFit = false;
            }
            final supported =
                kIsWeb ||
                defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS;
            final map = Stack(
              children: [
                if (!supported)
                  const EmptyState(
                    'Peta tidak tersedia pada platform ini',
                    'Gunakan browser atau Android.',
                  )
                else if (sdk == maps.MapsLoadStatus.loading)
                  const EmptyState(
                    'Menyiapkan Google Maps',
                    'Daftar posisi tetap dapat digunakan selama peta dimuat.',
                    action: CircularProgressIndicator(),
                  )
                else if (sdk != maps.MapsLoadStatus.ready)
                  _sdkUnavailable(sdk)
                else
                  AnimatedCourierMap(
                    selectedId: _selected,
                    markers: markers,
                    circles: {
                      if (selected?.hasPosition == true &&
                          selected!.hasAccuracy)
                        Circle(
                          circleId: const CircleId('accuracy'),
                          center: _point(selected),
                          radius: selected.accuracy!.clamp(0, 5000),
                          fillColor: accent.withValues(alpha: .12),
                          strokeColor: accent,
                          strokeWidth: 1,
                        ),
                    },
                    onMapCreated: (controller) {
                      _map = controller;
                      if (mounted) {
                        setState(() {
                          _ready = true;
                          _initialFit = false;
                          _mapError = null;
                        });
                      }
                    },
                  ),
                if (sdk == maps.MapsLoadStatus.ready) ...[
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _mapError ??
                              '${markers.length} posisi • Hijau: live • Jingga: terlambat • Ungu: berhenti',
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'fit',
                      tooltip: 'Tampilkan semua kurir',
                      onPressed: () {
                        setState(() => _follow = false);
                        _fit(positions);
                      },
                      child: const Icon(Icons.center_focus_strong),
                    ),
                  ),
                ],
              ],
            );
            final couriers = users.data!.docs
                .where(
                  (d) => '${d.data()['name']} ${d.data()['email']}'
                      .toLowerCase()
                      .contains(_search),
                )
                .toList();
            final panel = Material(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lokasi operasional',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Lokasi diperbarui langsung saat kurir mengantar. Pilih kurir untuk mengikuti perjalanannya. Saat koneksi terputus, posisi terakhir tetap tersedia.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Cari kurir',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (value) => setState(
                            () => _search = value.trim().toLowerCase(),
                          ),
                        ),
                        if (cached)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Dashboard belum terhubung ke server',
                              style: TextStyle(color: Colors.deepOrange),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_selected != null)
                    SwitchListTile(
                      dense: true,
                      title: const Text('Ikuti pergerakan kurir dipilih'),
                      value: _follow,
                      onChanged: (v) => setState(() {
                        _follow = v;
                        _lastFollowFix = null;
                      }),
                    ),
                  const Divider(height: 1),
                  Expanded(
                    child: couriers.isEmpty
                        ? const EmptyState(
                            'Tidak ada kurir yang sesuai',
                            'Ubah pencarian atau tambahkan akun kurir.',
                          )
                        : ListView.builder(
                            itemCount: couriers.length,
                            itemBuilder: (context, index) {
                              final courier = couriers[index],
                                  profile = courier.data(),
                                  p = data[courier.id];
                              final valid = p?.hasPosition == true,
                                  live =
                                      p?.signal(now, fromCache: cached) ==
                                      CourierSignal.live;
                              return Container(
                                color: _selected == courier.id
                                    ? accent.withValues(alpha: .08)
                                    : null,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  leading: Icon(
                                    Icons.person_pin_circle_outlined,
                                    color: live
                                        ? accent
                                        : Colors.orange.shade800,
                                  ),
                                  title: Text(
                                    profile['name'] ??
                                        profile['email'] ??
                                        'Kurir',
                                  ),
                                  subtitle: Text(
                                    '${p?.label(now, fromCache: cached) ?? 'Belum ada lokasi'}\n'
                                    '${valid ? 'GPS: ${dateText(p!.fixAt)}\nSinkron: ${dateText(p.updatedAt)}\n${p.latitude!.toStringAsFixed(6)}, ${p.longitude!.toStringAsFixed(6)}${p.hasAccuracy ? ' • ±${p.accuracy!.round()} m' : ''}' : 'Mulai pengantaran untuk berbagi lokasi'}',
                                  ),
                                  onTap: valid
                                      ? () => _select(courier.id, p)
                                      : null,
                                  trailing: valid
                                      ? IconButton(
                                          tooltip:
                                              'Buka koordinat di Google Maps',
                                          icon: const Icon(Icons.open_in_new),
                                          onPressed: () async {
                                            try {
                                              final ok = await launchUrl(
                                                Uri.https(
                                                  'www.google.com',
                                                  '/maps/search/',
                                                  {
                                                    'api': '1',
                                                    'query':
                                                        '${p!.latitude},${p.longitude}',
                                                  },
                                                ),
                                                mode: LaunchMode
                                                    .externalApplication,
                                              );
                                              if (!ok && context.mounted) {
                                                notify(
                                                  context,
                                                  'Google Maps tidak dapat dibuka.',
                                                  error: true,
                                                );
                                              }
                                            } catch (error) {
                                              if (context.mounted) {
                                                notify(
                                                  context,
                                                  errorText(error),
                                                  error: true,
                                                );
                                              }
                                            }
                                          },
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
            return LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth > 900
                  ? Row(
                      children: [
                        Expanded(child: map),
                        SizedBox(width: 380, child: panel),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(flex: 5, child: map),
                        Expanded(flex: 5, child: panel),
                      ],
                    ),
            );
          },
        );
      },
    ),
  );
}
