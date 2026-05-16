import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/admin/admin_shell.dart';
import '../../features/auth/login_screen.dart';
import '../../features/cashier/cashier_home.dart';
import '../auth/auth_state.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final user = auth.valueOrNull;
      final loggingIn = loc == '/login';

      if (auth.isLoading) return null;
      if (user == null) return loggingIn ? null : '/login';
      if (loggingIn) return user.isAdmin ? '/admin' : '/cashier';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/cashier', builder: (_, __) => const CashierHome()),
      GoRoute(path: '/admin', builder: (_, __) => const AdminShell()),
    ],
  );
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this.ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
  final Ref ref;
}
