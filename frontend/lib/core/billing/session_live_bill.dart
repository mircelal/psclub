import 'billing_calculator.dart';
import 'live_session_seconds.dart';
import '../utils/json_parse.dart';
import '../utils/session_datetime.dart';

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
    this.promotionName,
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
  final String? promotionName;
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
  int minBillingMinutes = 60,
  int billingIncrementMinutes = 30,
  int billingGraceMinutes = 10,
  DateTime? now,
}) {
  final pauses = session['pauses'] as List<dynamic>? ?? [];
  final items = session['items'] as List<dynamic>? ?? [];
  final isPaused = session['status'] == 'paused';
  final billPreview = session['bill_preview'] as Map<String, dynamic>?;
  final plannedMinutes = jsonToIntOrNull(session['planned_minutes']);
  final setPrice = jsonToDouble(session['set_price_snapshot']);
  final isPackage = setPrice > 0;

  int activeSeconds;
  int? remainingFromLive;
  if (billPreview != null && !isPaused) {
    final live = liveSessionSeconds(
      billPreview: billPreview,
      plannedMinutes: plannedMinutes,
      openedAtRaw: session['opened_at']?.toString(),
      isPaused: false,
      isPackage: isPackage,
      setPrice: setPrice,
    );
    activeSeconds = live.activeSeconds;
    remainingFromLive = live.remainingSeconds;
  } else {
    final end = (now ?? SessionClock.nowUtc()).toUtc();
    final opened = parseSessionDateTime(session['opened_at']?.toString());
    activeSeconds = 0;
    if (opened != null) {
      activeSeconds = _activeSeconds(opened.toUtc(), end, pauses, isPaused);
    }
  }

  final isCounter = (session['session_type'] ?? 'table') == 'counter';
  if (!isPackage && plannedMinutes != null && plannedMinutes > 0) {
    activeSeconds = BillingCalculator.capActiveSecondsForPlanned(activeSeconds, plannedMinutes);
  }
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
            minBillingMinutes: minBillingMinutes,
            billingIncrementMinutes: billingIncrementMinutes,
            billingGraceMinutes: billingGraceMinutes,
            plannedMinutes: plannedMinutes,
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
  final resolved = resolveSessionDiscount(
    timeCharge: timeCharge,
    productsTotal: productsTotal,
    session: session,
  );
  final discount = resolved.discount;
  final promotionName = resolved.promotionName;

  final total = double.parse((subtotal - discount).toStringAsFixed(2));
  final couponCode = session['coupon_code'] as String?;

  final remaining = remainingFromLive ??
      (plannedMinutes != null && plannedMinutes > 0 && setPrice <= 0
          ? (plannedMinutes * 60 - activeSeconds).clamp(0, plannedMinutes * 60)
          : setPrice > 0 && plannedMinutes != null && plannedMinutes > 0
              ? (plannedMinutes * 60 - activeSeconds).clamp(0, plannedMinutes * 60)
              : null);

  final countdown = setPrice <= 0 && plannedMinutes != null && plannedMinutes > 0;
  final discountType = session['discount_type'] as String? ?? 'none';
  final discountValue = jsonToDouble(session['discount_value']);

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
    isCountdown: countdown,
    discountType: discountType != 'none' ? discountType : null,
    discountValue: discountType != 'none' ? discountValue : null,
    couponCode: couponCode,
    promotionName: promotionName,
  );
}

class SessionDiscountSnapshot {
  const SessionDiscountSnapshot({required this.discount, this.promotionName});

  final double discount;
  final String? promotionName;
}

Map<String, dynamic>? readActivePromotion(Map<String, dynamic> session) {
  final direct = session['active_promotion'];
  if (direct is Map<String, dynamic>) return direct;
  if (direct is Map) return Map<String, dynamic>.from(direct);

  final bill = session['bill_preview'];
  if (bill is! Map) return null;
  final name = bill['promotion_name'] as String?;
  if (name == null || name.isEmpty) return null;

  return {
    'name': name,
    'discount_type': bill['promotion_discount_type'] as String? ?? 'percent',
    'discount_value': jsonToDouble(bill['promotion_discount_value']),
  };
}

