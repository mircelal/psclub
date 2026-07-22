import 'package:flutter_test/flutter_test.dart';
import 'package:psclub_pos/core/billing/billing_calculator.dart';
import 'package:psclub_pos/core/billing/effective_tariff_quote.dart';
import 'package:psclub_pos/core/utils/json_parse.dart';
import 'package:psclub_pos/core/utils/session_datetime.dart';

void main() {
  const minM = 60;
  const stepM = 30;
  const grace = 10;

  int bill(int minutes) => BillingCalculator.billableMinutesFromActive(
        activeSeconds: minutes * 60,
        minBillingMinutes: minM,
        billingIncrementMinutes: stepM,
        billingGraceMinutes: grace,
      );

  test('min_1h_then_30 with grace — open-ended', () {
    expect(bill(10), 60);
    expect(bill(60), 60);
    expect(bill(69), 60);
    expect(bill(70), 60);
    expect(bill(71), 90);
    expect(bill(80), 90);
    expect(bill(100), 90);
  });

  test('planned minutes — no grace', () {
    expect(
      BillingCalculator.billableMinutesFromPlanned(
        plannedMinutes: 90,
        minBillingMinutes: minM,
        billingIncrementMinutes: stepM,
      ),
      90,
    );
    expect(
      BillingCalculator.billableMinutes(
        activeSeconds: 30 * 60,
        billingMode: 'min_1h_then_30',
        plannedMinutes: 90,
      ),
      90,
    );
  });

  test('per_minute unchanged for open-ended sessions', () {
    expect(
      BillingCalculator.billableMinutes(
        activeSeconds: 69 * 60,
        billingMode: 'per_minute',
      ),
      69,
    );
  });

  test('per_minute caps charge at planned duration for timed sessions', () {
    final charge = BillingCalculator.calculateTimeCharge(
      activeSeconds: 180 * 60,
      hourlyRate: 10.0,
      billingMode: 'per_minute',
      plannedMinutes: 60,
    );
    expect(charge, closeTo(10.0, 0.01));
  });

  test('open-ended session keeps min 1h + grace rule', () {
    final charge = BillingCalculator.calculateTimeCharge(
      activeSeconds: 70 * 60,
      hourlyRate: 10.0,
      billingMode: 'min_1h_then_30',
      minBillingMinutes: minM,
      billingIncrementMinutes: stepM,
      billingGraceMinutes: grace,
      plannedMinutes: null,
    );
    expect(charge, closeTo(10.0, 0.01));
  });

  test('capActiveSecondsForPlanned limits elapsed time', () {
    expect(
      BillingCalculator.capActiveSecondsForPlanned(180 * 60, 60),
      60 * 60,
    );
    expect(
      BillingCalculator.capActiveSecondsForPlanned(45 * 60, 60),
      45 * 60,
    );
    expect(
      BillingCalculator.capActiveSecondsForPlanned(180 * 60, null),
      180 * 60,
    );
    expect(
      BillingCalculator.capActiveSecondsForPlanned(180 * 60, 120),
      120 * 60,
    );
  });

  test('effective hourly after percent promotion', () {
    final quote = quoteHourlyForTariff(
      tariffName: 'PS5',
      hourlyRate: 5,
      activePromotions: [
        {
          'name': 'Uşaqlar günü',
          'discount_type': 'percent',
          'discount_value': 10,
          'scope': 'all_tables',
        },
      ],
    );
    expect(quote.effectiveHourly, 4.5);
    expect(quote.hasDiscount, isTrue);
    expect(quote.effectiveLabel, '4.50 ₼ / saat');
  });

  test('package session isCountdown is false even with planned minutes', () {
    final preview = BillingPreview(
      activeSeconds: 100,
      timeCharge: 15,
      productsTotal: 0,
      totalAmount: 15,
      plannedMinutes: 60,
      remainingSeconds: 3500,
      isPackage: true,
    );
    expect(preview.isCountdown, isFalse);
    expect(
      BillingPreview(
        activeSeconds: 100,
        timeCharge: 10,
        productsTotal: 0,
        totalAmount: 10,
        plannedMinutes: 60,
        remainingSeconds: 3500,
      ).isCountdown,
      isTrue,
    );
  });

  test('fromSessionData marks package from session_set_price', () {
    final now = DateTime.utc(2026, 6, 19, 12, 0, 0);
    SessionClock.reset();
    SessionClock.sync(now.toIso8601String());
    addTearDown(SessionClock.reset);

    final preview = BillingCalculator.fromSessionData(
      table: {
        'opened_at': now.subtract(const Duration(minutes: 30)).toIso8601String(),
        'session_set_price': 20.0,
        'planned_minutes': 60,
        'session_hourly_rate': 10.0,
        'pauses': [],
      },
      billingMode: 'min_1h_then_30',
      now: now,
    );

    expect(preview.isPackage, isTrue);
    expect(preview.isCountdown, isFalse);
    expect(preview.timeCharge, closeTo(20.0, 0.01));
  });

  test('jsonToIntOrNull parses decimal strings', () {
    expect(jsonToIntOrNull('60.0'), 60);
    expect(jsonToIntOrNull('90.5'), 90);
    expect(jsonToIntOrNull('42'), 42);
    expect(jsonToIntOrNull(null), isNull);
  });
}
