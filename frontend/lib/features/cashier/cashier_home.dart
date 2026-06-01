import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_state.dart';
import '../../core/config/business_config_provider.dart';
import '../../core/layout/mobile_ui.dart';
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
import 'widgets/table_live_state.dart';
import 'widgets/tables_layout.dart';
import 'tables_provider.dart';
import 'shift_provider.dart';
import 'shift_dialogs.dart';
import 'shift_guard.dart';

class CashierHome extends ConsumerStatefulWidget {
  const CashierHome({super.key});

  @override
  ConsumerState<CashierHome> createState() => _CashierHomeState();
}

class _CashierHomeState extends ConsumerState<CashierHome> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _pollTimer;
  Timer? _tickTimer;
  Timer? _configPollTimer;
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
      ref.read(tablesProvider.notifier).refresh();
      refreshCurrentShift(ref);
    });
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _tick++);
    });
    _configPollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.invalidate(productsProvider);
      ref.invalidate(businessConfigProvider);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    _configPollTimer?.cancel();
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
    ref.read(tablesProvider.notifier).refresh();
    refreshCurrentShift(ref);
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
      showSessionPanel(
        context,
        ref,
        session['id'] as int,
        _onSessionChanged,
        lockUntilSettled: true,
      );
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
    ref.read(tablesProvider.notifier).refresh();
    refreshCurrentShift(ref);
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
    final opened = await showOpenShiftDialog(context, ref);
    if (opened) refreshCurrentShift(ref);
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
    final biz = ref.read(businessConfigProvider).valueOrNull ?? BusinessConfig.fallback;
    var sum = 0.0;
    for (final t in list) {
      if (t['session_id'] == null) continue;
      sum += tableLiveBillTotal(
        t,
        billingMode: biz.chargeBillingMode,
        timeBillingEnabled: biz.timeBillingEnabled,
        minBillingMinutes: biz.minBillingMinutes,
        billingIncrementMinutes: biz.billingIncrementMinutes,
        billingGraceMinutes: biz.billingGraceMinutes,
      );
    }
    return sum;
  }

  Widget _buildTablesArea({
    required List<dynamic>? tablesList,
    required AsyncValue<List<dynamic>> tablesAsync,
    required TableViewMode viewMode,
  }) {
    if (tablesList == null) {
      return tablesAsync.when(
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
            onPressed: () => ref.read(tablesProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            label: const Text('Yenidən cəhd et'),
          ),
        ),
        data: (_) => const SizedBox.shrink(),
      );
    }
    return _buildTablesGrid(
      tablesList.cast<Map<String, dynamic>>(),
      viewMode: viewMode,
    );
  }

  Widget _buildTablesGrid(
    List<Map<String, dynamic>> all, {
    required TableViewMode viewMode,
  }) {
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
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).valueOrNull;
    final shiftAsync = ref.watch(currentShiftProvider);
    final currentShift = shiftAsync.valueOrNull;
    final tablesAsync = ref.watch(tablesProvider);
    final tablesList = tablesAsync.valueOrNull;
    final uiSettings = ref.watch(appSettingsProvider).valueOrNull;
    final width = MediaQuery.sizeOf(context).width;
    final bp = CashierBreakpoints.fromWidth(width);
    final viewMode = effectiveTableViewMode(
      uiSettings?.tableViewMode ?? TableViewMode.grid,
      width,
      isMobile: bp.isMobile,
    );
    final biz = ref.watch(businessConfigProvider).valueOrNull ?? BusinessConfig.fallback;

    final list = tablesList?.cast<Map<String, dynamic>>() ?? [];
    final active = list.where((t) => t['session_id'] != null).length;
    final empty = list.where((t) => t['session_id'] == null).length;
    final revenue = _liveRevenue(list);

    final isAdmin = user?.isAdmin == true;
    final blockSales = !isAdmin &&
        shiftAsync.when(
          data: (shift) => shift == null,
          loading: () => true,
          error: (_, __) => true,
        );

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
          if (blockSales) {
            _handleOpenShift();
          } else {
            _startCounterSale();
          }
          if (inDrawer) _scaffoldKey.currentState?.closeDrawer();
        },
        onRefresh: _refresh,
        onSettings: () async {
          if (inDrawer) _scaffoldKey.currentState?.closeDrawer();
          await showUiSettingsSheet(context);
          ref.invalidate(businessConfigProvider);
          _refresh();
        },
        onShowShortcuts: bp.supportsKeyboardShortcuts
            ? () {
                showCashierShortcutsDialog(context, showAdmin: isAdmin);
                if (inDrawer) _scaffoldKey.currentState?.closeDrawer();
              }
            : null,
        showKeyboardShortcuts: bp.supportsKeyboardShortcuts,
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

      return cashierSafeArea(
        child: ColoredBox(
        color: CashierTheme.surfaceMain(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CashierTopBar(
              biz: biz,
              liveRevenue: revenue,
              activeCount: active,
              emptyCount: empty,
              totalCount: list.length,
              onCounterSale: blockSales ? _handleOpenShift : _startCounterSale,
              onShowShortcuts: bp.supportsKeyboardShortcuts
                  ? () => showCashierShortcutsDialog(context, showAdmin: isAdmin)
                  : null,
              onRefresh: _refresh,
              onMenuTap: bp.showDrawer ? () => _scaffoldKey.currentState?.openDrawer() : null,
              layout: bp.topBarLayout,
            ),
            if (bp.showDrawer) ...[
              if (!bp.isMobile)
                Padding(
                  padding: EdgeInsets.fromLTRB(padH, 8, padH, 0),
                  child: CashierStatsRow(
                    active: active,
                    empty: empty,
                    total: list.length,
                    liveRevenue: revenue,
                    scrollable: false,
                  ),
                ),
              CashierFilterBar(
                filter: _filter,
                onChanged: (f) => setState(() => _filter = f),
                unitLabel: biz.labels.unitPlural,
                compact: bp.useCompactCashierChrome,
                horizontalScroll: bp.isTablet,
              ),
            ],
            if (bp.isDesktop && !blockSales) CounterSaleToolbar(onNewSale: _startCounterSale),
            Expanded(
              child: blockSales
                  ? _ShiftBlockedWorkspace(onOpenShift: _handleOpenShift)
                  : Padding(
                      padding: EdgeInsets.fromLTRB(
                        bp.useFlatTableCanvas ? 0 : padH,
                        padT,
                        bp.useFlatTableCanvas ? 0 : padH,
                        bp.useFlatTableCanvas ? 0 : padH,
                      ),
                      child: bp.useFlatTableCanvas
                          ? _buildTablesArea(
                              tablesList: tablesList,
                              tablesAsync: tablesAsync,
                              viewMode: viewMode,
                            )
                          : DecoratedBox(
                              decoration: CashierTheme.contentPanelDecoration(context),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(CashierTheme.radiusCard + 2),
                                child: _buildTablesArea(
                                  tablesList: tablesList,
                                  tablesAsync: tablesAsync,
                                  viewMode: viewMode,
                                ),
                              ),
                            ),
                    ),
            ),
          ],
        ),
      ),
      );
    }

    return CashierShortcutsScope(
      enabled: bp.supportsKeyboardShortcuts,
      adminEnabled: isAdmin,
      onHelp: () => showCashierShortcutsDialog(context, showAdmin: isAdmin),
      onCounterSale: _startCounterSale,
      onRefresh: _refresh,
      onSettings: () async {
        await showUiSettingsSheet(context);
        ref.invalidate(businessConfigProvider);
        _refresh();
      },
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

/// Növbə açılmayınca masa paneli əvəzinə — arxada heç nə görünmür, yanıb-sönmə yoxdur.
class _ShiftBlockedWorkspace extends StatelessWidget {
  const _ShiftBlockedWorkspace({required this.onOpenShift});

  final Future<void> Function() onOpenShift;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: CashierTheme.surfaceMain(context),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: CashierTheme.surfaceRaised(context),
                    borderRadius: BorderRadius.circular(CashierTheme.radiusCard),
                    border: Border.all(color: CashierTheme.border(context)),
                  ),
                  child: Icon(Icons.lock_outline, size: 48, color: CashierTheme.accent(context)),
                ),
                const SizedBox(height: 24),
                Text(
                  'Əvvəlcə növbəni açın',
                  style: CashierTheme.stationTitle(context, size: 20),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Satış və stansiyalar yalnız növbə açılandan sonra aktiv olur. '
                  'Sol paneldən kassadakı nağdı daxil edib növbəni açın.',
                  style: CashierTheme.caption(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => onOpenShift(),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Növbəni aç'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
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
