/// Sessiya vaxtları — server (Asia/Baku) ilə eyni məntiq; cihaz saatından asılı deyil.
library;

/// Azərbaycan biznes vaxtı (DST yoxdur).
const Duration businessUtcOffset = Duration(hours: 4);

/// API-dən gələn vaxtı parse edir (naive MySQL və ya ISO8601).
DateTime? parseSessionDateTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final s = raw.trim();

  if (s.endsWith('Z')) {
    return DateTime.parse(s);
  }
  if (RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s)) {
    return DateTime.parse(s);
  }

  final normalized = s.contains('T') ? s : s.replaceFirst(' ', 'T');
  final parts = RegExp(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})').firstMatch(normalized);
  if (parts == null) {
    return DateTime.tryParse(s);
  }

  final y = int.parse(parts[1]!);
  final mo = int.parse(parts[2]!);
  final d = int.parse(parts[3]!);
  final h = int.parse(parts[4]!);
  final mi = int.parse(parts[5]!);
  final se = int.parse(parts[6]!);

  // Naive DB vaxtı = Baku divar saatı → UTC an
  return DateTime.utc(y, mo, d, h, mi, se).subtract(businessUtcOffset);
}

/// Server vaxtına görə «indi» — telefon/komputer saat fərqi timerə təsir etmir.
class SessionClock {
  SessionClock._();

  static DateTime? _serverUtc;
  static DateTime? _clientWhenSynced;

  static void sync(String? serverNowIso) {
    final parsed = parseSessionDateTime(serverNowIso);
    if (parsed == null) return;
    _serverUtc = parsed.toUtc();
    _clientWhenSynced = DateTime.now();
  }

  static void reset() {
    _serverUtc = null;
    _clientWhenSynced = null;
  }

  static DateTime nowUtc() {
    if (_serverUtc == null || _clientWhenSynced == null) {
      return DateTime.now().toUtc();
    }
    final drift = DateTime.now().difference(_clientWhenSynced!);
    return _serverUtc!.add(drift);
  }
}
