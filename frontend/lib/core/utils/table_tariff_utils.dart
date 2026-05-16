import 'json_parse.dart';

class TableTariff {
  const TableTariff({required this.id, required this.name, required this.hourlyRate});

  final int id;
  final String name;
  final double hourlyRate;

  factory TableTariff.fromJson(Map<String, dynamic> json) => TableTariff(
        id: jsonToInt(json['id']),
        name: json['name'] as String? ?? '',
        hourlyRate: jsonToDouble(json['hourly_rate']),
      );
}

List<TableTariff> parseTableTariffs(Map<String, dynamic> table) {
  final raw = table['tariffs'];
  if (raw is! List) return [];
  return raw.whereType<Map>().map((e) => TableTariff.fromJson(e.cast<String, dynamic>())).toList();
}

String formatTableTariffSummary(Map<String, dynamic> table) {
  final tariffs = parseTableTariffs(table);
  if (tariffs.isEmpty) {
    return '${jsonToDouble(table['hourly_rate']).toStringAsFixed(2)} ₼/saat';
  }
  if (tariffs.length == 1) {
    final t = tariffs.first;
    return '${t.hourlyRate.toStringAsFixed(2)} ₼/saat · ${t.name}';
  }
  final rates = tariffs.map((t) => t.hourlyRate).toList()..sort();
  return '${rates.first.toStringAsFixed(0)}–${rates.last.toStringAsFixed(0)} ₼/saat · ${tariffs.length} tarif';
}

String? activeSessionTariffLabel(Map<String, dynamic> table) {
  final name = table['session_tariff_name'] as String?;
  if (name != null && name.isNotEmpty) return name;
  return null;
}
