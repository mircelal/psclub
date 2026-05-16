import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/brand_colors.dart';
import '../theme/cashier_theme.dart';
import 'money_text.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.isMoney = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final bool isMoney;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? BrandColors.brightBlue;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: CashierTheme.elevatedCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 16, color: accent),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Text(label, style: CashierTheme.caption(context)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (isMoney)
            MoneyText(amount: double.tryParse(value) ?? 0, size: MoneySize.medium, color: accent)
          else
            Text(
              value,
              style: CashierTheme.metricValue(context, large: true).copyWith(color: accent),
            ),
        ],
      ),
    );
  }
}
