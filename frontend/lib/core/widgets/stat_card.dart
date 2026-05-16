import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
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
    final p = context.palette;
    final accent = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: p.border),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null)
                Icon(icon, size: 18, color: accent.withValues(alpha: 0.8)),
              if (icon != null) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(label, style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (isMoney)
            MoneyText(amount: double.tryParse(value) ?? 0, size: MoneySize.medium, color: accent)
          else
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: accent),
            ),
        ],
      ),
    );
  }
}
