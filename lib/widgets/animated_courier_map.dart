import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/courier_motion.dart';

/// Interpolates only between confirmed GPS samples, never beyond the latest fix.
class AnimatedCourierMap extends StatefulWidget {
  const AnimatedCourierMap({
    super.key,
    required this.markers,
    required this.circles,
    required this.onMapCreated,
    this.selectedId,
  });
  final Set<Marker> markers;
  final Set<Circle> circles;
  final String? selectedId;
  final ValueChanged<GoogleMapController> onMapCreated;
  @override
  State<AnimatedCourierMap> createState() => _AnimatedCourierMapState();
}

class _AnimatedCourierMapState extends State<AnimatedCourierMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  Map<MarkerId, Marker> _from = {}, _targets = {};
  final Map<int, BitmapDescriptor> _icons = {};
  @override
  void initState() {
    super.initState();
    _targets = {for (final m in widget.markers) m.markerId: m};
    _from = Map.of(_targets);
    _loadIcons();
  }

  Future<void> _loadIcons() async {
    for (final entry in {
      0: const Color(0xFF087F8C),
      1: const Color(0xFFE3941C),
      2: const Color(0xFF77559C),
    }.entries) {
      final recorder = ui.PictureRecorder();
      // Render a heading-aware navigation marker at 3x density.
      final drawing = Canvas(recorder);
      drawing.drawCircle(
        const Offset(48, 48),
        43,
        Paint()..color = Colors.white,
      );
      drawing.drawCircle(
        const Offset(48, 48),
        38,
        Paint()..color = entry.value,
      );
      final arrow = Path()
        ..moveTo(48, 18)
        ..lineTo(25, 72)
        ..lineTo(48, 61)
        ..lineTo(71, 72)
        ..close();
      drawing.drawPath(arrow, Paint()..color = Colors.white);
      final picture = recorder.endRecording();
      final image = await picture.toImage(96, 96);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      if (!mounted) return;
      if (bytes != null) {
        setState(
          () => _icons[entry.key] = BitmapDescriptor.bytes(
            bytes.buffer.asUint8List(),
            imagePixelRatio: 3,
          ),
        );
      }
    }
  }

  Map<MarkerId, Marker> _rendered() {
    final t = _animation.isAnimating ? _animation.value : 1.0;
    return {
      for (final entry in _targets.entries)
        entry.key: _interpolate(
          _from[entry.key] ?? entry.value,
          entry.value,
          t,
        ),
    };
  }

  Marker _interpolate(Marker start, Marker end, double t) {
    final distance = positionDistance(start.position, end.position);
    final move = end.alpha == 1 && distance > 0.5 && distance < 1000;
    final color = end.alpha == 1
        ? 0
        : end.alpha > .5
        ? 1
        : 2;
    return end.copyWith(
      positionParam: move
          ? interpolatePosition(start.position, end.position, t)
          : end.position,
      rotationParam: move
          ? interpolateHeading(start.rotation, end.rotation, t)
          : end.rotation,
      iconParam: _icons[color] ?? end.icon,
      anchorParam: const Offset(.5, .5),
      flatParam: true,
    );
  }

  @override
  void didUpdateWidget(AnimatedCourierMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = {for (final m in widget.markers) m.markerId: m};
    final moved = next.entries.any(
      (e) => _targets[e.key]?.position != e.value.position,
    );
    if (moved) {
      _from = _rendered();
      _targets = next;
      _animation.forward(from: 0);
    } else {
      _targets = next;
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animation,
    builder: (context, _) {
      final rendered = _rendered();
      final selected = rendered[MarkerId(widget.selectedId ?? '')];
      return GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(-2.5489, 118.0149),
          zoom: 4.5,
        ),
        markers: rendered.values.toSet(),
        circles: widget.circles
            .map(
              (circle) => selected == null
                  ? circle
                  : circle.copyWith(centerParam: selected.position),
            )
            .toSet(),
        myLocationButtonEnabled: false,
        mapToolbarEnabled: false,
        zoomControlsEnabled: true,
        onMapCreated: widget.onMapCreated,
      );
    },
  );
}
