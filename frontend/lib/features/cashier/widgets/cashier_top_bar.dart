import 'package:flutter/material.dart';
import '../../../core/config/business_config_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/cashier_theme.dart';
import '../../../core/widgets/business_logo.dart';

class CashierTopBar extends StatelessWidget {
  const CashierTopBar({
    super.key,
    required this.biz,
    required this.userName,
    required this.liveRevenue,
    required this.onRefresh,
    required this.onSettings,
    required this.onLogout,
    this.onAdmin,
  });

  final BusinessConfig biz;
  final String userName;
  final double liveRevenue;
  final VoidCallback onRefresh;
  final VoidCallback onSettings;
  final VoidCallback onLogout;
  final VoidCallback? onAdmin;

  @override
  Widget build(BuildContext context) {
    final isLight = CashierTheme.isLight(context);
    final timeStr = TimeOfDay.now().format(context);

    return Container(
      decoration: BoxDecoration(
        color: CashierTheme.surface(context).withValues(alpha: isLight ? 0.82 : 0.92),
        border: Border(bottom: BorderSide(color: isLight ? const Color(0x14000000) : Colors.white10)),
        boxShadow: CashierTheme.topBarShadow(context),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
          child: Row(
            children: [
              const BusinessLogo(size: 32),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(biz.name, style: CashierTheme.stationTitle(context, size: 18)),
                    const SizedBox(height: 2),
                    Text(
                      'Salam, $userName',
                      style: CashierTheme.caption(context),
                    ),
                  ],
                ),
              ),
              if (liveRevenue > 0) ...[
                _RevenueChip(amount: liveRevenue, currency: biz.currency),
                const SizedBox(width: AppSpacing.md),
              ],
              _IconCapsule(icon: Icons.schedule_rounded, label: timeStr),
              const SizedBox(width: AppSpacing.xs),
              _IconCapsule(icon: Icons.tune_rounded, onTap: onSettings, tooltip: 'Görünüş'),
              _IconCapsule(icon: Icons.refresh_rounded, onTap: onRefresh, tooltip: 'Yenilə'),
              if (onAdmin != null) ...[
                const SizedBox(width: AppSpacing.xs),
                _IconCapsule(icon: Icons.shield_outlined, label: 'Admin', onTap: onAdmin!),
              ],
              const SizedBox(width: AppSpacing.xs),
              _IconCapsule(icon: Icons.power_settings_new_rounded, onTap: onLogout, tooltip: 'Çıxış', danger: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _RevenueChip extends StatelessWidget {
  const _RevenueChip({required this.amount, required this.currency});

  final double amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF34C759), Color(0xFF30B350)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(CashierTheme.radiusPill),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF34C759).withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.trending_up_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            '${amount.toStringAsFixed(2)} $currency',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconCapsule extends StatelessWidget {
  const _IconCapsule({
    required this.icon,
    this.label,
    this.onTap,
    this.tooltip,
    this.danger = false,
  });

  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: CashierTheme.surfaceSecondary(context),
      borderRadius: BorderRadius.circular(CashierTheme.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CashierTheme.radiusPill),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: label != null ? 14 : 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: danger ? const Color(0xFFFF3B30) : CashierTheme.textSecondary(context),
              ),
              if (label != null) ...[
                const SizedBox(width: 6),
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: CashierTheme.textPrimary(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: child);
    }
    return child;
  }
}