Map<String, dynamic>? readActiveCustomerGroup(Map<String, dynamic> session) {
  final direct = session['active_customer_group'];
  if (direct is Map<String, dynamic>) return direct;
  if (direct is Map) return Map<String, dynamic>.from(direct);

  final bill = session['bill_preview'];
  if (bill is Map && bill['active_customer_group'] is Map) {
    return Map<String, dynamic>.from(bill['active_customer_group'] as Map);
  }
  if (bill is! Map) return null;
  final name = bill['customer_group_name'] as String? ?? bill['discount_label'] as String?;
  if (name == null || name.isEmpty) return null;

  return {
    'name': name,
    'discount_type': bill['customer_group_discount_type'] as String? ?? 'percent',
    'discount_value': jsonToDouble(bill['customer_group_discount_value']),
    'applies_to': bill['customer_group_applies_to'] as String? ?? 'time_only',
  };
}

double _discountForSource(
  Map<String, dynamic> source, {
  required double timeCharge,
  required double subtotal,
}) {
  final appliesTo = source['applies_to'] as String? ?? 'time_only';
  final base = appliesTo == 'all' ? subtotal : timeCharge;
  if (base <= 0) return 0;
  final type = source['discount_type'] as String? ?? 'percent';
  final value = jsonToDouble(source['discount_value']);
  return _computeDiscount(base, type, value, 0);
}

double readProductDiscount(Map<String, dynamic> session) {
  final bill = session['bill_preview'];
  if (bill is Map) {
    final fromBill = jsonToDouble(bill['product_discount']);
    if (fromBill > 0) return fromBill;
  }
  return jsonToDouble(session['product_discount']);
}

/// Sessiya sətiri id → məhsul endirimi məbləği (server bill_preview).
Map<int, double> readItemDiscounts(Map<String, dynamic> session) {
  final out = <int, double>{};
  final raw = session['bill_preview'] is Map
      ? (session['bill_preview'] as Map)['item_discounts']
      : session['item_discounts'];
  if (raw is! Map) return out;
  raw.forEach((key, value) {
    final id = jsonToInt(key);
    final amount = jsonToDouble(value);
    if (id > 0 && amount > 0) out[id] = amount;
  });
  return out;
}

