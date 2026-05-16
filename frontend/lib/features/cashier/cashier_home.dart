import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_state.dart';
import '../../core/config/business_config_provider.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/ui_settings_sheet.dart';
import '../../core/theme/cashier_breakpoints.dart';
import '../../core/theme/cashier_theme.dart';
import '../../core/theme/cashier_theme_data.dart';
import '../../core/utils/json_parse.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/empty_state.dart';
import '../../services/pos_service.dart';
import 'show_session_panel.dart';
import 'widgets/cashier_filter_bar.dart';
import 'widgets/cashier_stats_row.dart';
import 'widgets/cashier_side_rail.dart';
import 'widgets/cashier_top_bar.dart';
import 'widgets/counter_sales_bar.dart' show CounterSaleToolbar;
import 'widgets/open_counter_sale_dialog.dart';
import 'widgets/open_table_dialog.dart';
import 'widgets/table_context_menu.dart';
import 'widgets/table_session_state.dart';
import 'cashier_shortcuts.dart';
import 'widgets/tables_layout.dart';
import 'shift_provider.dart';
import 'shift_dialogs.dart';
import 'shift_guard.dart';

final tablesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.read(posServiceProvider).getTables();
});

class CashierHome extends ConsumerStatefulWidget {
  const CashierHome({super.key});

  @override
  ConsumerState<CashierHome> createState() => _CashierHomeState();
}

