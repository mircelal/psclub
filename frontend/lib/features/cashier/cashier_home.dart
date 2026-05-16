import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_state.dart';
import '../../core/config/business_config_provider.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/ui_settings_sheet.dart';
import '../../core/theme/cashier_theme.dart';
import '../../core/utils/json_parse.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/empty_state.dart';
import '../../services/pos_service.dart';
import 'show_session_panel.dart';
import 'widgets/cashier_filter_bar.dart';
import 'widgets/cashier_stats_row.dart';
import 'widgets/cashier_top_bar.dart';
import 'widgets/open_table_dialog.dart';
import 'widgets/tables_layout.dart';

final tablesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.read(posServiceProvider).getTables();
});

class CashierHome extends ConsumerStatefulWidget {
  const CashierHome({super.key});

  @override
  ConsumerState<CashierHome> createState() => _CashierHomeState();
}

class _CashierHomeState extends ConsumerState<CashierHome> {
  Timer? _pollTimer;
  Timer? _tickTimer;
  int _tick = 0;
  CashierTableFilter _filter = CashierTableFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productsProvider.future);
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => ref.invalidate(tablesProvider));
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _openTable(Map<String, dynamic> table) async {
    final result = await showOpenTableDialog(context, table['name'] as String);
    if (result == null || !result.confirmed) return;

    try {
      final session = await ref.read(posServiceProvider).openSession(
            table['id'] as int,
            plannedMinutes: result.plannedMinutes,
          );
      if (!mounted) return;
      showSessionPanel(context, ref, session['id'] as int, () => ref.invalidate(tablesProvider));
      ref.invalidate(tablesProvider);
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  void _showSession(int sessionId) {
    showSessionPanel(context, ref, sessionId, () => ref.invalidate(tablesProvider));
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> list) {
    return switch (_filter) {
      CashierTableFilter.active => list.where((t) {
          final s = t['status'] as String? ?? 'empty';
          return s == 'active' || s == 'paused' || t['session_id'] != null;
        }).toList(),
      CashierTableFilter.empty => list.where((t) => (t['status'] as String? ?? 'empty') == 'empty').toList(),
      CashierTableFilter.all => list,
    };
  }

  double _liveRevenue(List<Map<String, dynamic>> list) {
    var sum = 0.0;
    for (final t in list) {
      if (t['session_id'] == null) continue;
      final preview = t['bill_preview'] as Map<String, dynamic>?;
      if (preview != null) {
        sum += jsonToDouble(preview['total_amount']);
      }
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final tablesAsync = ref.watch(tablesProvider);
    final uiSettings = ref.watch(appSettingsProvider).valueOrNull;
    final viewMode = uiSettings?.tableViewMode ?? TableViewMode.grid;
    final biz = ref.watch(businessConfigProvider).valueOrNull ?? BusinessConfig.fallback;

    return Scaffold(
      backgroundColor: CashierTheme.scaffoldBg(context),
      body: Column(
        children: [
          CashierTopBar(
            biz: biz,
            userName: user?.fullName ?? user?.username ?? '',
            liveRevenue: tablesAsync.maybeWhen(data: (t) => _liveRevenue(t.cast()), orElse: () => 0),
            onRefresh: () => ref.invalidate(tablesProvider),
            onSettings: () => showUiSettingsSheet(context),
            onAdmin: user?.isAdmin == true ? () => context.go('/admin') : null,
            onLogout: () => ref.read(authProvider.notifier).logout(),
          ),
          Expanded(
            child: tablesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              error: (e, _) => EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Serverə qoşulmaq olmur',
                subtitle: e.toString(),
                action: FilledButton.icon(
                  onPressed: () => ref.invalidate(tablesProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Yenidən cəhd et'),
                ),
              ),
              data: (tables) {
                final list = tables.cast<Map<String, dynamic>>();
                final filtered = _applyFilter(list);
                final active = list.where((t) => t['status'] == 'active' || t['status'] == 'paused').length;
                final empty = list.where((t) => t['status'] == 'empty').length;
                final revenue = _liveRevenue(list);

                return Column(
                  children: [
                    CashierStatsRow(active: active, empty: empty, total: list.length, liveRevenue: revenue),
                    CashierFilterBar(
                      filter: _filter,
                      onChanged: (f) => setState(() => _filter = f),
                      unitLabel: biz.labels.unitPlural,
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Bu filtrə uyğun stansiya yoxdur',
                                style: TextStyle(color: CashierTheme.textSecondary(context)),
                              ),
                            )
                          : TablesLayout(
                              tables: filtered,
                              viewMode: viewMode,
                              tick: _tick,
                              onOpen: _openTable,
                              onSession: _showSession,
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
