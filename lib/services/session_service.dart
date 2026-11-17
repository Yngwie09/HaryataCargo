import 'backend_client.dart';
import 'courier_location_service.dart';

class SessionService {
  static Future<void> stopLocalTracking() =>
      CourierLocationService.instance.stopLocal();
  static Future<void> logout() async {
    final user = CargoAuth.instance.currentUser;
    if (user == null) return;
    final profile = await CargoStore.instance
        .collection('users')
        .doc(user.uid)
        .get(const ReadOptions(source: ReadSource.server));
    if (profile.data()?['role'] == 'kurir') {
      final tasks = await CargoStore.instance
          .collection('shipments')
          .where('courierId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'Proses')
          .limit(1)
          .get(const ReadOptions(source: ReadSource.server));
      if (tasks.docs.isNotEmpty) {
        throw StateError(
          'Masih ada pengantaran aktif. Selesaikan serah terima sebelum keluar.',
        );
      }
      await CourierLocationService.instance.stop(courierId: user.uid);
    }
    await CargoAuth.instance.signOut();
  }
}
