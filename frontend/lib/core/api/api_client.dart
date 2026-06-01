import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import 'token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((_) => TokenStorage.platform());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.read(tokenStorageProvider));
});

class ApiClient {
  ApiClient(this._storage) {
    _initDio();
  }

  /// 401-dən sonra token silinəndə auth state sıfırlansın.
  void Function()? onUnauthorized;

  void _initDio() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final path = error.requestOptions.path;
          final isPublic = path.contains('/public/') || path.contains('/auth/login');
          if (!isPublic) {
            await _storage.delete();
            onUnauthorized?.call();
          }
        }
        handler.next(error);
      },
    ));
  }

  final TokenStorage _storage;
  late final Dio _dio;

  Dio get dio => _dio;

  Future<void> saveToken(String token) => _storage.write(token);
  Future<void> clearToken() => _storage.delete();
  Future<String?> getToken() => _storage.read();

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    final res = await _dio.get(path, queryParameters: query);
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? data}) async {
    final res = await _dio.post(path, data: data);
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? data}) async {
    final res = await _dio.put(path, data: data);
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? data}) async {
    final res = await _dio.patch(path, data: data);
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> delete(String path, {Map<String, dynamic>? data}) async {
    final res = await _dio.delete(path, data: data);
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> postMultipart(String path, FormData data) async {
    // contentType verməyin — Dio boundary ilə özü təyin edir.
    final res = await _dio.post(path, data: data);
    return _unwrap(res);
  }

  Map<String, dynamic> _unwrap(Response res) {
    final body = res.data;
    if (body is! Map<String, dynamic>) {
      throw DioException(requestOptions: res.requestOptions, message: 'Invalid response');
    }
    if (body['success'] != true) {
      throw DioException(
        requestOptions: res.requestOptions,
        message: body['message']?.toString() ?? 'Request failed',
      );
    }
    return body;
  }

  static String messageFromError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401) {
        return 'Sessiya bitib və ya giriş yoxdur — yenidən daxil olun';
      }
      if (status == 403) {
        return 'Bu əməliyyat üçün admin hüququ lazımdır';
      }
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
      return error.message ?? error.toString();
    }
    return error.toString();
  }
}
