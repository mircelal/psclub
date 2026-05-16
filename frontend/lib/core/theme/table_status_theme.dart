import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_palette.dart';
import 'cashier_theme.dart';

/// Masa kartı / siyahı sətri üçün status rəngləri (dark + light).
class TableStatusStyle {
  const TableStatusStyle({
    required this.accent,
    required this.cardFill,
    required this.cardBorder,
    required this.badgeFill,
    required this.badgeBorder,
    required this.timerZoneFill,
    this.moneyColor,
    this.cardShadow,
    this.borderWidth = 1,
    this.accentBarWidth = 4,
  });

  final Color accent;
  final Color cardFill;
  final Color cardBorder;
  final Color badgeFill;
  final Color badgeBorder;
  final Color timerZoneFill;
  final Color? moneyColor;
  final List<BoxShadow>? cardShadow;
  final double borderWidth;
  final double accentBarWidth;
}

abstract final class TableStatusTheme {
  static TableStatusStyle resolve(
    BuildContext context,
    String status, {
    bool hasSession = false,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final p = context.palette;
    final effective = hasSession && status == 'empty' ? 'active' : status;

    if (isLight) {
      return _light(context, effective);
    }
    return _dark(effective, p);
  }

  static TableStatusStyle _light(BuildContext context, String status) {
    final shadow = CashierTheme.cardShadow(context);

    return switch (status) {
      'active' => TableStatusStyle(
          accent: const Color(0xFFFF3B30),
          cardFill: CashierTheme.lightSurface,
          cardBorder: const Color(0xFFFF3B30),
          badgeFill: const Color(0xFFFFEBE9),
          badgeBorder: const Color(0xFFFFD4D1),
          timerZoneFill: const Color(0xFFF5F5F7),
          moneyColor: const Color(0xFF1D1D1F),
          borderWidth: 0.5,
          accentBarWidth: 3,
          cardShadow: shadow,
        ),
      'paused' => TableStatusStyle(
          accent: const Color(0xFFFF9500),
          cardFill: CashierTheme.lightSurface,
          cardBorder: const Color(0xFFFF9500),
          badgeFill: const Color(0xFFFFF4E5),
          badgeBorder: const Color(0xFFFFE4BF),
          timerZoneFill: const Color(0xFFF5F5F7),
          moneyColor: const Color(0xFF1D1D1F),
          borderWidth: 0.5,
          accentBarWidth: 3,
          cardShadow: shadow,
        ),
      'closed' => TableStatusStyle(
          accent: const Color(0xFF8E8E93),
          cardFill: CashierTheme.lightSurfaceSecondary,
          cardBorder: const Color(0xFFC7C7CC),
          badgeFill: const Color(0xFFE5E5EA),
          badgeBorder: const Color(0xFFD1D1D6),
          timerZoneFill: const Color(0xFFF2F2F7),
          borderWidth: 0.5,
          cardShadow: shadow,
        ),
      _ => TableStatusStyle(
          accent: const Color(0xFF34C759),
          cardFill: CashierTheme.lightSurface,
          cardBorder: const Color(0xFFD1D1D6),
          badgeFill: const Color(0xFFE8FAEE),
          badgeBorder: const Color(0xFFC6EFD4),
          timerZoneFill: const Color(0xFFF5F5F7),
          moneyColor: const Color(0xFF1D1D1F),
          borderWidth: 0.5,
          accentBarWidth: 3,
          cardShadow: shadow,
        ),
    };
  }

  static TableStatusStyle _dark(String status, AppPalette p) {
    return switch (status) {
      'active' => TableStatusStyle(
          accent: AppColors.tableActive,
          cardFill: Color.lerp(p.surfaceElevated, AppColors.tableActive, 0.12)!,
          cardBorder: AppColors.tableActive.withValues(alpha: 0.55),
          badgeFill: AppColors.tableActive.withValues(alpha: 0.16),
          badgeBorder: AppColors.tableActive.withValues(alpha: 0.38),
          timerZoneFill: AppColors.tableActive.withValues(alpha: 0.12),
          moneyColor: AppColors.accent,
          borderWidth: 1.5,
          accentBarWidth: 4,
          cardShadow: [
            BoxShadow(
              color: AppColors.tableActive.withValues(alpha: 0.15),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      'paused' => TableStatusStyle(
          accent: AppColors.tablePaused,
          cardFill: Color.lerp(p.surfaceElevated, AppColors.tablePaused, 0.10)!,
          cardBorder: AppColors.tablePaused.withValues(alpha: 0.50),
          badgeFill: AppColors.tablePaused.withValues(alpha: 0.14),
          badgeBorder: AppColors.tablePaused.withValues(alpha: 0.35),
          timerZoneFill: AppColors.tablePaused.withValues(alpha: 0.10),
          moneyColor: AppColors.accent,
          borderWidth: 1.5,
          accentBarWidth: 4,
        ),
      'closed' => TableStatusStyle(
          accent: AppColors.tableClosed,
          cardFill: p.surface,
          cardBorder: AppColors.tableClosed.withValues(alpha: 0.35),
          badgeFill: AppColors.tableClosed.withValues(alpha: 0.12),
          badgeBorder: AppColors.tableClosed.withValues(alpha: 0.28),
          timerZoneFill: p.surface,
          accentBarWidth: 4,
        ),
      _ => TableStatusStyle(
          accent: AppColors.tableEmpty,
          cardFill: p.surfaceElevated,
          cardBorder: AppColors.tableEmpty.withValues(alpha: 0.28),
          badgeFill: AppColors.tableEmpty.withValues(alpha: 0.10),
          badgeBorder: AppColors.tableEmpty.withValues(alpha: 0.22),
          timerZoneFill: p.surface,
          accentBarWidth: 4,
        ),
    };
  }

  static TableStatusStyle expiredOverlay(TableStatusStyle base, double t) {
    const pulse = Color(0xFFDC4A42);
    return TableStatusStyle(
      accent: pulse,
      cardFill: Color.lerp(base.cardFill, const Color(0xFFFFE8E6), 0.35 * t)!,
      cardBorder: Color.lerp(base.cardBorder, pulse, t)!,
      badgeFill: Color.lerp(base.badgeFill, pulse, 0.2 * t)!,
      badgeBorder: Color.lerp(base.badgeBorder, pulse, 0.45 * t)!,
      timerZoneFill: Color.lerp(base.timerZoneFill, pulse, 0.15 * t)!,
      moneyColor: base.moneyColor ?? pulse,
      borderWidth: 2.5,
      accentBarWidth: 5,
      cardShadow: [
        BoxShadow(
          color: pulse.withValues(alpha: 0.28 * t),
          blurRadius: 18,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
        ...(base.cardShadow ?? []),
      ],
    );
  }
}

extension TableStatusThemeContext on BuildContext {
  TableStatusStyle tableStatusStyle(String status, {bool hasSession = false}) {
    return TableStatusTheme.resolve(this, status, hasSession: hasSession);
  }
}
