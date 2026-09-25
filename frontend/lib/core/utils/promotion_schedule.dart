import 'package:intl/intl.dart';

enum PromotionDurationMode { unlimited, singleDay, range }

/// Kampaniya tarixi və saat pəncərəsi — API `yyyy-MM-dd` / `HH:mm`.
class PromotionSchedule {
  PromotionSchedule._();

  static final DateFormat apiDay = DateFormat('yyyy-MM-dd');
  static final DateFormat displayDay = DateFormat('dd.MM.yyyy');
  static final RegExp _hm = RegExp(r'^(\d{1,2}):(\d{2})$');

  static DateTime? parseApiDate(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static bool isSameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static PromotionDurationMode modeOf(DateTime? from, DateTime? until) {
    if (from == null && until == null) return PromotionDurationMode.unlimited;
    if (from != null && until != null && isSameCalendarDay(from, until)) {
      return PromotionDurationMode.singleDay;
    }
    return PromotionDurationMode.range;
  }

  static String? toApiDate(DateTime? d) => d == null ? null : apiDay.format(d);

  static String formatDay(DateTime d) => displayDay.format(d);

  static String? rangeLabel(DateTime? from, DateTime? until) {
    if (from == null && until == null) return null;
    if (from != null && until != null && isSameCalendarDay(from, until)) {
      return formatDay(from);
    }
    if (from != null && until != null) {
      return '${formatDay(from)} – ${formatDay(until)}';
    }
    if (from != null) return '${formatDay(from)}-dən';
    return '${formatDay(until!)}-dək';
  }

  static int? parseMinutes(String s) {
    final m = _hm.firstMatch(s.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return h * 60 + min;
  }

  static bool isValidHm(String s) => parseMinutes(s) != null;

  static String? normalizeHm(String s) {
    final m = parseMinutes(s);
    if (m == null) return null;
    return formatHm(m ~/ 60, m % 60);
  }

  static String formatHm(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
