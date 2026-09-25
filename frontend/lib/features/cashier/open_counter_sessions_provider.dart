import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/json_parse.dart';
import '../../services/pos_service.dart';

/// Açıq birbaşa satışlar (table_id NULL / session_type=counter).
final openCounterSessionsProvider =
    AsyncNotifierProvider<OpenCounterSessionsNotifier, List<Map<String, dynamic>>>(
  OpenCounterSessionsNotifier.new,
);

class OpenCounterSessionsNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() => _fetch();

  Future<List<Map<String, dynamic>>> _fetch() async {
    final sessions = await ref.read(posServiceProvider).getActiveSessions();
    return sessions
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((s) {
          final type = s['session_type'] as String? ?? 'table';
          final tableId = s['table_id'];
          return type == 'counter' || tableId == null;
        })
        .toList();
  }

  Future<void> refresh() async {
    final previous = state.asData?.value;
    try {
      state = AsyncData(await _fetch());
    } catch (e, st) {
      if (previous == null) {
        state = AsyncError(e, st);
      }
    }
  }
}

double counterSessionPayable(Map<String, dynamic> session) {
  final bill = session['bill_preview'];
  if (bill is Map) {
    final total = jsonToDouble(bill['total_amount']);
    if (total > 0) return total;
  }
  return jsonToDouble(session['total_amount']);
}

int counterSessionItemCount(Map<String, dynamic> session) {
  final items = session['items'];
  if (items is! List) return 0;
  var n = 0;
  for (final raw in items) {
    if (raw is! Map) continue;
    if (raw['is_set_item'] == true || raw['is_set_item'] == 1) continue;
    n += jsonToInt(raw['quantity']).clamp(1, 9999);
  }
  return n;
}
