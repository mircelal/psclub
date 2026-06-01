import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import 'auth_state.dart';

/// ApiClient 401 → auth sıfırlama (bir dəfə quraşdırılır, watch yoxdur).
final authSessionBridgeProvider = Provider<void>((ref) {
  final api = ref.read(apiClientProvider);
  api.onUnauthorized = () {
    Future.microtask(() => ref.read(authProvider.notifier).handleUnauthorized());
  };
  ref.onDispose(() => api.onUnauthorized = null);
  return;
});
