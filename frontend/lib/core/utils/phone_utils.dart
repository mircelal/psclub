/// Azərbaycan mobil: +994XXXXXXXXX
class PhoneUtils {
  static String? normalize(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('994')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length != 9) return null;
    return '+994$digits';
  }

  static bool isValid(String? input) => normalize(input) != null;

  static String displayHint() => '+994555555555';

  /// Input mask helper: keeps +994 prefix visible
  static String formatForDisplay(String? normalized) {
    if (normalized == null || normalized.isEmpty) return '';
    return normalized;
  }
}
