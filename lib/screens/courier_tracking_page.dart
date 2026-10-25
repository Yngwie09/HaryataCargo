import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CourierTrackingPage extends StatefulWidget {
  const CourierTrackingPage({super.key});

  @override
  State<CourierTrackingPage> createState() => _CourierTrackingPageState();
}

class _CourierTrackingPageState extends State<CourierTrackingPage> {
  static const _initialPosition = LatLng(-6.200000, 106.816666);
  GoogleMapController? _mapController;
  String _lastCourierIds = '';
  List<LatLng> _latestPositions = [];
  Timer? _staleLocationTimer;

  @override
  void initState() {
    super.initState();
    _staleLocationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _staleLocationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pantau Kurir',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'kurir')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Gagal memuat lokasi kurir: ${snapshot.error}'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final couriers = snapshot.data!.docs.where((doc) {
            final data = doc.data();
            final updatedAt = data['locationUpdatedAt'];
            return data['isTracking'] == true &&
                data['latitude'] is num &&
                data['longitude'] is num &&
                updatedAt is Timestamp &&
                DateTime.now().difference(updatedAt.toDate()).inMinutes < 2;
          }).toList();

          _latestPositions = couriers.map((doc) {
            final data = doc.data();
            return LatLng(
              (data['latitude'] as num).toDouble(),
              (data['longitude'] as num).toDouble(),
            );
          }).toList();
          final courierIds = couriers.map((doc) => doc.id).toList()..sort();
          final courierIdsSignature = courierIds.join(',');
          if (courierIdsSignature != _lastCourierIds) {
            _lastCourierIds = courierIdsSignature;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fitCouriers();
            });
          }

          final markers = couriers.map((doc) {
            final data = doc.data();
            final email = (data['email'] ?? 'Kurir').toString();
            final lat = (data['latitude'] as num).toDouble();
            final lng = (data['longitude'] as num).toDouble();
            final updatedAt = data['locationUpdatedAt'];
            final updatedLabel = updatedAt is Timestamp
                ? _formatTimestamp(updatedAt)
                : 'Baru saja';

            return Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: email,
                snippet: 'Lokasi diperbarui $updatedLabel',
              ),
            );
          }).toSet();

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _initialPosition,
                  zoom: 11,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                  _fitCouriers();
                },
                markers: markers,
                myLocationButtonEnabled: false,
                mapToolbarEnabled: false,
              ),
              SafeArea(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, color: Color(0xFF1E3A8A)),
                      const SizedBox(width: 8),
                      Text(
                        couriers.isEmpty
                            ? 'Tidak ada kurir yang sedang mengantar'
                            : '${couriers.length} kurir sedang mengantar',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _fitCouriers() {
    final controller = _mapController;
    if (controller == null || _latestPositions.isEmpty) return;

    final samePosition = _latestPositions.every(
      (position) =>
          position.latitude == _latestPositions.first.latitude &&
          position.longitude == _latestPositions.first.longitude,
    );
    if (_latestPositions.length == 1 || samePosition) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(_latestPositions.first, 15),
      );
      return;
    }

    var south = _latestPositions.first.latitude;
    var north = south;
    var west = _latestPositions.first.longitude;
    var east = west;
    for (final position in _latestPositions.skip(1)) {
      if (position.latitude < south) south = position.latitude;
      if (position.latitude > north) north = position.latitude;
      if (position.longitude < west) west = position.longitude;
      if (position.longitude > east) east = position.longitude;
    }
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(south, west),
          northeast: LatLng(north, east),
        ),
        64,
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate().toLocal();
    final datePart =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
    final timePart =
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    return '$datePart $timePart';
  }
}
