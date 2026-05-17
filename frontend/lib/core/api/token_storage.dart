import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Web: SharedPreferences (secure_storage bəzən xəta verir).
/// Desktop/mobile: FlutterSecureStorage.
class TokenStorage {
  const TokenStorage([this._secure]);

  static const _key = 'jwt_token';
  final FlutterSecureStorage? _secure;

  factory TokenStorage.platform() {
    return TokenStorage(kIsWeb ? null : const FlutterSecureStorage());
  }

  Future<void> write(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, token);
      return;
    }
    await (_secure ?? const FlutterSecureStorage()).write(key: _key, value: token);
  }

  Future<String?> read() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_key);
    }
    return (_secure ?? const FlutterSecureStorage()).read(key: _key);
  }

  Future<void> delete() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      return;
    }
    await (_secure ?? const FlutterSecureStorage()).delete(key: _key);
  }
}
