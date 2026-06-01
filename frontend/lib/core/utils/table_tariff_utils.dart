import '../billing/effective_tariff_quote.dart';
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
  return formatEffectiveTariffSummary(table, const []);
}

/// Boş masa kartı və kassir paneli — endirimdən sonra saatlıq qiymət.
String formatEffectiveTariffSummary(
  Map<String, dynamic> table,
  List<Map<String, dynamic>> activePromotions,
) {
  final tariffs = parseTableTariffs(table);
  if (tariffs.isEmpty) {
    final rate = jsonToDouble(table['hourly_rate']);
    final quote = quoteHourlyForTariff(
      tariffName: '',
      hourlyRate: rate,
      activePromotions: activePromotions,
    );
    return quote.hasDiscount ? quote.effectiveLabel : '${rate.toStringAsFixed(2)} ₼/saat';
  }
  if (tariffs.length == 1) {
    final t = tariffs.first;
    final quote = quoteHourlyForTariff(
      tariffName: t.name,
      hourlyRate: t.hourlyRate,
      activePromotions: activePromotions,
    );
    if (quote.hasDiscount) {
      return '${t.name}: ${quote.effectiveHourly.toStringAsFixed(2)} ₼/saat';
    }
    return '${t.hourlyRate.toStringAsFixed(2)} ₼/saat · ${t.name}';
  }
  final parts = tariffs.map((t) {
    final quote = quoteHourlyForTariff(
      tariffName: t.name,
      hourlyRate: t.hourlyRate,
      activePromotions: activePromotions,
    );
    final price = quote.hasDiscount
        ? quote.effectiveHourly.toStringAsFixed(2)
        : t.hourlyRate.toStringAsFixed(2);
    return '${t.name} $price₼';
  });
  return parts.join(' · ');
}

String? activeSessionTariffLabel(Map<String, dynamic> table) {
  final name = table['session_tariff_name'] as String?;
  if (name != null && name.isNotEmpty) return name;
  return null;
}
