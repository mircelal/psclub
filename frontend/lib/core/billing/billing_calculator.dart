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

  static double calculateTimeCharge({
    required int activeSeconds,
    required double hourlyRate,
    required String billingMode,
    double rounding = 0.01,
  }) {
    if (activeSeconds <= 0) return 0;

    double charge;
    switch (billingMode) {
      case 'block_30':
        final minutes = (activeSeconds / 60).ceil();
        final blocks = (minutes / 30).ceil();
        charge = blocks * (hourlyRate / 2);
        break;
      case 'block_60':
        final minutes = (activeSeconds / 60).ceil();
        final blocks = (minutes / 60).ceil();
        charge = blocks * hourlyRate;
        break;
      default:
        final minutes = (activeSeconds / 60).ceil();
        charge = minutes * (hourlyRate / 60);
    }

    if (rounding <= 0) return double.parse(charge.toStringAsFixed(2));
    return (charge / rounding).round() * rounding;
  }

  static BillingPreview fromSessionData({
    required Map<String, dynamic> table,
    required String billingMode,
    DateTime? now,
  }) {
    final bill = table['bill_preview'] as Map<String, dynamic>?;
    if (bill != null) {
      return BillingPreview(
        activeSeconds: (bill['active_seconds'] as num?)?.toInt() ?? 0,
        timeCharge: (bill['time_charge'] as num?)?.toDouble() ?? 0,
        productsTotal: (bill['products_total'] as num?)?.toDouble() ?? 0,
        totalAmount: (bill['total_amount'] as num?)?.toDouble() ?? 0,
        plannedMinutes: (bill['planned_minutes'] as num?)?.toInt(),
        remainingSeconds: (bill['remaining_seconds'] as num?)?.toInt(),
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
    final planned = (table['planned_minutes'] as num?)?.toInt();
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