SessionDiscountSnapshot resolveSessionDiscount({
  required double timeCharge,
  required double productsTotal,
  required Map<String, dynamic> session,
}) {
  final subtotal = double.parse((timeCharge + productsTotal).toStringAsFixed(2));
  final discountType = session['discount_type'] as String? ?? 'none';
  final discountValue = jsonToDouble(session['discount_value']);
  // Kassa satışında əl endirimi məhsula da şamil olunur. `time_only` burada
  // vaxt haqqı 0 olduğu üçün endirimi silir və hədiyyə (100%) yenə pul istəyir.
  var appliesTo = session['discount_applies_to'] as String? ?? 'time_only';
  if ((session['session_type'] ?? 'table') == 'counter' && discountType != 'none') {
    appliesTo = 'all';
  }

  double discount;
  String? promotionName;
  if (discountType != 'none') {
    final base = appliesTo == 'time_only' ? timeCharge : subtotal;
    discount = _computeDiscount(base, discountType, discountValue, 0);
  } else {
    final group = readActiveCustomerGroup(session);
    final promo = readActivePromotion(session);
    final groupAmount = group != null ? _discountForSource(group, timeCharge: timeCharge, subtotal: subtotal) : 0.0;
    final promoAmount = promo != null
        ? _discountForSource({...promo, 'applies_to': 'time_only'}, timeCharge: timeCharge, subtotal: subtotal)
        : 0.0;
    final productDiscount = readProductDiscount(session);

    double timeOrGroup = 0;
    if (group != null && groupAmount >= promoAmount && groupAmount > 0) {
      timeOrGroup = groupAmount;
      promotionName = group['name'] as String?;
    } else if (promo != null && promoAmount > 0) {
      timeOrGroup = promoAmount;
      promotionName = promo['name'] as String?;
    }

    discount = timeOrGroup + productDiscount;
    if (discount <= 0) {
      discount = jsonToDouble(session['discount']);
      if (discount <= 0 && session['bill_preview'] is Map) {
        final bill = session['bill_preview'] as Map;
        discount = jsonToDouble(bill['discount']);
        promotionName ??= bill['customer_group_name'] as String? ??
            bill['promotion_name'] as String? ??
            bill['discount_label'] as String?;
      }
    } else if (promotionName == null && productDiscount > 0 && session['bill_preview'] is Map) {
      final promos = (session['bill_preview'] as Map)['active_product_promotions'];
      if (promos is List && promos.isNotEmpty && promos.first is Map) {
        promotionName = (promos.first as Map)['name'] as String?;
      }
    }
    if (discount > subtotal) discount = subtotal;
  }

  return SessionDiscountSnapshot(
    discount: double.parse(discount.toStringAsFixed(2)),
    promotionName: promotionName,
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
    final pausedAt = parseSessionDateTime(p['paused_at']?.toString());
    if (pausedAt == null) continue;
    final resumedAt =
        parseSessionDateTime(p['resumed_at']?.toString())?.toUtc() ?? (isPaused ? end : end);
    paused += resumedAt.difference(pausedAt.toUtc()).inSeconds.clamp(0, 999999);
  }

  return (total - paused).clamp(0, 999999);
}

/// API `bill_preview` ümumi məbləği (bonus öncəsi).
double billGrossTotal(Map<String, dynamic> billMap) => jsonToDouble(billMap['total_amount']);

/// Müştəri bonusu tətbiq olunmuş ödəniləcək məbləğ.
///
/// Canlı `fallback` (live gross) verilib və server preview gross-dan fərqlənirsə,
/// köhnə `total_after_bonus` əvəzinə [adjustTotalForLoyalty] tətbiq olunur.
double billPayableTotal(Map<String, dynamic> billMap, [double? fallback]) {
  if (fallback != null) {
    final previewGross = billGrossTotal(billMap);
    if ((fallback - previewGross).abs() >= 0.02) {
      return adjustTotalForLoyalty(billMap, fallback);
    }
  }
  final loyalty = billMap['loyalty_preview'] as Map<String, dynamic>?;
  if (loyalty != null) {
    return jsonToDouble(loyalty['total_after_bonus'], fallback ?? billGrossTotal(billMap));
  }
  return fallback ?? billGrossTotal(billMap);
}

/// Loyallıq endirimi (₼); yoxdursa null.
double? billLoyaltyCredit(Map<String, dynamic> billMap) {
  final loyalty = billMap['loyalty_preview'] as Map<String, dynamic>?;
  if (loyalty == null) return null;
  final credit = jsonToDouble(loyalty['loyalty_credit']);
  return credit > 0 ? credit : null;
}

/// Canlı hesablanmış ümumi + server loyalty preview uyğunlaşdırması.
double adjustTotalForLoyalty(Map<String, dynamic>? billMap, double grossTotal) {
  if (billMap == null) return grossTotal;
  final loyalty = billMap['loyalty_preview'] as Map<String, dynamic>?;
  if (loyalty == null) return grossTotal;
  final previewGross = billGrossTotal(billMap);
  final previewNet = billPayableTotal(billMap);
  final credit = jsonToDouble(loyalty['loyalty_credit']);
  if (credit <= 0) return grossTotal;
  if ((grossTotal - previewGross).abs() < 0.02) return previewNet;
  return (grossTotal - credit).clamp(0.0, grossTotal);
}
