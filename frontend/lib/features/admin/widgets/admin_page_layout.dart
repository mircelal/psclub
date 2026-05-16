import 'package:flutter/material.dart';
import '../../../core/theme/admin_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/cashier_theme.dart';

/// Admin shell artıq yuxarıda başlıq göstərir — burada təkrar başlıq yoxdur.
class AdminPageLayout extends StatelessWidget {
  const AdminPageLayout({
    super.key,
    this.title,
    this.subtitle,
    this.action,
    required this.child,
    this.showInlineHeader = false,
  });

  final String? title;
  final String? subtitle;
  final Widget? action;
  final Widget child;
  final bool showInlineHeader;

  @override
  Widget build(BuildContext context) {
    if (showInlineHeader && title != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xl, AppSpacing.xxl, AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title!, style: CashierTheme.stationTitle(context, size: 22)),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(subtitle!, style: CashierTheme.caption(context)),
                      ],
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
          Expanded(child: child),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (subtitle != null || action != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (subtitle != null)
                  Expanded(
                    child: Text(subtitle!, style: CashierTheme.caption(context)),
                  ),
                if (action != null) ...[
                  if (subtitle != null) const SizedBox(width: AppSpacing.md),
                  action!,
                ],
              ],
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}

class AdminListTile extends StatelessWidget {
  const AdminListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.onTap,
    this.onDelete,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: CashierTheme.elevatedCardDecoration(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CashierTheme.radiusCard),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: AppSpacing.md)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: CashierTheme.stationTitle(context, size: 14)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: CashierTheme.caption(context)),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
                if (onDelete != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline, size: 20, color: AdminTheme.danger(context)),
                    tooltip: 'Sil',
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
