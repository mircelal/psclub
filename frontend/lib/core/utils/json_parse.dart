/// MariaDB/PDO JSON cavablarında rəqəmlər tez-tez String gəlir.
double jsonToDouble(dynamic value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int? jsonToIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  if (value is String) {
    final asInt = int.tryParse(value);
    if (asInt != null) return asInt;
    final asDouble = double.tryParse(value);
    if (asDouble != null) return asDouble.toInt();
    return null;
  }
  return null;
}

int jsonToInt(dynamic value, [int fallback = 0]) => jsonToIntOrNull(value) ?? fallback;

/// MySQL boolean: 1, "1", true → aktiv; 0, "0", false, null → deaktiv.
bool jsonIsActive(dynamic value, {bool defaultActive = true}) {
  if (value == null) return defaultActive;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == '1' || v == 'true') return true;
    if (v == '0' || v == 'false') return false;
  }
  return defaultActive;
}
