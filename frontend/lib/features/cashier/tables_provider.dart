import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/pos_service.dart';

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
    } catch (e, st) {
      if (previous == null) {
        state = AsyncError(e, st);
      }
    }
  }
}

final tablesProvider = AsyncNotifierProvider<TablesNotifier, List<dynamic>>(TablesNotifier.new);
