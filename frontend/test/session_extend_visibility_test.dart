import 'package:flutter_test/flutter_test.dart';
import 'package:psclub_pos/core/config/business_config_provider.dart';
import 'package:psclub_pos/features/cashier/widgets/session_extend_dialog.dart';

void main() {
  const config = BusinessConfig.fallback;

  test('planned 180 dəq (3 saat) olanda uzatma seçənəyi görünür', () {
    expect(
      sessionCanExtendTime({'session_type': 'table', 'planned_minutes': 180}, config),
      isTrue,
    );
    expect(config.extendTimeOptions, isNotEmpty);
  });

  test('planned 12+ saat olanda belə uzatma seçənəyi görünür', () {
    expect(
      sessionCanExtendTime({'session_type': 'table', 'planned_minutes': 720}, config),
      isTrue,
    );
  });

  test('paket və kassa satışında uzatma yoxdur', () {
    expect(
      sessionCanExtendTime({
        'session_type': 'table',
        'planned_minutes': 60,
        'set_price_snapshot': 15.0,
      }, config),
      isFalse,
    );
    expect(
      sessionCanExtendTime({
        'session_type': 'counter',
        'planned_minutes': 60,
      }, config),
      isFalse,
    );
  });
}
