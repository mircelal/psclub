import 'package:flutter/material.dart';
import '../../../core/config/business_config_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/cashier_theme.dart';
import '../../../core/widgets/business_logo.dart';
import 'cashier_filter_bar.dart';
import 'cashier_stats_row.dart';

class CashierSideRail extends StatelessWidget {
  const CashierSideRail({
    super.key,
    required this.biz,
    required this.userName,
    required this.active,
    required this.empty,
    required this.total,
    required this.liveRevenue,
    required this.filter,
    required this.onFilterChanged,
    required this.onRefresh,
    required this.onCounterSale,
    required this.onSettings,
    required this.onLogout,
    this.onAdmin,
  });

  final BusinessConfig biz;
  final String userName;
  final int active;
  final int empty;
  final int total;
  final double liveRevenue;
  final CashierTableFilter filter;
  final ValueChanged<CashierTableFilter> onFilterChanged;
  final VoidCallback onRefresh;
  final VoidCallback onCounterSale;
  final VoidCallback onSettings;
  final VoidCallback onLogout;
  final VoidCallback? onAdmin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: CashierTheme.sideRailWidth,
      decoration: CashierTheme.sideRailDecoration(context),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
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
                                  biz.name,
                                  style: CashierTheme.stationTitle(context, size: 15),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text('Kassir paneli', style: CashierTheme.caption(context)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: _UserTile(name: userName),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Text('GÜNDƏLİK', style: CashierTheme.sectionTitle(context)),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: CashierStatsRow(
                        active: active,
                        empty: empty,
                        total: total,
                        liveRevenue: liveRevenue,
                        vertical: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: onCounterSale,
                          icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                          label: const Text('Birbaşa satış'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            alignment: Alignment.centerLeft,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: CashierFilterBar(
                        filter: filter,
                        onChanged: onFilterChanged,
                        unitLabel: biz.labels.unitPlural,
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _RailActions(
                onRefresh: onRefresh,
                onSettings: onSettings,
                onAdmin: onAdmin,
                onLogout: onLogout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CashierTheme.accentSubtle(context),
        borderRadius: BorderRadius.circular(CashierTheme.radiusCard),
        border: Border.all(color: CashierTheme.accent(context).withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: CashierTheme.accentSubtle(context),
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CashierTheme.accent(context),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: CashierTheme.stationTitle(context, size: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('Aktiv operator', style: CashierTheme.caption(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailActions extends StatelessWidget {
  const _RailActions({
    required this.onRefresh,
    required this.onSettings,
    required this.onLogout,
    this.onAdmin,
  });

  final VoidCallback onRefresh;
  final VoidCallback onSettings;
  final VoidCallback onLogout;
  final VoidCallback? onAdmin;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ActionButton(icon: Icons.sync_rounded, tooltip: 'Yenilə', onTap: onRefresh),
        _ActionButton(icon: Icons.settings_outlined, tooltip: 'Görünüş', onTap: onSettings),
        if (onAdmin != null) _ActionButton(icon: Icons.admin_panel_settings_outlined, tooltip: 'Admin', onTap: onAdmin!),
        const Spacer(),
        _ActionButton(icon: Icons.logout_rounded, tooltip: 'Çıxış', onTap: onLogout, danger: true),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
          hoverColor: CashierTheme.accentSubtle(context),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(
              icon,
              size: 20,
              color: danger ? const Color(0xFFC42B1C) : CashierTheme.textSecondary(context),
            ),
          ),
        ),
      ),
    );
  }
}
