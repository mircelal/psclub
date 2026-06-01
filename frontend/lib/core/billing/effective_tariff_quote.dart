import '../utils/json_parse.dart';

/// Saatlıq tarif + aktiv endirim → kassirin bir baxışda deyə biləcəyi qiymət.
class EffectiveHourlyQuote {
  const EffectiveHourlyQuote({
    required this.baseHourly,
    required this.effectiveHourly,
    this.discountLabel,
  });

  final double baseHourly;
  final double effectiveHourly;
  final String? discountLabel;

  bool get hasDiscount => (baseHourly - effectiveHourly) > 0.004;

  String get effectiveLabel => '${effectiveHourly.toStringAsFixed(2)} ₼ / saat';

  String? get savingsLabel {
    if (!hasDiscount) return null;
    return '${baseHourly.toStringAsFixed(2)} ₼ tarif';
  }
}

double discountAmountOnBase(
  double base, {
  required String discountType,
  required double discountValue,
  String appliesTo = 'time_only',
  double productsTotal = 0,
}) {
  if (base <= 0 || discountType == 'none') return 0;
  final chargeBase = appliesTo == 'all' ? base + productsTotal : base;
  if (chargeBase <= 0) return 0;
  if (discountType == 'fixed') {
    return discountValue > chargeBase ? chargeBase : discountValue;
  }
  if (discountType == 'percent') {
    return (chargeBase * discountValue / 100).clamp(0, chargeBase);
  }
  return 0;
}

List<Map<String, dynamic>> promotionsForTariff(
  List<Map<String, dynamic>> promotions,
  String tariffName,
) {
  final out = <Map<String, dynamic>>[];
  final key = tariffName.trim().toLowerCase();
  for (final p in promotions) {
    final scope = p['scope'] as String? ?? 'all_tables';
    if (scope == 'all_tables') {
      out.add(p);
      continue;
    }
    if (scope != 'tariffs' || key.isEmpty) continue;
    final names = (p['tariff_names'] as List<dynamic>? ?? [])
        .map((e) => e.toString().trim().toLowerCase())
        .where((e) => e.isNotEmpty);
    if (names.any((n) => n == key)) {
      out.add(p);
    }
  }
  return out;
}

EffectiveHourlyQuote quoteHourlyForTariff({
  required String tariffName,
  required double hourlyRate,
  required List<Map<String, dynamic>> activePromotions,
  Map<String, dynamic>? customer,
}) {
  var bestDiscount = 0.0;
  String? bestLabel;

  for (final p in promotionsForTariff(activePromotions, tariffName)) {
    final amount = discountAmountOnBase(
      hourlyRate,
      discountType: p['discount_type'] as String? ?? 'percent',
      discountValue: jsonToDouble(p['discount_value']),
      appliesTo: 'time_only',
    );
    if (amount > bestDiscount) {
      bestDiscount = amount;
      bestLabel = p['name'] as String?;
    }
  }

  final groupName = customer?['customer_group_name'] as String?;
  if (groupName != null && groupName.isNotEmpty) {
    final groupAmount = discountAmountOnBase(
      hourlyRate,
      discountType: customer!['customer_group_discount_type'] as String? ?? 'percent',
      discountValue: jsonToDouble(customer['customer_group_discount_value']),
      appliesTo: customer['customer_group_applies_to'] as String? ?? 'time_only',
    );
    if (groupAmount >= bestDiscount) {
      bestDiscount = groupAmount;
      bestLabel = groupName;
    }
  }

  final effective = double.parse((hourlyRate - bestDiscount).clamp(0, hourlyRate).toStringAsFixed(2));
  return EffectiveHourlyQuote(
    baseHourly: hourlyRate,
    effectiveHourly: effective,
    discountLabel: bestDiscount > 0 ? bestLabel : null,
  );
}
