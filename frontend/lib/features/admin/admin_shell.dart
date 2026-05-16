import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_state.dart';
import '../../core/config/business_config_provider.dart';
import '../../core/settings/ui_settings_sheet.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/theme/cashier_theme.dart';
import '../../core/theme/cashier_theme_data.dart';
import '../../core/widgets/business_logo.dart';
import 'audit_screen.dart';
import 'shifts_screen.dart';
import 'dashboard_screen.dart';
import 'orders_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'customers_screen.dart';
import 'session_sets_screen.dart';
import 'settings_screen.dart';
import 'stock_screen.dart';
import 'tables_screen.dart';
import 'users_screen.dart';

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;

  static const _destinations = [
    (Icons.dashboard_outlined, Icons.dashboard_rounded, 'Statistika'),
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Sifarişlər'),
    (Icons.table_bar_outlined, Icons.table_bar_rounded, 'Masalar'),
    (Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Məhsullar'),
    (Icons.restaurant_menu_outlined, Icons.restaurant_menu_rounded, 'Paketlər'),
    (Icons.contacts_outlined, Icons.contacts_rounded, 'Müştərilər'),
    (Icons.warehouse_outlined, Icons.warehouse_rounded, 'Stok'),
    (Icons.people_outline, Icons.people_rounded, 'İstifadəçilər'),
    (Icons.tune_outlined, Icons.tune_rounded, 'Parametrlər'),
    (Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Hesabatlar'),
    (Icons.point_of_sale_outlined, Icons.point_of_sale_rounded, 'Növbə / Kassa'),
    (Icons.history_outlined, Icons.history_rounded, 'Jurnal'),
  ];

  Widget _page(int i) => switch (i) {
        0 => const DashboardScreen(),
        1 => const OrdersScreen(),
        2 => const TablesScreen(),
        3 => const ProductsScreen(),
        4 => const SessionSetsScreen(),
        5 => const CustomersScreen(),
        6 => const StockScreen(),
        7 => const UsersScreen(),
        8 => const SettingsScreen(),
        9 => const ReportsScreen(),
        10 => const ShiftsScreen(),
        11 => const AuditScreen(),
        _ => const SizedBox(),
      };

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final mobile = width < 600;
    final user = ref.watch(authProvider).valueOrNull;

    void selectPage(int i) {
      setState(() => _index = i);
      _scaffoldKey.currentState?.closeDrawer();
    }

    return CashierThemeData.wrap(
      context,
      Scaffold(
        key: _scaffoldKey,
        backgroundColor: CashierTheme.scaffoldBg(context),
        drawer: !wide
            ? Drawer(
                width: math.min(width * 0.88, 300.0),
                backgroundColor: CashierTheme.surfaceSidebar(context),
                child: _SideNav(
                  index: _index,
                  onSelect: selectPage,
                  onCashier: () => context.go('/cashier'),
                ),
              )
            : null,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              _SideNav(
                index: _index,
                onSelect: (i) => setState(() => _index = i),
                onCashier: () => context.go('/cashier'),
              ),
            Expanded(
              child: Column(
                children: [
                  _AdminTopBar(
                    title: _destinations[_index].$3,
                    userName: user?.fullName ?? user?.username ?? '',
                    compact: mobile,
                    onMenuTap: !wide ? () => _scaffoldKey.currentState?.openDrawer() : null,
                    onSettings: () => showUiSettingsSheet(context),
                    onCashier: () => context.go('/cashier'),
                    onLogout: () => ref.read(authProvider.notifier).logout(),
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: CashierTheme.surfaceMain(context),
                      child: _page(_index),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _index.clamp(0, 3),
                onDestinationSelected: (i) {
                  if (i == 3) {
                    _showMoreMenu(context);
                  } else {
                    setState(() => _index = i);
                  }
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard_rounded),
                    label: 'Stat',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long_rounded),
                    label: 'Sifariş',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.contacts_outlined),
                    selectedIcon: Icon(Icons.contacts_rounded),
                    label: 'Müştəri',
                  ),
                  NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: 'Digər'),
                ],
              ),
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    final items = [
      (0, Icons.dashboard_rounded, 'Statistika'),
      (1, Icons.receipt_long_rounded, 'Sifarişlər'),
      (2, Icons.table_bar_rounded, 'Masalar'),
      (3, Icons.inventory_2_rounded, 'Məhsullar'),
      (4, Icons.restaurant_menu_rounded, 'Paketlər'),
      (5, Icons.contacts_rounded, 'Müştərilər'),
      (6, Icons.warehouse_rounded, 'Stok'),
      (7, Icons.people_rounded, 'İstifadəçilər'),
      (8, Icons.tune_rounded, 'Parametrlər'),
      (9, Icons.bar_chart_rounded, 'Hesabatlar'),
      (10, Icons.history_rounded, 'Əməliyyat jurnalı'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: CashierTheme.surfaceRaised(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text('Menyu', style: CashierTheme.stationTitle(ctx, size: 16)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
            ...items.map(
              (e) => ListTile(
                leading: Icon(e.$2, color: _index == e.$1 ? BrandColors.brightBlue : CashierTheme.textSecondary(ctx)),
                title: Text(
                  e.$3,
                  style: TextStyle(
                    fontWeight: _index == e.$1 ? FontWeight.w600 : FontWeight.w500,
                    color: _index == e.$1 ? BrandColors.brightBlue : CashierTheme.textPrimary(ctx),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _index = e.$1);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SideNav extends ConsumerWidget {
  const _SideNav({
    required this.index,
    required this.onSelect,
    required this.onCashier,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onCashier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final biz = ref.watch(businessConfigProvider).valueOrNull;

    return Container(
      width: AdminTheme.sideNavWidth,
      decoration: CashierTheme.sideRailDecoration(context),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
              child: Row(
                children: [
                  const BusinessLogo(size: 36),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          biz?.name ?? 'PS Club',
                          style: CashierTheme.stationTitle(context, size: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text('Admin paneli', style: CashierTheme.caption(context)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text('MENYU', style: CashierTheme.sectionTitle(context)),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                children: List.generate(_AdminShellState._destinations.length, (i) {
                  final d = _AdminShellState._destinations[i];
                  final selected = index == i;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Material(
                      color: selected ? CashierTheme.accentSubtle(context) : Colors.transparent,
                      borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
                      child: InkWell(
                        onTap: () => onSelect(i),
                        borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
                        hoverColor: CashierTheme.accentSubtle(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: selected
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
                                  border: Border.all(
                                    color: CashierTheme.accent(context).withValues(alpha: 0.35),
                                  ),
                                )
                              : null,
                          child: Row(
                            children: [
                              Icon(
                                selected ? d.$2 : d.$1,
                                size: 20,
                                color: selected ? BrandColors.brightBlue : CashierTheme.textSecondary(context),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  d.$3,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                    color: selected
                                        ? CashierTheme.textPrimary(context)
                                        : CashierTheme.textSecondary(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: onCashier,
                  icon: const Icon(Icons.point_of_sale_outlined, size: 20),
                  label: const Text('Kassir paneli'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({
    required this.title,
    required this.userName,
    required this.onSettings,
    required this.onCashier,
    required this.onLogout,
    this.onMenuTap,
    this.compact = false,
  });

  final String title;
  final String userName;
  final VoidCallback onSettings;
  final VoidCallback onCashier;
  final VoidCallback onLogout;
  final VoidCallback? onMenuTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: CashierTheme.topBarDecoration(context),
      padding: EdgeInsets.fromLTRB(
        compact ? AppSpacing.md : AppSpacing.xl,
        AppSpacing.md,
        compact ? AppSpacing.md : AppSpacing.xl,
        AppSpacing.md,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (onMenuTap != null) ...[
              IconButton(
                onPressed: onMenuTap,
                icon: const Icon(Icons.menu_rounded),
                tooltip: 'Menyu',
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: CashierTheme.stationTitle(context, size: compact ? 17 : 20)),
                  if (!compact && userName.isNotEmpty)
                    Text(userName, style: CashierTheme.caption(context)),
                ],
              ),
            ),
            IconButton(
              onPressed: onSettings,
              icon: const Icon(Icons.tune_rounded, size: 22),
              tooltip: 'Görünüş',
              color: CashierTheme.textSecondary(context),
            ),
            if (compact)
              IconButton(
                onPressed: onCashier,
                icon: const Icon(Icons.point_of_sale_outlined, size: 22),
                tooltip: 'Kassir paneli',
                color: BrandColors.brightBlue,
              )
            else
              FilledButton.tonalIcon(
                onPressed: onCashier,
                icon: const Icon(Icons.point_of_sale_outlined, size: 20),
                label: const Text('Kassir paneli'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              onPressed: onLogout,
              icon: Icon(Icons.logout_rounded, size: 20, color: CashierTheme.textSecondary(context)),
              tooltip: 'Çıxış',
            ),
          ],
        ),
      ),
    );
  }
}
