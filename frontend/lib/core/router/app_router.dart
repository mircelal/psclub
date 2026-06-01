import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/admin/admin_shell.dart';
import '../../features/auth/login_screen.dart';
import '../../features/cashier/cashier_home.dart';
import '../auth/auth_state.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // authProvider-ı watch etməyin — hər dəyişiklikdə GoRouter yenidən yaranır və UI donur.
  final refresh = _AuthRefresh(ref);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;
      final user = auth.valueOrNull;
      final loggingIn = loc == '/login';

      if (auth.isLoading) return null;
      if (user == null) return loggingIn ? null : '/login';
      if (loggingIn) return user.isAdmin ? '/admin' : '/cashier';
      if (loc.startsWith('/admin') && !user.isAdmin) return '/cashier';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/cashier', builder: (context, state) => const CashierHome()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminShell()),
    ],
  );
});

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this.ref) {
    Timer? debounce;
    ref.listen(authProvider, (previous, next) {
      if (next.isLoading) return;
      final prevId = previous?.valueOrNull?.id;
      final nextId = next.valueOrNull?.id;
      if (previous?.isLoading != true && prevId == nextId) return;
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 80), notifyListeners);
    });
  }
  final Ref ref;
}
