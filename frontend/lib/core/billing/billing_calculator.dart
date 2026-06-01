import '../utils/json_parse.dart';

class BillingPreview {
  BillingPreview({
    required this.activeSeconds,
    required this.timeCharge,
    required this.productsTotal,
    required this.totalAmount,
    this.plannedMinutes,
    this.remainingSeconds,
  });

  final int activeSeconds;
  final double timeCharge;
  final double productsTotal;
  final double totalAmount;
  final int? plannedMinutes;
  final int? remainingSeconds;

  bool get isCountdown => plannedMinutes != null && plannedMinutes! > 0;
}

class BillingCalculator {
  static int calculateActiveSeconds({
    required DateTime openedAt,
    required List<({DateTime pausedAt, DateTime? resumedAt})> pauses,
    DateTime? now,
  }) {
    final end = now ?? DateTime.now();
    var total = end.difference(openedAt).inSeconds;
    if (total < 0) return 0;

    var paused = 0;
    for (final p in pauses) {
      final resume = p.resumedAt ?? end;
      paused += resume.difference(p.pausedAt).inSeconds.clamp(0, 999999);
    }
    return (total - paused).clamp(0, 999999);
  }

  /// Müddətli sessiya: min saat + hər uzatma intervalı (planned_minutes əsasında).
  static int billableMinutesFromPlanned({
    required int plannedMinutes,
    int minBillingMinutes = 60,
    int billingIncrementMinutes = 30,
  }) {
    final minM = minBillingMinutes < 1 ? 60 : minBillingMinutes;
    final stepM = billingIncrementMinutes < 1 ? 30 : billingIncrementMinutes;
    if (plannedMinutes <= minM) return minM;
    final over = plannedMinutes - minM;
    final blocks = over ~/ stepM;
    return minM + blocks * stepM;
  }

  /// Vaxtsız sessiya: minimum ilk müddət; sonrakı interval blokları + güzəşt.
  static int billableMinutesFromActive({
    required int activeSeconds,
    int minBillingMinutes = 60,
    int billingIncrementMinutes = 30,
    int billingGraceMinutes = 10,
  }) {
    if (activeSeconds <= 0) return 0;
    final minutes = (activeSeconds / 60).ceil();
    final minM = minBillingMinutes < 1 ? 60 : minBillingMinutes;
    final stepM = billingIncrementMinutes < 1 ? 30 : billingIncrementMinutes;
    final grace = billingGraceMinutes < 0 ? 0 : billingGraceMinutes;
    if (minutes <= minM) return minM;
    final extra = minutes - minM;
    if (extra <= grace) return minM;
    final chargeableExtra = extra - grace;
    final blocks = (chargeableExtra / stepM).ceil();
    return minM + blocks * stepM;
  }

  static int billableMinutes({
    required int activeSeconds,
    required String billingMode,
    int minBillingMinutes = 60,
    int billingIncrementMinutes = 30,
    int billingGraceMinutes = 10,
    int? plannedMinutes,
  }) {
    if (billingMode == 'min_1h_then_30' && plannedMinutes != null && plannedMinutes > 0) {
      return billableMinutesFromPlanned(
        plannedMinutes: plannedMinutes,
        minBillingMinutes: minBillingMinutes,
        billingIncrementMinutes: billingIncrementMinutes,
      );
    }
    if (activeSeconds <= 0) return 0;
    final minutes = (activeSeconds / 60).ceil();
    switch (billingMode) {
      case 'block_30':
        return ((minutes / 30).ceil()) * 30;
      case 'block_60':
        return ((minutes / 60).ceil()) * 60;
      case 'min_1h_then_30':
        return billableMinutesFromActive(
          activeSeconds: activeSeconds,
          minBillingMinutes: minBillingMinutes,
          billingIncrementMinutes: billingIncrementMinutes,
          billingGraceMinutes: billingGraceMinutes,
        );
      default:
        return minutes;
    }
  }

  static double calculateTimeCharge({
    required int activeSeconds,
    required double hourlyRate,
    required String billingMode,
    double rounding = 0.01,
    int minBillingMinutes = 60,
    int billingIncrementMinutes = 30,
    int billingGraceMinutes = 10,
    int? plannedMinutes,
  }) {
    if (billingMode == 'min_1h_then_30' && plannedMinutes != null && plannedMinutes > 0) {
      final billed = billableMinutesFromPlanned(
        plannedMinutes: plannedMinutes,
        minBillingMinutes: minBillingMinutes,
        billingIncrementMinutes: billingIncrementMinutes,
      );
      final charge = (billed / 60) * hourlyRate;
      if (rounding <= 0) return double.parse(charge.toStringAsFixed(2));
      return double.parse(((charge / rounding).round() * rounding).toStringAsFixed(2));
    }

    if (activeSeconds <= 0) return 0;

    final billedMinutes = billableMinutes(
      activeSeconds: activeSeconds,
      billingMode: billingMode,
      minBillingMinutes: minBillingMinutes,
      billingIncrementMinutes: billingIncrementMinutes,
      billingGraceMinutes: billingGraceMinutes,
      plannedMinutes: plannedMinutes,
    );
    double charge;
    switch (billingMode) {
      case 'block_30':
      case 'block_60':
      case 'min_1h_then_30':
        charge = (billedMinutes / 60) * hourlyRate;
        break;
      default:
        charge = billedMinutes * (hourlyRate / 60);
    }

    if (rounding <= 0) return double.parse(charge.toStringAsFixed(2));
    return double.parse(((charge / rounding).round() * rounding).toStringAsFixed(2));
  }

  static BillingPreview fromSessionData({
    required Map<String, dynamic> table,
    required String billingMode,
    DateTime? now,
  }) {
    final bill = table['bill_preview'] as Map<String, dynamic>?;
    if (bill != null) {
      return BillingPreview(
        activeSeconds: jsonToInt(bill['active_seconds']),
        timeCharge: jsonToDouble(bill['time_charge']),
        productsTotal: jsonToDouble(bill['products_total']),
        totalAmount: jsonToDouble(bill['total_amount']),
        plannedMinutes: jsonToIntOrNull(bill['planned_minutes']),
        remainingSeconds: jsonToIntOrNull(bill['remaining_seconds']),
      );
    }

    final openedAt = DateTime.tryParse(table['opened_at']?.toString() ?? '') ?? now ?? DateTime.now();
    final activeSeconds = calculateActiveSeconds(openedAt: openedAt, pauses: [], now: now);
    final rate = double.tryParse(table['session_hourly_rate']?.toString() ?? table['hourly_rate']?.toString() ?? '') ?? 0;
    final timeCharge = calculateTimeCharge(
      activeSeconds: activeSeconds,
      hourlyRate: rate,
      billingMode: billingMode,
    );
    final planned = jsonToIntOrNull(table['planned_minutes']);
    final remaining = planned != null && planned > 0
        ? (planned * 60 - activeSeconds).clamp(0, planned * 60)
        : null;

    return BillingPreview(
      activeSeconds: activeSeconds,
      timeCharge: timeCharge,
      productsTotal: 0,
      totalAmount: timeCharge,
      plannedMinutes: planned,
      remainingSeconds: remaining,
    );
  }
}
