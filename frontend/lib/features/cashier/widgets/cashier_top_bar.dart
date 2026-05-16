import 'package:flutter/material.dart';
import '../../../core/config/business_config_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/cashier_theme.dart';

class CashierTopBar extends StatelessWidget {
  const CashierTopBar({
    super.key,
    required this.biz,
    required this.liveRevenue,
    required this.activeCount,
    required this.totalCount,
  });

  final BusinessConfig biz;
  final double liveRevenue;
  final int activeCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final timeStr = TimeOfDay.now().format(context);
    final dateStr = _formatDate(DateTime.now());

    return Container(
      decoration: CashierTheme.topBarDecoration(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Canlı monitorinq',
                    style: CashierTheme.stationTitle(context, size: 20),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$activeCount / $totalCount aktiv · ${biz.labels.unitPlural.toLowerCase()}',
                    style: CashierTheme.caption(context),
                  ),
                ],
              ),
            ),
            if (liveRevenue > 0) ...[
              _RevenueBadge(amount: liveRevenue, currency: biz.currency),
              const SizedBox(width: AppSpacing.lg),
            ],
            _InfoChip(icon: Icons.calendar_today_outlined, label: dateStr),
            const SizedBox(width: AppSpacing.sm),
            _InfoChip(icon: Icons.schedule_outlined, label: timeStr),
            const SizedBox(width: AppSpacing.md),
            _LiveIndicator(),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Yan', 'Fev', 'Mar', 'Apr', 'May', 'İyn', 'İyl', 'Avq', 'Sen', 'Okt', 'Noy', 'Dek'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

class _RevenueBadge extends StatelessWidget {
  const _RevenueBadge({required this.amount, required this.currency});

  final double amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: CashierTheme.statusEmpty.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(CashierTheme.radiusCard),
        border: Border.all(color: CashierTheme.statusEmpty.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up_rounded, color: CashierTheme.statusEmpty, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Açıq gəlir', style: CashierTheme.caption(context)),
              Text(
                '${amount.toStringAsFixed(2)} $currency',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: CashierTheme.textPrimary(context),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: CashierTheme.elevatedCardDecoration(
        context,
        fill: CashierTheme.surfaceSecondary(context),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: CashierTheme.textSecondary(context)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: CashierTheme.textPrimary(context),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: CashierTheme.statusEmpty,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: CashierTheme.statusEmpty.withValues(alpha: 0.4),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Canlı',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: CashierTheme.textSecondary(context),
          ),
        ),
      ],
    );
  }
}