class _CashierHomeState extends ConsumerState<CashierHome> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _pollTimer;
  Timer? _tickTimer;
  int _tick = 0;
  CashierTableFilter _filter = CashierTableFilter.all;
  bool _shiftGateShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productsProvider.future);
      _maybePromptOpenShift();
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      ref.invalidate(tablesProvider);
      ref.invalidate(currentShiftProvider);
    });
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
    if (!await ensureOpenShiftForCashier(context, ref)) return;
    final result = await showOpenTableDialog(context, table);
    if (result == null || !result.confirmed) return;

    try {
      final session = await ref.read(posServiceProvider).openSession(
            table['id'] as int,
            plannedMinutes: result.plannedMinutes,
            tariffId: result.tariffId,
            setId: result.setId,
            customerId: result.customerId,
          );
      if (!mounted) return;
      showSessionPanel(context, ref, session['id'] as int, _onSessionChanged);
      _onSessionChanged();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  void _onSessionChanged() {
    ref.invalidate(tablesProvider);
  }

  Future<void> _showSession(int sessionId) async {
    if (!await ensureOpenShiftForCashier(context, ref)) return;
    if (!mounted) return;
    showSessionPanel(context, ref, sessionId, _onSessionChanged);
  }

  Future<void> _startCounterSale() async {
    if (!await ensureOpenShiftForCashier(context, ref)) return;
    final result = await showOpenCounterSaleDialog(context);
    if (result == null || !result.confirmed) return;

    try {
      final session = await ref.read(posServiceProvider).openCounterSale(customerId: result.customerId);
      if (!mounted) return;
      showSessionPanel(context, ref, session['id'] as int, _onSessionChanged);
      _onSessionChanged();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
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

  List<Map<String, dynamic>> _filteredTables() {
    final list = ref.read(tablesProvider).valueOrNull?.cast<Map<String, dynamic>>() ?? [];
    return _applyFilter(list);
  }

  Future<void> _activateTableSlot(int slot) async {
    if (!await ensureOpenShiftForCashier(context, ref)) return;
    final tables = _filteredTables();
    final index = slot - 1;
    if (index < 0 || index >= tables.length) return;
    final t = tables[index];
    final sessionId = TableSessionState.openSessionId(t);
    if (sessionId != null) {
      _showSession(sessionId);
    } else if (TableSessionState.canOpenSession(t)) {
      _openTable(t);
    }
  }

  void _refresh() {
    ref.invalidate(tablesProvider);
    ref.invalidate(currentShiftProvider);
  }

  Future<void> _maybePromptOpenShift() async {
    final user = ref.read(authProvider).valueOrNull;
    if (user?.isAdmin == true || _shiftGateShown || !mounted) return;

    final shift = await ref.read(currentShiftProvider.future);
    if (shift != null || !mounted) return;

    _shiftGateShown = true;
    await showOpenShiftDialog(context, ref);
  }

  Future<void> _handleOpenShift() async {
    await showOpenShiftDialog(context, ref);
  }

  Future<void> _handleCashIn(Map<String, dynamic> shift) async {
    await showCashPayInDialog(context, ref, shift['id'] as int);
  }

  Future<void> _handleCashOut(Map<String, dynamic> shift) async {
    await showCashOutDialog(context, ref, shift['id'] as int);
  }

  Future<void> _handleCloseShift(Map<String, dynamic> shift) async {
    await showCloseShiftDialog(context, ref, shift);
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
    final shiftAsync = ref.watch(currentShiftProvider);
    final currentShift = shiftAsync.valueOrNull;
    final tablesAsync = ref.watch(tablesProvider);
    final uiSettings = ref.watch(appSettingsProvider).valueOrNull;
    final viewMode = uiSettings?.tableViewMode ?? TableViewMode.grid;
    final biz = ref.watch(businessConfigProvider).valueOrNull ?? BusinessConfig.fallback;

    final list = tablesAsync.valueOrNull?.cast<Map<String, dynamic>>() ?? [];
    final active = list.where((t) => t['session_id'] != null).length;
    final empty = list.where((t) => t['session_id'] == null).length;
    final revenue = _liveRevenue(list);

    final isAdmin = user?.isAdmin == true;
    final needsShift = !isAdmin && currentShift == null && !shiftAsync.isLoading;

    Widget buildSideRail({required bool inDrawer}) {
      return CashierSideRail(
        inDrawer: inDrawer,
        biz: biz,
        userName: user?.fullName ?? user?.username ?? '',
        active: active,
        empty: empty,
        total: list.length,
        liveRevenue: revenue,
        filter: _filter,
        shift: currentShift,
        onOpenShift: _handleOpenShift,
        onCashIn: currentShift != null ? () => _handleCashIn(currentShift) : null,
        onCashOut: currentShift != null ? () => _handleCashOut(currentShift) : null,
        onCloseShift: currentShift != null ? () => _handleCloseShift(currentShift) : null,
        onFilterChanged: (f) {
          setState(() => _filter = f);
          if (inDrawer) _scaffoldKey.currentState?.closeDrawer();
        },
        onCounterSale: () {
          _startCounterSale();
          if (inDrawer) _scaffoldKey.currentState?.closeDrawer();
        },
        onRefresh: _refresh,
        onSettings: () {
          showUiSettingsSheet(context);
          if (inDrawer) _scaffoldKey.currentState?.closeDrawer();
        },
        onShowShortcuts: () {
          showCashierShortcutsDialog(context, showAdmin: isAdmin);
          if (inDrawer) _scaffoldKey.currentState?.closeDrawer();
        },
        onAdmin: isAdmin
            ? () {
                context.go('/admin');
                if (inDrawer) _scaffoldKey.currentState?.closeDrawer();
              }
            : null,
        onLogout: () => ref.read(authProvider.notifier).logout(),
      );
    }

    Widget buildMainColumn(CashierBreakpoints bp) {
      final padH = bp.contentPaddingH;
      final padT = bp.contentPaddingV;

      return ColoredBox(
        color: CashierTheme.surfaceMain(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CashierTopBar(
              biz: biz,
              liveRevenue: revenue,
              activeCount: active,
              totalCount: list.length,
              onCounterSale: _startCounterSale,
              onShowShortcuts: () => showCashierShortcutsDialog(context, showAdmin: isAdmin),
              onMenuTap: bp.showDrawer ? () => _scaffoldKey.currentState?.openDrawer() : null,
              layout: bp.topBarLayout,
            ),
            if (bp.showDrawer) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(padH, 8, padH, 0),
                child: CashierStatsRow(
                  active: active,
                  empty: empty,
                  total: list.length,
                  liveRevenue: revenue,
                ),
              ),
              CashierFilterBar(
                filter: _filter,
                onChanged: (f) => setState(() => _filter = f),
                unitLabel: biz.labels.unitPlural,
                horizontalScroll: bp.isMobile,
              ),
            ],
            if (bp.isDesktop) CounterSaleToolbar(onNewSale: _startCounterSale),
            Expanded(
              child: Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(padH, padT, padH, padH),
                    child: DecoratedBox(
                      decoration: CashierTheme.contentPanelDecoration(context),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(CashierTheme.radiusCard + 2),
                        child: tablesAsync.when(
                          loading: () => Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: CashierTheme.accent(context),
                              ),
                            ),
                          ),
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
                            final all = tables.cast<Map<String, dynamic>>();
                            final filtered = _applyFilter(all);

                            if (filtered.isEmpty) {
                              return _EmptyFilterState(filter: _filter);
                            }

                            return TablesLayout(
                              tables: filtered,
                              viewMode: viewMode,
                              tick: _tick,
                              onOpen: _openTable,
                              onSession: _showSession,
                              onTableContextMenu: (table, details) => showTableContextMenu(
                                context: context,
                                ref: ref,
                                table: table,
                                globalPosition: details.globalPosition,
                                onOpenTable: _openTable,
                                onOpenSession: _showSession,
                                onChanged: _onSessionChanged,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  if (needsShift)
                    _ShiftRequiredOverlay(onOpenShift: _handleOpenShift),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return CashierShortcutsScope(
      adminEnabled: isAdmin,
      onHelp: () => showCashierShortcutsDialog(context, showAdmin: isAdmin),
      onCounterSale: _startCounterSale,
      onRefresh: _refresh,
      onSettings: () => showUiSettingsSheet(context),
      onFilter: (f) => setState(() => _filter = f),
      onTableSlot: _activateTableSlot,
      onAdmin: isAdmin ? () => context.go('/admin') : null,
      child: CashierThemeData.wrap(
        context,
        LayoutBuilder(
          builder: (context, constraints) {
            final bp = CashierBreakpoints.fromWidth(constraints.maxWidth);
            final drawerWidth = math.min(constraints.maxWidth * 0.88, 320.0);

            return Scaffold(
              key: _scaffoldKey,
              backgroundColor: CashierTheme.scaffoldBg(context),
              drawer: bp.showDrawer
                  ? Drawer(
                      width: drawerWidth,
                      child: buildSideRail(inDrawer: true),
                    )
                  : null,
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (bp.showPermanentRail) buildSideRail(inDrawer: false),
                  Expanded(child: buildMainColumn(bp)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShiftRequiredOverlay extends StatelessWidget {
  const _ShiftRequiredOverlay({required this.onOpenShift});

  final VoidCallback onOpenShift;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CashierTheme.scaffoldBg(context).withValues(alpha: 0.94),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 52, color: CashierTheme.textTertiary(context)),
                const SizedBox(height: 20),
                Text(
                  'Növbə açılmayıb',
                  style: CashierTheme.stationTitle(context, size: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Satışa başlamaq üçün əvvəlcə kassadakı nağdı daxil edib günün növbəsini açın.',
                  style: CashierTheme.caption(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onOpenShift,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Növbəni aç'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyFilterState extends StatelessWidget {
  const _EmptyFilterState({required this.filter});

  final CashierTableFilter filter;

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (filter) {
      CashierTableFilter.active => (
          Icons.hourglass_empty_outlined,
          'Aktiv sessiya yoxdur',
          'Hal-hazırda heç bir stansiya işləmir.',
        ),
      CashierTableFilter.empty => (
          Icons.event_available_outlined,
          'Boş stansiya yoxdur',
          'Bütün stansiyalar məşğuldur.',
        ),
      CashierTableFilter.all => (
          Icons.table_restaurant_outlined,
          'Stansiya tapılmadı',
          'Sistemdə stansiya qeydiyyatı yoxdur.',
        ),
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: CashierTheme.textTertiary(context)),
            const SizedBox(height: 16),
            Text(title, style: CashierTheme.stationTitle(context, size: 16), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subtitle, style: CashierTheme.caption(context), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
