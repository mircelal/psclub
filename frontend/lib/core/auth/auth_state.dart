import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../utils/json_parse.dart';

class AuthUser {
  AuthUser({
    required this.id,
    required this.username,
    required this.role,
    this.fullName,
  });

  final int id;
  final String username;
  final String role;
  final String? fullName;

  bool get isAdmin => role == 'admin';

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: jsonToInt(json['id']),
      username: json['username'] as String,
      role: json['role'] as String,
      fullName: json['full_name'] as String?,
    );
  }
}

class AuthNotifier extends StateNotifier<AsyncValue<AuthUser?>> {
  AuthNotifier(this._api) : super(const AsyncValue.loading()) {
    _init();
  }

  final ApiClient _api;

  Future<void> _init() async {
    final token = await _api.getToken();
    if (token == null) {
      state = const AsyncValue.data(null);
      return;
    }
    try {
      final res = await _api.get('/auth/me');
      state = AsyncValue.data(AuthUser.fromJson(res['data'] as Map<String, dynamic>));
    } catch (_) {
      await _api.clearToken();
      state = const AsyncValue.data(null);
    }
  }

  Future<void> login(String username, String password) async {
    state = const AsyncValue.loading();
    try {
      final res = await _api.post('/auth/login', data: {
        'username': username,
        'password': password,
      });
      final data = res['data'] as Map<String, dynamic>;
      await _api.saveToken(data['token'] as String);
      state = AsyncValue.data(AuthUser.fromJson(data['user'] as Map<String, dynamic>));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {}
    await _api.clearToken();
    state = const AsyncValue.data(null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<AuthUser?>>((ref) {
  return AuthNotifier(ref.read(apiClientProvider));
});
