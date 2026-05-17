import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/json_parse.dart';
import '../../services/pos_service.dart';

/// autoDispose deyil — hər 3 saniyədə yenilənəndə UI yanıb-sönməsin.
final currentShiftProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return ref.read(posServiceProvider).getCurrentShift();
});

void refreshCurrentShift(WidgetRef ref) {
  ref.invalidate(currentShiftProvider);
}

final shiftCategoriesProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.read(posServiceProvider).getShiftCategories();
});

double shiftExpectedCash(Map<String, dynamic>? shift) {
  if (shift == null) return 0;
  final totals = shift['totals'] as Map<String, dynamic>?;
  if (totals != null) return jsonToDouble(totals['expected_cash']);
  return jsonToDouble(shift['opening_cash']);
}
