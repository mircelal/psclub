import 'package:flutter/material.dart';
import '../../../core/config/business_config_provider.dart';
import '../../../core/layout/mobile_ui.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/theme/cashier_breakpoints.dart';
import '../../../core/theme/cashier_theme.dart';

const _topBarControlHeight = 40.0;
const _topBarControlHeightMobile = 48.0;

class CashierTopBar extends StatelessWidget {
  const CashierTopBar({
    super.key,
    required this.biz,
    required this.liveRevenue,
    required this.activeCount,
    required this.totalCount,
    required this.emptyCount,
    required this.onCounterSale,
    this.onShowShortcuts,
    this.onMenuTap,
    this.onRefresh,
    this.layout = CashierTopBarLayout.desktop,
  });

  final BusinessConfig biz;
  final double liveRevenue;
  final int activeCount;
  final int totalCount;
  final int emptyCount;
  final VoidCallback onCounterSale;
  final VoidCallback? onShowShortcuts;
  final VoidCallback? onMenuTap;
  final VoidCallback? onRefresh;
  final CashierTopBarLayout layout;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: CashierTheme.topBarDecoration(context),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          layout == CashierTopBarLayout.mobile ? AppSpacing.sm : AppSpacing.xl,
          layout == CashierTopBarLayout.mobile ? AppSpacing.sm : AppSpacing.md,
          layout == CashierTopBarLayout.mobile ? AppSpacing.sm : AppSpacing.xl,
          layout == CashierTopBarLayout.mobile ? AppSpacing.sm : AppSpacing.md,
        ),
        child: switch (layout) {
          CashierTopBarLayout.mobile => _buildMobile(context),
          CashierTopBarLayout.compact => _buildCompact(context),
          CashierTopBarLayout.desktop => _buildDesktop(context),
        },
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    final units = biz.labels.unitPlural.toLowerCase();
    final revenueStr = liveRevenue > 0 ? ' · ${liveRevenue.toStringAsFixed(2)} ₼' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (onMenuTap != null)
              IconButton(
                onPressed: onMenuTap,
                icon: const Icon(Icons.menu_rounded),
                tooltip: 'Menyu',
                iconSize: 26,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: kMinTouchTarget, minHeight: kMinTouchTarget),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kassir',
                    style: CashierTheme.stationTitle(context, size: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$activeCount aktiv · $emptyCount boş · $totalCount $units$revenueStr',
                    style: CashierTheme.caption(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const _LiveIndicator(compact: true),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: SizedBox(
                height: kMinTouchTarget,
                child: FilledButton.icon(
                  onPressed: onCounterSale,
                  icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                  label: const Text('Birbaşa satış'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (onRefresh != null)
              _iconAction(Icons.refresh_rounded, 'Yenilə', onRefresh!, mobile: true),
          ],
        ),
      ],
    );
  }

  Widget _buildCompact(BuildContext context) {
    final timeStr = TimeOfDay.now().format(context);
    return Row(
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
              Text('Canlı monitorinq', style: CashierTheme.stationTitle(context, size: 18)),
              Text(
                '$activeCount / $totalCount aktiv',
                style: CashierTheme.caption(context),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onCounterSale,
          icon: const Icon(Icons.shopping_bag_outlined, size: 18),
          label: const Text('Satış'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, _topBarControlHeight),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
        if (onShowShortcuts != null) ...[
          const SizedBox(width: AppSpacing.sm),
          _iconAction(Icons.keyboard_outlined, 'Qısayollar', onShowShortcuts!),
        ],
        if (liveRevenue > 0) ...[
          const SizedBox(width: AppSpacing.sm),
          _RevenueBadge(amount: liveRevenue, compact: true),
        ],
        const SizedBox(width: AppSpacing.sm),
        _InfoChip(icon: Icons.schedule_outlined, label: timeStr),
        const SizedBox(width: AppSpacing.sm),
        const _LiveIndicator(),
      ],
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final timeStr = TimeOfDay.now().format(context);
    final dateStr = _formatDate(DateTime.now());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Canlı monitorinq', style: CashierTheme.stationTitle(context, size: 20)),
              const SizedBox(height: 4),
              Text(
                '$activeCount / $totalCount aktiv · ${biz.labels.unitPlural.toLowerCase()}',
                style: CashierTheme.caption(context),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onCounterSale,
          icon: const Icon(Icons.shopping_bag_outlined, size: 18),
          label: const Text('Birbaşa satış'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, _topBarControlHeight),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
        if (onShowShortcuts != null) ...[
          const SizedBox(width: AppSpacing.sm),
          _iconAction(Icons.keyboard_outlined, 'Qısayollar (F1)', onShowShortcuts!),
        ],
        const SizedBox(width: AppSpacing.lg),
        if (liveRevenue > 0) ...[
          _RevenueBadge(amount: liveRevenue),
          const SizedBox(width: AppSpacing.lg),
        ],
        _InfoChip(icon: Icons.calendar_today_outlined, label: dateStr),
        const SizedBox(width: AppSpacing.sm),
        _InfoChip(icon: Icons.schedule_outlined, label: timeStr),
        const SizedBox(width: AppSpacing.md),
        const _LiveIndicator(),
      ],
    );
  }

  Widget _iconAction(IconData icon, String tooltip, VoidCallback onTap, {bool mobile = false}) {
    final size = mobile ? _topBarControlHeightMobile : _topBarControlHeight;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: size,
        width: size,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
          child: Icon(icon, size: mobile ? 22 : 20),
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
  const _RevenueBadge({required this.amount, this.compact = false});

  final double amount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _topBarControlHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: BrandColors.brightBlue.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
          border: Border.all(color: BrandColors.brightBlue.withValues(alpha: 0.28)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.trending_up_rounded, color: BrandColors.brightBlue, size: compact ? 16 : 18),
              const SizedBox(width: 6),
              Text(
                compact ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: compact ? 13 : 15,
                  fontWeight: FontWeight.w600,
                  color: CashierTheme.textPrimary(context),
                  fontFeatures: const [FontFeature.tabularFigures()],
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '₼',
                style: TextStyle(
                  fontSize: compact ? 13 : 16,
                  fontWeight: FontWeight.w600,
                  color: BrandColors.brightBlue,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
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
    return SizedBox(
      height: _topBarControlHeight,
      child: DecoratedBox(
        decoration: CashierTheme.elevatedCardDecoration(
          context,
          fill: CashierTheme.surfaceSecondary(context),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
        ),
      ),
    );
  }
}

class _LiveIndicator extends StatelessWidget {
  const _LiveIndicator({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: BrandColors.brightBlue,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: BrandColors.brightBlue.withValues(alpha: 0.45),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        if (!compact) ...[
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
      ],
    );
  }
}
