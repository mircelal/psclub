import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/pos_service.dart';
import 'session_sync_provider.dart';

/// Masalar siyahısı — yenilənəndə əvvəlki məlumat qalır (timer sıçramır).
class TablesNotifier extends AsyncNotifier<List<dynamic>> {
  @override
  Future<List<dynamic>> build() async {
    return ref.read(posServiceProvider).getTables();
  }

  Future<void> refresh() async {
    final previous = state.asData?.value;
    try {
      final data = await ref.read(posServiceProvider).getTables();
      state = AsyncData(data);
      _publishSessionRevisions(data);
    } catch (e, st) {
      if (previous == null) {
        state = AsyncError(e, st);
      }
    }
  }

  void _publishSessionRevisions(List<dynamic> tables) {
    final openId = ref.read(openSessionIdProvider);
    if (openId == null) return;

    for (final raw in tables) {
      final table = raw as Map<String, dynamic>;
      final sessionId = table['session_id'];
      if (sessionId == null || sessionId != openId) continue;
      final updatedAt = table['session_updated_at']?.toString();
      if (updatedAt != null && updatedAt.isNotEmpty) {
        ref.read(sessionRevisionProvider.notifier).bump(openId, updatedAt);
      }
      break;
    }
  }
}

final tablesProvider = AsyncNotifierProvider<TablesNotifier, List<dynamic>>(TablesNotifier.new);
