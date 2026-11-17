import 'backend_client.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

typedef LocationWriter =
    Future<void> Function(String uid, Map<String, dynamic> data, bool merge);

class CourierLocationService {
  CourierLocationService._()
    : _locate = null,
      _positions = null,
      _writer = null,
      canStartForeground = null,
      writeTimeout = const Duration(seconds: 20);
  @visibleForTesting
  CourierLocationService.testing(
    this._locate,
    this._positions,
    this._writer, {
    this.writeTimeout = const Duration(seconds: 20),
    this.canStartForeground,
  });
  static final instance = CourierLocationService._();
  final Future<Position> Function()? _locate;
  final Stream<Position> Function(LocationSettings)? _positions;
  final LocationWriter? _writer;
  final Duration writeTimeout;
  final bool Function()? canStartForeground;
  final message = ValueNotifier<String>('Lokasi belum dibagikan');
  final lastSyncedAt = ValueNotifier<DateTime?>(null);
  StreamSubscription<Position>? _subscription;
  Timer? _heartbeat;
  String? _uid, _startingUid;
  Future<void>? _startTask;
  int _generation = 0;
  Completer<void> _sessionEnded = Completer<void>();
  int _newGeneration() {
    if (!_sessionEnded.isCompleted) _sessionEnded.complete();
    _sessionEnded = Completer<void>();
    return ++_generation;
  }

  int? _refreshGeneration;
  DateTime? _lastQueued;
  ({String uid, String email, Position position, int generation})? _pending;
  Future<void>? _drainTask;
  bool get running => _subscription != null;
  @visibleForTesting
  Future<void> get pendingWrites async {
    while (_drainTask != null) {
      await _drainTask;
    }
  }

