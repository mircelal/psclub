import 'package:flutter_test/flutter_test.dart';
import 'package:psclub_pos/core/billing/billing_calculator.dart';
import 'package:psclub_pos/core/billing/effective_tariff_quote.dart';

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

  test('per_minute unchanged', () {
    expect(
      BillingCalculator.billableMinutes(
        activeSeconds: 69 * 60,
        billingMode: 'per_minute',
      ),
      69,
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
}
