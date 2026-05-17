import '../../../core/billing/billing_calculator.dart';
import '../../../core/utils/json_parse.dart';

class SessionItemLine {
  const SessionItemLine({required this.name, required this.quantity});

  final String name;
  final int quantity;
}

class TableLiveSnapshot {
  const TableLiveSnapshot({
    required this.bill,
    required this.items,
    required this.isExpired,
    required this.isUrgent,
  });

  final BillingPreview bill;
  final List<SessionItemLine> items;
  final bool isExpired;
  final bool isUrgent;
}

/// Kassir panelindəki «canlı gəlir» — masa kartı ilə eyni məntiq (vaxt bitəndə artmır).
double tableLiveBillTotal(
  Map<String, dynamic> table, {
  String billingMode = 'per_minute',
  bool timeBillingEnabled = true,
}) {
  final snap = computeTableLive(
    table,
    billingMode: billingMode,
    timeBillingEnabled: timeBillingEnabled,
  );
  if (snap != null) return snap.bill.totalAmount;

  final preview = table['bill_preview'] as Map<String, dynamic>?;
  if (preview == null) return 0;
  return jsonToDouble(preview['total_amount']);
}

TableLiveSnapshot? computeTableLive(
  Map<String, dynamic> table, {
  String billingMode = 'per_minute',
  bool timeBillingEnabled = true,
}) {
  if (table['session_id'] == null) return null;

  final status = table['status'] as String? ?? 'empty';
  final isPaused = status == 'paused' || table['session_status'] == 'paused';
  final billMap = table['bill_preview'] as Map<String, dynamic>?;
  final items = _parseItems(table, billMap);

  final base = billMap != null
      ? BillingPreview(
          activeSeconds: jsonToInt(billMap['active_seconds']),
          timeCharge: jsonToDouble(billMap['time_charge']),
          productsTotal: jsonToDouble(billMap['products_total']),
          totalAmount: jsonToDouble(billMap['total_amount']),
          plannedMinutes: jsonToIntOrNull(billMap['planned_minutes']),
          remainingSeconds: jsonToIntOrNull(billMap['remaining_seconds']),
        )
      : BillingCalculator.fromSessionData(table: table, billingMode: 'per_minute');

  if (isPaused) {
    final expired = base.isCountdown && (base.remainingSeconds ?? 1) <= 0;
    return TableLiveSnapshot(
      bill: base,
      items: items,
      isExpired: expired,
      isUrgent: !expired && base.isCountdown && (base.remainingSeconds ?? 999) <= 300,
    );
  }

  final opened = DateTime.tryParse(table['opened_at']?.toString() ?? '');
  if (opened == null) {
    return TableLiveSnapshot(bill: base, items: items, isExpired: false, isUrgent: false);
  }

  final now = DateTime.now();
  final int? plannedSecs =
      base.plannedMinutes != null && base.plannedMinutes! > 0 ? base.plannedMinutes! * 60 : null;

  int activeSeconds;
  int? remaining;
  if (plannedSecs != null) {
    final endAt = opened.add(Duration(seconds: plannedSecs));
    remaining = endAt.difference(now).inSeconds.clamp(0, plannedSecs);
    activeSeconds = plannedSecs - remaining;
  } else {
    activeSeconds = now.difference(opened).inSeconds;
  }

  final rate = jsonToDouble(table['session_hourly_rate'] ?? table['hourly_rate']);
  final timeCharge = timeBillingEnabled
      ? BillingCalculator.calculateTimeCharge(
          activeSeconds: activeSeconds,
          hourlyRate: rate,
          billingMode: billingMode,
        )
      : 0.0;
  final products = base.productsTotal;

  final bill = BillingPreview(
    activeSeconds: activeSeconds,
    timeCharge: timeCharge,
    productsTotal: products,
    totalAmount: timeCharge + products,
    plannedMinutes: base.plannedMinutes,
    remainingSeconds: remaining,
  );

  final expired = bill.isCountdown && (bill.remainingSeconds ?? 1) <= 0;
  final urgent = !expired && bill.isCountdown && (bill.remainingSeconds ?? 999) <= 300;

  return TableLiveSnapshot(bill: bill, items: items, isExpired: expired, isUrgent: urgent);
}

List<SessionItemLine> _parseItems(Map<String, dynamic> table, Map<String, dynamic>? billMap) {
  final raw = (table['session_items'] as List<dynamic>?) ?? (billMap?['items'] as List<dynamic>?) ?? [];
  return raw.map((e) {
    final m = e as Map<String, dynamic>;
    return SessionItemLine(
      name: m['product_name'] as String? ?? '—',
      quantity: jsonToInt(m['quantity'], 1),
    );
  }).toList();
}
