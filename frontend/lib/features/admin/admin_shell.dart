import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_state.dart';
import '../../core/settings/ui_settings_sheet.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import 'audit_screen.dart';
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
  int _index = 0;

  static const _destinations = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Statistika'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Sifarişlər'),
    (Icons.table_bar_outlined, Icons.table_bar, 'Masalar'),
    (Icons.inventory_2_outlined, Icons.inventory_2, 'Məhsullar'),
    (Icons.restaurant_menu_outlined, Icons.restaurant_menu, 'Paketlər'),
    (Icons.contacts_outlined, Icons.contacts, 'Müştərilər'),
    (Icons.warehouse_outlined, Icons.warehouse, 'Stok'),
    (Icons.people_outline, Icons.people, 'İstifadəçilər'),
    (Icons.tune_outlined, Icons.tune, 'Parametrlər'),
    (Icons.bar_chart_outlined, Icons.bar_chart, 'Hesabatlar'),
    (Icons.history_outlined, Icons.history, 'Audit'),
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
        10 => const AuditScreen(),
        _ => const SizedBox(),
      };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final user = ref.watch(authProvider).valueOrNull;

    final p = context.palette;

    return Scaffold(
      backgroundColor: p.bg,
      body: Row(
        children: [
          if (wide) _SideNav(index: _index, onSelect: (i) => setState(() => _index = i)),
          Expanded(
            child: Column(
              children: [
                _AdminTopBar(
                  title: _destinations[_index].$3,
                  userName: user?.username ?? '',
                  onSettings: () => showUiSettingsSheet(context),
                  onCashier: () => context.go('/cashier'),
                  onLogout: () => ref.read(authProvider.notifier).logout(),
                ),
                Expanded(child: _page(_index)),
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
                if (i == 3) _showMoreMenu(context);
                else setState(() => _index = i);
              },
              destinations: const [
                NavigationDestination(icon: Icon(Icons.table_bar_outlined), selectedIcon: Icon(Icons.table_bar), label: 'Masalar'),
                NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Məhsul'),
                NavigationDestination(icon: Icon(Icons.warehouse_outlined), selectedIcon: Icon(Icons.warehouse), label: 'Stok'),
                NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Digər'),
              ],
            ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.dashboard), title: const Text('Statistika'), onTap: () { Navigator.pop(ctx); setState(() => _index = 0); }),
            ListTile(leading: const Icon(Icons.receipt_long), title: const Text('Sifarişlər'), onTap: () { Navigator.pop(ctx); setState(() => _index = 1); }),
            ListTile(leading: const Icon(Icons.restaurant_menu), title: const Text('Paketlər'), onTap: () { Navigator.pop(ctx); setState(() => _index = 4); }),
            ListTile(leading: const Icon(Icons.contacts), title: const Text('Müştərilər'), onTap: () { Navigator.pop(ctx); setState(() => _index = 5); }),
            ListTile(leading: const Icon(Icons.people), title: const Text('İstifadəçilər'), onTap: () { Navigator.pop(ctx); setState(() => _index = 7); }),
            ListTile(leading: const Icon(Icons.tune), title: const Text('Parametrlər'), onTap: () { Navigator.pop(ctx); setState(() => _index = 8); }),
            ListTile(leading: const Icon(Icons.bar_chart), title: const Text('Hesabatlar'), onTap: () { Navigator.pop(ctx); setState(() => _index = 9); }),
            ListTile(leading: const Icon(Icons.history), title: const Text('Audit'), onTap: () { Navigator.pop(ctx); setState(() => _index = 10); }),
          ],
        ),
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(right: BorderSide(color: p.border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Image.asset('assets/icons/app_icon.png', width: 20, height: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Text('Admin', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
              children: List.generate(_AdminShellState._destinations.length, (i) {
                final d = _AdminShellState._destinations[i];
                final selected = index == i;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Material(
                    color: selected ? AppColors.primarySoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    child: InkWell(
                      onTap: () => onSelect(i),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
                        child: Row(
                          children: [
                            Icon(selected ? d.$2 : d.$1, size: 20, color: selected ? AppColors.primary : AppColors.textMuted),
                            const SizedBox(width: AppSpacing.md),
                            Text(
                              d.$3,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                color: selected ? AppColors.primary : AppColors.textSecondary,
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
        ],
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
  });

  final String title;
  final String userName;
  final VoidCallback onSettings;
  final VoidCallback onCashier;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            Text(userName, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: AppSpacing.lg),
            IconButton(
              onPressed: onSettings,
              icon: const Icon(Icons.tune_rounded, size: 22),
              tooltip: 'Tətbiq parametrləri',
            ),
            OutlinedButton.icon(
              onPressed: onCashier,
              icon: const Icon(Icons.point_of_sale_outlined, size: 18),
              label: const Text('Kassir'),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(onPressed: onLogout, icon: const Icon(Icons.logout, size: 20), tooltip: 'Çıxış'),
          ],
        ),
      ),
    );
  }
}
