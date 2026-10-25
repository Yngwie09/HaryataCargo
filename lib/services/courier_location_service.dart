import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class CourierLocationService {
  CourierLocationService._();

  static final CourierLocationService instance = CourierLocationService._();

  StreamSubscription<Position>? _positionSubscription;
  String? _courierId;
  void Function(Object error)? onError;

  Future<void> start({
    required String courierId,
    required String email,
  }) async {
    if (_positionSubscription != null && _courierId == courierId) return;

    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _courierId = courierId;

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _courierId = null;
      throw StateError('Aktifkan layanan lokasi/GPS untuk mulai berbagi lokasi.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _courierId = null;
      throw StateError(
        'Izin lokasi ditolak. Izinkan akses lokasi di pengaturan perangkat.',
      );
    }
    if (permission != LocationPermission.always) {
      _courierId = null;
      await Geolocator.openAppSettings();
      throw StateError(
        'Pelacakan latar belakang memerlukan izin lokasi "Selalu". '
        'Ubah izin lokasi aplikasi menjadi "Izinkan sepanjang waktu".',
      );
    }

    final settings = _locationSettings();
    try {
      final firstPosition = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      );
      await _savePosition(courierId, email, firstPosition);
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        (position) => _savePosition(courierId, email, position).catchError(
          (Object error) => onError?.call(error),
        ),
        onError: (Object error) => onError?.call(error),
      );
    } catch (_) {
      _courierId = null;
      rethrow;
    }
  }

  Future<void> stop({required String courierId}) async {
    if (_courierId != null && _courierId != courierId) return;

    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _courierId = null;
    await FirebaseFirestore.instance.collection('users').doc(courierId).update({
      'isTracking': false,
      'trackingStoppedAt': FieldValue.serverTimestamp(),
    });
  }

  LocationSettings _locationSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
        intervalDuration: const Duration(seconds: 15),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Pelacakan pengiriman aktif',
          notificationText: 'Lokasi Anda dibagikan kepada admin selama pengantaran.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }

    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 20,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20,
    );
  }

  Future<void> _savePosition(
    String courierId,
    String email,
    Position position,
  ) async {
    await FirebaseFirestore.instance.collection('users').doc(courierId).update({
      'email': email,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'locationUpdatedAt': FieldValue.serverTimestamp(),
      'isTracking': true,
    });
  }
}
