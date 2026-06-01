import 'package:flutter_test/flutter_test.dart';
import 'package:psclub_pos/core/billing/session_live_bill.dart';
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
}
