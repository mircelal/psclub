import '../../../core/billing/billing_calculator.dart';

import '../../../core/billing/live_session_seconds.dart';

import '../../../core/billing/session_live_bill.dart';

import '../../../core/utils/json_parse.dart';

import '../../../core/utils/package_session.dart';



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

    this.isPackage = false,

    this.discount = 0,

    this.promotionName,

  });



  final BillingPreview bill;

  final List<SessionItemLine> items;

  final bool isExpired;

  final bool isUrgent;

  final bool isPackage;

  final double discount;

  final String? promotionName;

}



/// Kassir panelindəki «canlı gəlir» — masa kartı ilə eyni məntiq (vaxt bitəndə artmır).

double tableLiveBillTotal(

  Map<String, dynamic> table, {

  String billingMode = 'per_minute',

  bool timeBillingEnabled = true,

  int minBillingMinutes = 60,

  int billingIncrementMinutes = 30,

  int billingGraceMinutes = 10,

}) {

  final snap = computeTableLive(

    table,

    billingMode: billingMode,

    timeBillingEnabled: timeBillingEnabled,

    minBillingMinutes: minBillingMinutes,

    billingIncrementMinutes: billingIncrementMinutes,

    billingGraceMinutes: billingGraceMinutes,

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

  int minBillingMinutes = 60,

  int billingIncrementMinutes = 30,

  int billingGraceMinutes = 10,

}) {

  if (table['session_id'] == null) return null;



  final packagePrice = tablePackagePrice(table);

  final isPackage = packagePrice > 0;



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



  if (isPackage) {

    final liveSecs = isPaused

        ? null

        : liveSessionSeconds(

            billPreview: billMap,

            plannedMinutes: base.plannedMinutes,

            openedAtRaw: table['opened_at']?.toString(),

            isPaused: false,

          );

    final activeSeconds = isPaused ? base.activeSeconds : (liveSecs?.activeSeconds ?? base.activeSeconds);

    final remaining = isPaused ? base.remainingSeconds : liveSecs?.remainingSeconds;



    final bill = BillingPreview(

      activeSeconds: activeSeconds,

      timeCharge: packagePrice,

      productsTotal: base.productsTotal,

      totalAmount: packagePrice + base.productsTotal,

      plannedMinutes: base.plannedMinutes,

      remainingSeconds: remaining,

    );



    return _withDiscount(

      table,

      TableLiveSnapshot(

        bill: bill,

        items: items,

        isExpired: false,

        isUrgent: remaining != null && remaining > 0 && remaining <= 300,

        isPackage: true,

      ),

    );

  }



  if (isPaused) {

    final rate = jsonToDouble(table['session_hourly_rate'] ?? table['hourly_rate']);

    final pausedCharge = timeBillingEnabled

        ? BillingCalculator.calculateTimeCharge(

            activeSeconds: base.activeSeconds,

            hourlyRate: rate,

            billingMode: billingMode,

            minBillingMinutes: minBillingMinutes,

            billingIncrementMinutes: billingIncrementMinutes,

            plannedMinutes: base.plannedMinutes,

          )

        : 0.0;

    final pausedBill = BillingPreview(

      activeSeconds: base.activeSeconds,

      timeCharge: pausedCharge,

      productsTotal: base.productsTotal,

      totalAmount: pausedCharge + base.productsTotal,

      plannedMinutes: base.plannedMinutes,

      remainingSeconds: base.remainingSeconds,

    );

    final expired = pausedBill.isCountdown && (pausedBill.remainingSeconds ?? 1) <= 0;

    return _withDiscount(

      table,

      TableLiveSnapshot(

        bill: pausedBill,

        items: items,

        isExpired: expired,

        isUrgent: !expired && pausedBill.isCountdown && (pausedBill.remainingSeconds ?? 999) <= 300,

      ),

    );

  }



  final liveSecs = liveSessionSeconds(

    billPreview: billMap,

    plannedMinutes: base.plannedMinutes,

    openedAtRaw: table['opened_at']?.toString(),

    isPaused: false,

  );

  final activeSeconds = liveSecs.activeSeconds;

  final remaining = liveSecs.remainingSeconds;



  final rate = jsonToDouble(table['session_hourly_rate'] ?? table['hourly_rate']);

  final timeCharge = timeBillingEnabled

      ? BillingCalculator.calculateTimeCharge(

          activeSeconds: activeSeconds,

          hourlyRate: rate,

          billingMode: billingMode,

          minBillingMinutes: minBillingMinutes,

          billingIncrementMinutes: billingIncrementMinutes,

          billingGraceMinutes: billingGraceMinutes,

          plannedMinutes: base.plannedMinutes,

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



  return _withDiscount(

    table,

    TableLiveSnapshot(bill: bill, items: items, isExpired: expired, isUrgent: urgent),

  );

}



TableLiveSnapshot _withDiscount(Map<String, dynamic> table, TableLiveSnapshot snapshot) {

  final resolved = resolveSessionDiscount(

    timeCharge: snapshot.bill.timeCharge,

    productsTotal: snapshot.bill.productsTotal,

    session: _discountSessionFromTable(table),

  );

  if (resolved.discount <= 0) return snapshot;



  final subtotal = snapshot.bill.timeCharge + snapshot.bill.productsTotal;

  final discountedBill = BillingPreview(

    activeSeconds: snapshot.bill.activeSeconds,

    timeCharge: snapshot.bill.timeCharge,

    productsTotal: snapshot.bill.productsTotal,

    totalAmount: double.parse((subtotal - resolved.discount).toStringAsFixed(2)),

    plannedMinutes: snapshot.bill.plannedMinutes,

    remainingSeconds: snapshot.bill.remainingSeconds,

  );



  return TableLiveSnapshot(

    bill: discountedBill,

    items: snapshot.items,

    isExpired: snapshot.isExpired,

    isUrgent: snapshot.isUrgent,

    isPackage: snapshot.isPackage,

    discount: resolved.discount,

    promotionName: resolved.promotionName,

  );

}



Map<String, dynamic> _discountSessionFromTable(Map<String, dynamic> table) {

  final billMap = table['bill_preview'] as Map<String, dynamic>?;

  return {

    'discount_type': table['session_discount_type'] ?? 'none',

    'discount_value': table['session_discount_value'] ?? 0,

    'discount_applies_to': table['session_discount_applies_to'] ?? 'time_only',

    'discount': billMap?['discount'],

    'active_promotion': table['active_promotion'] ?? billMap?['active_promotion'],

    'active_customer_group': table['active_customer_group'] ?? billMap?['active_customer_group'],

    'bill_preview': billMap,

  };

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


