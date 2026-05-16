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
  if (value is String) return int.tryParse(value);
  return null;
}

int jsonToInt(dynamic value, [int fallback = 0]) => jsonToIntOrNull(value) ?? fallback;
