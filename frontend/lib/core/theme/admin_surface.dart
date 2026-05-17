import 'package:flutter/material.dart';
import 'brand_colors.dart';
import 'cashier_theme.dart';

/// Admin panel kartları — dark/light üçün oxunaqlı fon və mətn.
class AdminSurface {
  AdminSurface._({
    required this.fill,
    required this.border,
    required this.label,
    required this.body,
    required this.muted,
  });

  final Color fill;
  final Color border;
  final Color label;
  final Color body;
  final Color muted;

  static AdminSurface periodCard(BuildContext context, Color accent) {
    final isLight = CashierTheme.isLight(context);
    return AdminSurface._(
      fill: accent.withValues(alpha: isLight ? 0.08 : 0.18),
      border: accent.withValues(alpha: isLight ? 0.28 : 0.45),
      label: accent,
      body: isLight ? BrandColors.navy : DarkNeutral.textHigh,
      muted: isLight ? BrandColors.textMutedLight : DarkNeutral.textMedium,
    );
  }

  static List<Color> dashboardAccents(BuildContext context) {
    final isLight = CashierTheme.isLight(context);
    if (isLight) {
      return [
        BrandColors.brightBlue,
        BrandColors.navy,
        const Color(0xFF1B8F5A),
        const Color(0xFF6B4FA8),
      ];
    }
    return [
      const Color(0xFF8AB4F8),
      const Color(0xFFAECBFA),
      const Color(0xFF81C995),
      const Color(0xFFCE93D8),
    ];
  }
}
