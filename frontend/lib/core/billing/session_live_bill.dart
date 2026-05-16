import 'billing_calculator.dart';
import '../utils/json_parse.dart';

class SessionBillSnapshot {
  const SessionBillSnapshot({
    required this.activeSeconds,
    required this.activeMinutes,
    required this.timeCharge,
    required this.productsTotal,
    required this.discount,
    required this.subtotal,
    required this.totalAmount,
    required this.plannedMinutes,
    required this.remainingSeconds,
    required this.isCountdown,
    this.discountType,
    this.discountValue,
    this.couponCode,
  });

  final int activeSeconds;
  final int activeMinutes;
  final double timeCharge;
  final double productsTotal;
  final double discount;
  final double subtotal;
  final double totalAmount;
  final String? discountType;
  final double? discountValue;
  final String? couponCode;
  final int? plannedMinutes;
  final int? remainingSeconds;
  final bool isCountdown;

  Map<String, dynamic> toMap() => {
        'active_seconds': activeSeconds,
        'active_minutes': activeMinutes,
        'time_charge': timeCharge,
        'products_total': productsTotal,
        'discount': discount,
        'subtotal': subtotal,
        'total_amount': totalAmount,
        'planned_minutes': plannedMinutes,
        'remaining_seconds': remainingSeconds,
        'is_countdown': isCountdown,
      };
}

SessionBillSnapshot computeSessionLiveBill(
  Map<String, dynamic> session, {
  required String billingMode,
  required bool timeBillingEnabled,
  DateTime? now,
}) {
  final end = now ?? DateTime.now();
  final opened = DateTime.tryParse(session['opened_at']?.toString() ?? '');
  final pauses = session['pauses'] as List<dynamic>? ?? [];
  final items = session['items'] as List<dynamic>? ?? [];

  var activeSeconds = 0;
  if (opened != null) {
    activeSeconds = _activeSeconds(opened, end, pauses, session['status'] == 'paused');
  }

  final plannedMinutes = jsonToIntOrNull(session['planned_minutes']);
  if (plannedMinutes != null && plannedMinutes > 0) {
    activeSeconds = activeSeconds.clamp(0, plannedMinutes * 60);
  }

  final isCounter = (session['session_type'] ?? 'table') == 'counter';
  final setPrice = jsonToDouble(session['set_price_snapshot']);
  final double timeCharge;
  if (isCounter) {
    timeCharge = 0.0;
  } else if (setPrice > 0) {
    timeCharge = setPrice;
  } else {
    final rate = jsonToDouble(session['hourly_rate_snapshot']);
    timeCharge = timeBillingEnabled
        ? BillingCalculator.calculateTimeCharge(
            activeSeconds: activeSeconds,
            hourlyRate: rate,
            billingMode: billingMode,
          )
        : 0.0;
  }

  var productsTotal = 0.0;
  for (final raw in items) {
    final i = raw as Map<String, dynamic>;
    if (setPrice > 0 && (i['is_set_item'] == true || i['is_set_item'] == 1)) {
      continue;
    }
    productsTotal += jsonToDouble(i['unit_price']) * jsonToInt(i['quantity'], 1);
  }
  productsTotal = double.parse(productsTotal.toStringAsFixed(2));

  final subtotal = double.parse((timeCharge + productsTotal).toStringAsFixed(2));
  final discountType = session['discount_type'] as String? ?? 'none';
  final discountValue = jsonToDouble(session['discount_value']);
  final discount = _computeDiscount(subtotal, discountType, discountValue, jsonToDouble(session['discount']));
  final total = double.parse((subtotal - discount).toStringAsFixed(2));
  final couponCode = session['coupon_code'] as String?;

  final remaining = plannedMinutes != null && plannedMinutes > 0
      ? (plannedMinutes * 60 - activeSeconds).clamp(0, plannedMinutes * 60)
      : null;

  return SessionBillSnapshot(
    activeSeconds: activeSeconds,
    activeMinutes: (activeSeconds / 60).ceil(),
    timeCharge: timeCharge,
    productsTotal: productsTotal,
    discount: discount,
    subtotal: subtotal,
    totalAmount: total,
    plannedMinutes: plannedMinutes,
    remainingSeconds: remaining,
    isCountdown: plannedMinutes != null && plannedMinutes > 0,
    discountType: discountType != 'none' ? discountType : null,
    discountValue: discountType != 'none' ? discountValue : null,
    couponCode: couponCode,
  );
}

double _computeDiscount(double subtotal, String type, double value, double stored) {
  if (subtotal <= 0 || type == 'none') return stored;
  if (type == 'fixed') return (value > subtotal ? subtotal : value).clamp(0, subtotal);
  if (type == 'percent') return (subtotal * value / 100).clamp(0, subtotal);
  return stored;
}

int _activeSeconds(DateTime opened, DateTime end, List<dynamic> pauses, bool isPaused) {
  var total = end.difference(opened).inSeconds;
  if (total < 0) return 0;

  var paused = 0;
  for (final raw in pauses) {
    final p = raw as Map<String, dynamic>;
    final pausedAt = DateTime.tryParse(p['paused_at']?.toString() ?? '');
    if (pausedAt == null) continue;
    final resumedAt = DateTime.tryParse(p['resumed_at']?.toString() ?? '') ?? (isPaused ? end : end);
    paused += resumedAt.difference(pausedAt).inSeconds.clamp(0, 999999);
  }

  return (total - paused).clamp(0, 999999);
}
