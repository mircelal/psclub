import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

const _tokenKey = 'jwt_token';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.read(secureStorageProvider));
});

class ApiClient {
  ApiClient(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _tokenKey);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  final FlutterSecureStorage _storage;
  late final Dio _dio;

  Dio get dio => _dio;

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<void> clearToken() => _storage.delete(key: _tokenKey);
  Future<String?> getToken() => _storage.read(key: _tokenKey);

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

  Future<Map<String, dynamic>> delete(String path) async {
    final res = await _dio.delete(path);
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> postMultipart(String path, FormData data) async {
    final res = await _dio.post(
      path,
      data: data,
      options: Options(contentType: 'multipart/form-data'),
    );
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
}
