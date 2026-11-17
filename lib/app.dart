import 'services/backend_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/ui.dart';
import 'screens/preview_page.dart';
import 'screens/login_page.dart';
import 'screens/admin_home.dart';
import 'screens/kurir_home.dart';
import 'services/session_service.dart';

final cargoNavigatorKey = GlobalKey<NavigatorState>();

void resetProtectedRoutes() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    cargoNavigatorKey.currentState?.popUntil((route) => route.isFirst);
  });
}

class CargoApp extends StatelessWidget {
  const CargoApp({super.key, this.preview = false});
  final bool preview;
  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: cargoNavigatorKey,
    title: 'Haryata Cargo',
    debugShowCheckedModeBanner: false,
    locale: const Locale('id', 'ID'),
    supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: cargoTheme(),
    home: preview ? const PreviewPage() : const AuthGate(),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<CargoUser?>(
    stream: CargoAuth.instance.authStateChanges(),
    builder: (context, auth) {
      if (auth.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (auth.data == null) {
        resetProtectedRoutes();
        SessionService.stopLocalTracking();
        return const LoginPage();
      }
      return StreamBuilder<RecordSnapshot<Map<String, dynamic>>>(
        stream: CargoStore.instance
            .collection('users')
            .doc(auth.data!.uid)
            .snapshots(),
        builder: (context, profile) {
          if (profile.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final data = profile.data?.data();
          final role = data?['role'];
          if (profile.hasError ||
              data == null ||
              data['active'] != true ||
              (role != 'admin' && role != 'kurir')) {
            resetProtectedRoutes();
            SessionService.stopLocalTracking();
            return Scaffold(
              body: EmptyState(
                'Akun belum dapat digunakan',
                profile.hasError
                    ? errorText(profile.error!)
                    : 'Akun belum memiliki akses aktif. Hubungi administrator Haryata Cargo.',
                icon: Icons.lock_person_outlined,
                action: FilledButton(
                  onPressed: () => CargoAuth.instance.signOut(),
                  child: const Text('Kembali ke login'),
                ),
              ),
            );
          }
          return role == 'admin' ? const AdminHome() : const KurirHome();
        },
      );
    },
  );
}
