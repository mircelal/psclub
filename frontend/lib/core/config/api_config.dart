class ApiConfig {
  /// Laragon: http://psclub.test/api | Lokal PHP server: http://127.0.0.1:8080/api
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://127.0.0.1:8080/api',
  );
}
