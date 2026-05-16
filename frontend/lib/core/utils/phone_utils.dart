/// Azərbaycan mobil: +994XXXXXXXXX (9 rəqəm).
class PhoneUtils {
  PhoneUtils._();

  static const prefix = '+994';
  static const nationalDigitCount = 9;
  static const fullLength = prefix.length + nationalDigitCount; // 13

  static String? normalize(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    if (RegExp(r'[a-zA-Z]').hasMatch(input)) return null;

    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('994')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length != nationalDigitCount) return null;
    return '$prefix$digits';
  }

  static bool isValid(String? input) => normalize(input) != null;

  static bool isComplete(String? input) {
    final n = normalize(input);
    return n != null && n.length == fullLength;
  }

  static String displayHint() => '+994707232128';

  static String fieldValue({String? stored}) {
    final n = normalize(stored);
    return n ?? prefix;
  }

  static String validationMessage(String? input) {
    if (input == null || input.trim().isEmpty || input == prefix) {
      return 'Telefon nömrəsini daxil edin';
    }
    final digits = input.replaceAll(RegExp(r'\D'), '');
    final national = digits.startsWith('994')
        ? digits.substring(3)
        : (digits.startsWith('0') ? digits.substring(1) : digits);
    if (national.length < nationalDigitCount) {
      return 'Əksik rəqəm: ${nationalDigitCount - national.length} rəqəm qalıb';
    }
    if (RegExp(r'[a-zA-Z]').hasMatch(input)) {
      return 'Telefonda hərf ola bilməz';
    }
    return 'Düzgün format: ${displayHint()}';
  }
}
