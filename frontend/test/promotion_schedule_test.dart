import 'package:flutter_test/flutter_test.dart';
import 'package:psclub_pos/core/utils/promotion_schedule.dart';

void main() {
  test('specific day mode and labels', () {
    final day = DateTime(2026, 6, 1, 0, 0);
    final until = DateTime(2026, 6, 1, 23, 59, 59);
    expect(PromotionSchedule.modeOf(day, until), PromotionDurationMode.singleDay);
    expect(PromotionSchedule.toApiDate(day), '2026-06-01');
    expect(PromotionSchedule.rangeLabel(day, until), '01.06.2026');
  });

  test('range and unlimited modes', () {
    expect(PromotionSchedule.modeOf(null, null), PromotionDurationMode.unlimited);
    expect(PromotionSchedule.rangeLabel(null, null), isNull);
    final from = DateTime(2026, 6, 1);
    final until = DateTime(2026, 6, 7);
    expect(PromotionSchedule.modeOf(from, until), PromotionDurationMode.range);
    expect(PromotionSchedule.rangeLabel(from, until), '01.06.2026 – 07.06.2026');
  });

  test('parse api datetime from backend', () {
    final parsed = PromotionSchedule.parseApiDate('2026-06-01 23:59:59');
    expect(parsed, isNotNull);
    expect(PromotionSchedule.modeOf(
      PromotionSchedule.parseApiDate('2026-06-01 00:00:00'),
      parsed,
    ), PromotionDurationMode.singleDay);
  });

  test('HH:mm validation', () {
    expect(PromotionSchedule.parseMinutes('18:00'), 18 * 60);
    expect(PromotionSchedule.parseMinutes('9:00'), 9 * 60);
    expect(PromotionSchedule.normalizeHm('9:05'), '09:05');
    expect(PromotionSchedule.parseMinutes('abc'), isNull);
    expect(PromotionSchedule.parseMinutes('25:00'), isNull);
    expect(PromotionSchedule.isValidHm('18:00'), isTrue);
  });
}
