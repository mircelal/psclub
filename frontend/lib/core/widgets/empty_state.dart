import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/cashier_theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: CashierTheme.surfaceSecondary(context),
                shape: BoxShape.circle,
                border: Border.all(color: CashierTheme.border(context)),
              ),
              child: Icon(icon, size: 40, color: CashierTheme.textTertiary(context)),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: CashierTheme.textPrimary(context),
                  ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: CashierTheme.textSecondary(context),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
