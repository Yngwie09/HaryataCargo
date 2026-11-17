import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

double interpolateHeading(double start, double end, double progress) {
  final delta = (end - start + 540) % 360 - 180;
  return (start + delta * progress.clamp(0, 1) + 360) % 360;
}

LatLng interpolatePosition(LatLng start, LatLng end, double progress) {
  final t = progress.clamp(0, 1);
  final longitudeDelta = (end.longitude - start.longitude + 540) % 360 - 180;
  return LatLng(
    start.latitude + (end.latitude - start.latitude) * t,
    (start.longitude + longitudeDelta * t + 540) % 360 - 180,
  );
}

double positionDistance(LatLng start, LatLng end) {
  const radians = math.pi / 180;
  final dy = (end.latitude - start.latitude) * radians;
  final dx = (end.longitude - start.longitude) * radians;
  final a =
      math.pow(math.sin(dy / 2), 2) +
      math.cos(start.latitude * radians) *
          math.cos(end.latitude * radians) *
          math.pow(math.sin(dx / 2), 2);
  return 6371000 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
}
