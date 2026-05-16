import 'api_config.dart';

/// Serverdən gələn media URL-lərini cari [ApiConfig.baseUrl] ilə uyğunlaşdırır.
/// DB-də `http://psclub.test/...` olsa belə, tətbiq `127.0.0.1:8080` istifadə edirsə şəkil yüklənir.
abstract final class MediaUrl {
  static String? resolve(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final trimmed = raw.trim();

    if (trimmed.startsWith('/')) {
      return _withApiOrigin(trimmed);
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;

    if (uri.path.contains('/api/media/')) {
      final path = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
      return _withApiOrigin(path);
    }

    return trimmed;
  }

  static String _withApiOrigin(String pathAndQuery) {
    final api = Uri.parse(ApiConfig.baseUrl);
    final pathUri = Uri.parse('http://local$pathAndQuery');

    return Uri(
      scheme: api.scheme,
      host: api.host,
      port: api.hasPort ? api.port : null,
      path: pathUri.path,
      query: pathUri.hasQuery ? pathUri.query : null,
    ).toString();
  }
}
