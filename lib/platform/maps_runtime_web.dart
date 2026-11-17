import 'dart:js_interop';
import 'maps_status.dart';
export 'maps_status.dart';

@JS('cargoMapsState')
external JSString? get _state;
@JS('location.reload')
external void _reload();
MapsLoadStatus mapsLoadStatus() => switch (_state?.toDart) {
  'ready' => MapsLoadStatus.ready,
  'missing-key' => MapsLoadStatus.missingKey,
  'network-error' => MapsLoadStatus.networkError,
  'auth-error' => MapsLoadStatus.authorizationError,
  _ => MapsLoadStatus.loading,
};
void reloadMaps() => _reload();