  Future<Position> _currentPosition() =>
      _locate?.call() ??
      Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );

  Future<Position> checkLocation() async {
    if (_locate != null) return _locate();
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError(
        'GPS tidak aktif. Aktifkan lokasi perangkat lalu coba lagi.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError(
        'Izin lokasi diblokir. Buka pengaturan aplikasi dan izinkan lokasi akurat.',
      );
    }
    if (permission == LocationPermission.denied) {
      throw StateError('Izin lokasi diperlukan untuk pengantaran.');
    }
    return _currentPosition();
  }

  LocationSettings get _settings {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 2),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Haryata Cargo • Pengantaran aktif',
          notificationText:
              'Lokasi dibagikan kepada admin. Buka aplikasi untuk melihat tugas.',
          notificationIcon: AndroidResource(
            name: 'ic_tracking',
            defType: 'drawable',
          ),
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );
  }

  Future<void> start({required String courierId, required String email}) {
    if (_uid == courierId && running) return Future.value();
    if (_startingUid == courierId && _startTask != null) return _startTask!;
    _startingUid = courierId;
    final task = _start(courierId, email);
    _startTask = task;
    return task.whenComplete(() {
      if (identical(_startTask, task)) {
        _startTask = null;
        _startingUid = null;
      }
    });
  }

  Future<void> _start(String uid, String email) async {
    final generation = _newGeneration();
    final cleanup = _detach();
    _uid = uid;
    lastSyncedAt.value = null;
    message.value = 'Menyiapkan GPS…';
    try {
      await cleanup;
      if (generation != _generation) return;
      final first = await checkLocation();
      if (generation != _generation) return;
      if (!_valid(first)) {
        throw StateError(
          'GPS menghasilkan koordinat tidak valid. Coba lagi di area terbuka.',
        );
      }
      final visible =
          canStartForeground?.call() ??
          (_locate != null ||
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed);
      if (!visible) {
        throw StateError(
          'Buka aplikasi di layar depan untuk memulai kembali layanan lokasi.',
        );
      }
      _subscription =
          (_positions?.call(_settings) ??
                  Geolocator.getPositionStream(locationSettings: _settings))
              .listen(
                (position) {
                  if (generation == _generation) _queue(uid, email, position);
                },
                onError: (Object error) {
                  if (generation == _generation) {
                    message.value =
                        'Sinyal GPS bermasalah. Mencoba pembaruan otomatis.';
                  }
                },
                onDone: () {
                  if (generation == _generation) {
                    _subscription = null;
                    message.value =
                        'Stream GPS berhenti. Pulihkan saat aplikasi terbuka.';
                  }
                },
              );
      _heartbeat = Timer.periodic(const Duration(seconds: 15), (_) {
        if (generation == _generation) refresh(email: email);
      });
      message.value = 'GPS aktif • menunggu sinkronisasi server';
      // A slow/offline API connection must not delay the Android foreground service.
      _queue(uid, email, first);
    } catch (_) {
      if (generation == _generation) {
        await stopLocal();
        message.value = 'GPS belum aktif. Periksa izin dan layanan lokasi.';
      }
      rethrow;
    }
  }

  bool _valid(Position p) =>
      p.latitude.isFinite &&
      p.longitude.isFinite &&
      p.accuracy.isFinite &&
      p.latitude.abs() <= 90 &&
      p.longitude.abs() <= 180 &&
      p.accuracy >= 0;
  void _queue(String uid, String email, Position position) {
    if (_uid != uid ||
        !_valid(position) ||
        (_lastQueued != null && position.timestamp.isBefore(_lastQueued!))) {
      return;
    }
    _lastQueued = position.timestamp;
    // Coalesce GPS fixes instead of building an unbounded offline queue.
    _pending = (
      uid: uid,
      email: email,
      position: position,
      generation: _generation,
    );
    _ensureDrain();
  }

  void _ensureDrain() {
    if (_drainTask != null) return;
    _drainTask = _drain().whenComplete(() {
      _drainTask = null;
      if (_pending != null) _ensureDrain();
    });
  }

  Future<void> _drain() async {
    while (_pending != null) {
      final next = _pending!;
      _pending = null;
      if (next.generation != _generation || next.uid != _uid) continue;
      try {
        final operation = Future.any<void>([
          _save(next.uid, next.email, next.position, next.generation),
          _sessionEnded.future,
        ]);
        try {
          await operation.timeout(writeTimeout);
        } on TimeoutException {
          if (next.generation == _generation) {
            message.value =
                'GPS tetap aktif • koneksi server belum tersinkron. Menunggu sambungan pulih.';
          }
          // Keep one in-flight location request and coalesce the newest GPS fix.
          await operation;
        }
      } catch (_) {
        if (next.generation == _generation) {
          message.value =
              'GPS tetap aktif • koneksi server belum tersinkron. Mencoba lagi otomatis.';
        }
      }
    }
  }

  Future<void> refresh({required String email}) async {
    final generation = _generation;
    if (_uid == null || _refreshGeneration == generation) return;
    _refreshGeneration = generation;
    final uid = _uid!;
    try {
      final position = await _currentPosition();
      if (generation == _generation) _queue(uid, email, position);
    } catch (_) {
      if (generation == _generation) {
        message.value =
            'Sinyal GPS belum tersedia. Admin tetap melihat posisi terakhir.';
      }
    } finally {
      if (_refreshGeneration == generation) _refreshGeneration = null;
    }
  }

  Future<void> synchronize({required String email}) async {
    final before = lastSyncedAt.value;
    await refresh(email: email);
    await pendingWrites;
    if (lastSyncedAt.value == before) {
      throw StateError(
        'GPS belum berhasil disinkronkan ke server. Periksa koneksi dan waktu perangkat.',
      );
    }
  }

  Future<void> _write(
    String uid,
    Map<String, dynamic> data, {
    bool merge = false,
  }) async {
    if (_writer != null) {
      await _writer(uid, data, merge);
      return;
    }
    await CargoStore.instance
        .collection('courier_locations')
        .doc(uid)
        .set(data, WriteOptions(merge: merge));
  }

  Future<void> _save(
    String uid,
    String email,
    Position p,
    int generation,
  ) async {
    await _write(uid, {
      'courierId': uid,
      'email': email,
      'latitude': p.latitude,
      'longitude': p.longitude,
      'accuracy': p.accuracy,
      'heading': p.heading.isFinite ? p.heading : 0,
      'speed': p.speed.isFinite ? p.speed : 0,
      'fixAt': DataTimestamp.fromDate(p.timestamp),
      'updatedAt': DataValue.serverTimestamp(),
      'isTracking': true,
    });
    if (generation == _generation && _uid == uid) {
      lastSyncedAt.value = DateTime.now();
      message.value = 'Lokasi tersinkron • akurasi ±${p.accuracy.round()} m';
    }
  }

  Future<void> _detach() {
    _pending = null;
    _lastQueued = null;
    _refreshGeneration = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    final subscription = _subscription;
    _subscription = null;
    _uid = null;
    return subscription?.cancel() ?? Future.value();
  }

  Future<void> stopLocal() async {
    final generation = _newGeneration();
    _startTask = null;
    _startingUid = null;
    await _detach();
    if (generation == _generation) {
      message.value = 'Tidak ada pengantaran aktif';
    }
  }

  Future<void> stop({required String courierId}) async {
    // Never let an old session stop a newer courier's stream.
    if (_uid != null && _uid != courierId) return;
    final generation = _generation + 1;
    await stopLocal();
    if (generation != _generation) return;
    await _write(courierId, {
      'courierId': courierId,
      'isTracking': false,
      'stoppedAt': DataValue.serverTimestamp(),
    }, merge: true).timeout(writeTimeout);
  }
}
