import 'package:flutter_test/flutter_test.dart';
import 'package:psclub_pos/core/billing/live_session_seconds.dart';
import 'package:psclub_pos/core/billing/session_live_bill.dart';
import 'package:psclub_pos/core/utils/session_datetime.dart';
import 'package:psclub_pos/features/cashier/widgets/table_live_state.dart';

void main() {
  test('manual time_only discount excludes products', () {
    final session = {
      'session_type': 'table',
      'status': 'active',
      'opened_at': DateTime.now().toUtc().toIso8601String(),
      'set_price_snapshot': 10.0,
      'discount_type': 'fixed',
      'discount_value': 5.0,
      'discount_applies_to': 'time_only',
      'pauses': [],
      'items': [
        {'quantity': 2, 'unit_price': 3.0, 'is_set_item': false},
      ],
    };

    final bill = computeSessionLiveBill(
      session,
      billingMode: 'per_minute',
      timeBillingEnabled: true,
    );

    expect(bill.productsTotal, 6.0);
    expect(bill.discount, 5.0);
    expect(bill.totalAmount, bill.timeCharge + 6.0 - 5.0);
  });

  test('active promotion applies to time charge only', () {
    final session = {
      'session_type': 'table',
      'status': 'active',
      'opened_at': DateTime.now().toUtc().toIso8601String(),
      'set_price_snapshot': 20.0,
      'discount_type': 'none',
      'discount_applies_to': 'time_only',
      'active_promotion': {
        'name': 'Kids day',
        'discount_type': 'percent',
        'discount_value': 50.0,
      },
      'pauses': [],
      'items': [
        {'quantity': 1, 'unit_price': 4.0, 'is_set_item': false},
      ],
    };

    final bill = computeSessionLiveBill(
      session,
      billingMode: 'per_minute',
      timeBillingEnabled: true,
    );

    expect(bill.productsTotal, 4.0);
    expect(bill.discount, closeTo(bill.timeCharge * 0.5, 0.01));
    expect(bill.promotionName, 'Kids day');
  });

  test('customer group discount applies when better than promotion', () {
    final session = {
      'session_type': 'table',
      'status': 'active',
      'opened_at': DateTime.now().toUtc().toIso8601String(),
      'set_price_snapshot': 20.0,
      'discount_type': 'none',
      'active_customer_group': {
        'name': 'VIP',
        'discount_type': 'percent',
        'discount_value': 15.0,
        'applies_to': 'time_only',
      },
      'active_promotion': {
        'name': 'Happy hour',
        'discount_type': 'percent',
        'discount_value': 10.0,
      },
      'pauses': [],
      'items': [],
    };

    final bill = computeSessionLiveBill(
      session,
      billingMode: 'per_minute',
      timeBillingEnabled: true,
    );

    expect(bill.promotionName, 'VIP');
    expect(bill.discount, closeTo(bill.timeCharge * 0.15, 0.01));
  });

  test('table live bill applies active promotion from bill preview', () {
    final table = {
      'session_id': 1,
      'status': 'active',
      'session_status': 'active',
      'opened_at': DateTime.now().toUtc().toIso8601String(),
      'session_hourly_rate': 12.0,
      'session_discount_type': 'none',
      'session_discount_value': 0,
      'session_discount_applies_to': 'time_only',
      'session_set_price': 20.0,
      'bill_preview': {
        'active_seconds': 0,
        'time_charge': 20.0,
        'products_total': 5.0,
        'discount': 10.0,
        'promotion_name': 'Kids day',
        'promotion_discount_type': 'percent',
        'promotion_discount_value': 50.0,
        'total_amount': 15.0,
        'computed_at': DateTime.now().toUtc().toIso8601String(),
      },
    };

    final snap = computeTableLive(
      table,
      billingMode: 'per_minute',
      timeBillingEnabled: true,
    );

    expect(snap, isNotNull);
    expect(snap!.discount, closeTo(10.0, 0.01));
    expect(snap.promotionName, 'Kids day');
    expect(snap.bill.totalAmount, closeTo(15.0, 0.01));
  });

  test('liveSessionSeconds counts elapsed time within planned window', () {
    final now = DateTime.utc(2026, 6, 19, 12, 0, 0);
    SessionClock.reset();
    SessionClock.sync(now.toIso8601String());
    addTearDown(SessionClock.reset);

    final billPreview = {
      'active_seconds': 1800,
      'remaining_seconds': 1800,
      'computed_at': now.toIso8601String(),
    };

    final live = liveSessionSeconds(
      billPreview: billPreview,
      plannedMinutes: 60,
      openedAtRaw: now.subtract(const Duration(minutes: 30)).toIso8601String(),
      isPaused: false,
    );

    expect(live.activeSeconds, 1800);
    expect(live.remainingSeconds, 1800);
  });

  test('liveSessionSeconds stops at planned duration when time expires', () {
    final now = DateTime.utc(2026, 6, 19, 12, 0, 0);
    SessionClock.reset();
    SessionClock.sync(now.toIso8601String());
    addTearDown(SessionClock.reset);

    final billPreview = {
      'active_seconds': 3600,
      'remaining_seconds': 0,
      'computed_at': now.toIso8601String(),
    };

    final live = liveSessionSeconds(
      billPreview: billPreview,
      plannedMinutes: 60,
      openedAtRaw: now.subtract(const Duration(hours: 6)).toIso8601String(),
      isPaused: false,
    );

    expect(live.activeSeconds, 3600);
    expect(live.remainingSeconds, 0);
  });

  test('liveSessionSeconds does not freeze activeSeconds for packages after expiry', () {
    final now = DateTime.utc(2026, 6, 19, 12, 0, 0);
    SessionClock.reset();
    SessionClock.sync(now.toIso8601String());
    addTearDown(SessionClock.reset);

    final computedAt = now.subtract(const Duration(minutes: 10));
    final billPreview = {
      'active_seconds': 3600,
      'remaining_seconds': 0,
      'computed_at': computedAt.toIso8601String(),
    };

    final live = liveSessionSeconds(
      billPreview: billPreview,
      plannedMinutes: 60,
      openedAtRaw: now.subtract(const Duration(hours: 2)).toIso8601String(),
      isPaused: false,
      isPackage: true,
      setPrice: 20,
    );

    expect(live.activeSeconds, 3600 + 10 * 60);
    expect(live.remainingSeconds, 0);
  });

  test('billPayableTotal uses live fallback adjusted by loyalty when gross diverges', () {
    final billMap = {
      'total_amount': 20.0,
      'loyalty_preview': {
        'loyalty_credit': 5.0,
        'total_after_bonus': 15.0,
      },
    };

    // Stale preview net would be 15; live gross 30 → 30 - 5 = 25
    expect(billPayableTotal(billMap, 30.0), closeTo(25.0, 0.01));
    // Matching live gross still prefers server total_after_bonus
    expect(billPayableTotal(billMap, 20.0), closeTo(15.0, 0.01));
  });

  test('computeSessionLiveBill caps timed session at planned duration', () {
    final now = DateTime.utc(2026, 6, 19, 12, 0, 0);
    SessionClock.reset();
    SessionClock.sync(now.toIso8601String());
    addTearDown(SessionClock.reset);
    final openedAt = now.subtract(const Duration(hours: 6));
    final billPreview = {
      'active_seconds': 3600,
      'remaining_seconds': 0,
      'computed_at': now.toIso8601String(),
      'time_charge': 10.0,
      'products_total': 0.0,
      'total_amount': 10.0,
      'discount': 0.0,
      'planned_minutes': 60,
      'is_countdown': true,
    };

    final session = {
      'session_type': 'table',
      'status': 'active',
      'opened_at': openedAt.toIso8601String(),
      'hourly_rate_snapshot': 10.0,
      'planned_minutes': 60,
      'pauses': [],
      'items': [],
      'bill_preview': billPreview,
    };

    final bill = computeSessionLiveBill(
      session,
      billingMode: 'min_1h_then_30',
      timeBillingEnabled: true,
      minBillingMinutes: 60,
      billingIncrementMinutes: 30,
      billingGraceMinutes: 10,
      now: now,
    );

    expect(bill.activeSeconds, 3600);
    expect(bill.activeMinutes, 60);
    expect(bill.timeCharge, closeTo(10.0, 0.01));
    expect(bill.remainingSeconds, 0);
  });

  test('computeSessionLiveBill fallback caps timed session at planned duration', () {
    final now = DateTime.utc(2026, 6, 19, 12, 0, 0);
    final openedAt = now.subtract(const Duration(hours: 6));

    final session = {
      'session_type': 'table',
      'status': 'active',
      'opened_at': openedAt.toIso8601String(),
      'hourly_rate_snapshot': 10.0,
      'planned_minutes': 60,
      'pauses': [],
      'items': [],
    };

    final bill = computeSessionLiveBill(
      session,
      billingMode: 'min_1h_then_30',
      timeBillingEnabled: true,
      minBillingMinutes: 60,
      billingIncrementMinutes: 30,
      billingGraceMinutes: 10,
      now: now,
    );

    expect(bill.activeSeconds, 3600);
    expect(bill.activeMinutes, 60);
    expect(bill.timeCharge, closeTo(10.0, 0.01));
    expect(bill.remainingSeconds, 0);
  });

  test('product discount from bill_preview adds to time promotion', () {
    final session = {
      'session_type': 'table',
      'status': 'active',
      'opened_at': DateTime.now().toUtc().toIso8601String(),
      'set_price_snapshot': 20.0,
      'discount_type': 'none',
      'discount_applies_to': 'time_only',
      'active_promotion': {
        'name': 'Kids day',
        'discount_type': 'percent',
        'discount_value': 50.0,
      },
      'bill_preview': {
        'product_discount': 2.0,
        'active_product_promotions': [
          {'name': 'Cola 20%', 'discount_type': 'percent', 'discount_value': 20.0},
        ],
        'item_discounts': {'11': 2.0},
      },
      'pauses': [],
      'items': [
        {'id': 11, 'quantity': 1, 'unit_price': 10.0, 'is_set_item': false},
      ],
    };

    final bill = computeSessionLiveBill(
      session,
      billingMode: 'per_minute',
      timeBillingEnabled: true,
    );

    // time 50% of 20 = 10 + product 2 = 12
    expect(bill.discount, closeTo(12.0, 0.01));
    expect(bill.productsTotal, 10.0);
    expect(readItemDiscounts(session)[11], 2.0);
  });

  test('manual discount ignores product_discount from bill_preview', () {
    final session = {
      'session_type': 'table',
      'status': 'active',
      'opened_at': DateTime.now().toUtc().toIso8601String(),
      'set_price_snapshot': 10.0,
      'discount_type': 'fixed',
      'discount_value': 3.0,
      'discount_applies_to': 'time_only',
      'bill_preview': {
        'product_discount': 5.0,
        'item_discounts': {'1': 5.0},
      },
      'pauses': [],
      'items': [
        {'id': 1, 'quantity': 1, 'unit_price': 8.0, 'is_set_item': false},
      ],
    };

    final bill = computeSessionLiveBill(
      session,
      billingMode: 'per_minute',
      timeBillingEnabled: true,
    );

    expect(bill.discount, 3.0);
  });

  test('counter gift 100% zeroes the product total', () {
    final session = {
      'session_type': 'counter',
      'status': 'active',
      'opened_at': DateTime.now().toUtc().toIso8601String(),
      'discount_type': 'percent',
      'discount_value': '100.00',
      'discount_applies_to': 'all',
      'pauses': <dynamic>[],
      'items': [
        {'id': '4', 'quantity': '1', 'unit_price': '3.50', 'is_set_item': 0},
      ],
    };

    final bill = computeSessionLiveBill(
      session,
      billingMode: 'per_minute',
      timeBillingEnabled: true,
    );

    expect(bill.productsTotal, 3.5);
    expect(bill.discount, 3.5);
    expect(bill.totalAmount, 0);
  });

  test('counter gift zeroes products even when scope is time_only', () {
    final session = {
      'session_type': 'counter',
      'status': 'active',
      'opened_at': DateTime.now().toUtc().toIso8601String(),
      'discount_type': 'percent',
      'discount_value': 100,
      'discount_applies_to': 'time_only',
      'pauses': <dynamic>[],
      'items': [
        {'quantity': 2, 'unit_price': 3.5, 'is_set_item': false},
      ],
    };

    final bill = computeSessionLiveBill(
      session,
      billingMode: 'per_minute',
      timeBillingEnabled: true,
    );

    expect(bill.discount, 7);
    expect(bill.totalAmount, 0);
  });

  test('table 100% time_only discount does not zero products', () {
    final session = {
      'session_type': 'table',
      'status': 'active',
      'opened_at': DateTime.now().toUtc().toIso8601String(),
      'set_price_snapshot': 10.0,
      'discount_type': 'percent',
      'discount_value': 100,
      'discount_applies_to': 'time_only',
      'pauses': <dynamic>[],
      'items': [
        {'quantity': 1, 'unit_price': 4.0, 'is_set_item': false},
      ],
    };

    final bill = computeSessionLiveBill(
      session,
      billingMode: 'per_minute',
      timeBillingEnabled: true,
    );

    expect(bill.productsTotal, 4);
    expect(bill.discount, 10);
    expect(bill.totalAmount, 4);
  });
}
