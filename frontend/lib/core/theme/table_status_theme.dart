import 'package:flutter/material.dart';
import 'app_palette.dart';
import 'cashier_theme.dart';

/// Masa kartı — status rəngi hiss olunur, premium pastel.
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
    return _dark(context, effective, p);
  }

  static List<BoxShadow> _cardShadow(BuildContext context) => CashierTheme.cardShadow(context);

  static TableStatusStyle _light(BuildContext context, String status) {
    final shadow = _cardShadow(context);

    return switch (status) {
      'active' => TableStatusStyle(
          accent: CashierTheme.statusActive,
          cardFill: const Color(0xFFFFF6F6),
          cardBorder: const Color(0xFFE8BCBC),
          badgeFill: const Color(0xFFFCEAEA),
          badgeBorder: const Color(0xFFF5D0D0),
          timerZoneFill: const Color(0xFFFDF0F0),
          moneyColor: CashierTheme.lightTextPrimary,
          cardShadow: shadow,
        ),
      'paused' => TableStatusStyle(
          accent: CashierTheme.statusPaused,
          cardFill: const Color(0xFFFFFAF4),
          cardBorder: const Color(0xFFE8D4B0),
          badgeFill: const Color(0xFFFDF4E8),
          badgeBorder: const Color(0xFFF0E0C4),
          timerZoneFill: const Color(0xFFFAF2E6),
          moneyColor: CashierTheme.lightTextPrimary,
          cardShadow: shadow,
        ),
      'closed' => TableStatusStyle(
          accent: CashierTheme.statusClosed,
          cardFill: const Color(0xFFF6F7FA),
          cardBorder: const Color(0xFFD0D5E0),
          badgeFill: const Color(0xFFECEEF4),
          badgeBorder: const Color(0xFFD8DCE6),
          timerZoneFill: const Color(0xFFF0F2F6),
          cardShadow: shadow,
        ),
      _ => TableStatusStyle(
          accent: CashierTheme.statusEmpty,
          cardFill: const Color(0xFFF4FBF6),
          cardBorder: const Color(0xFFB8DFC6),
          badgeFill: const Color(0xFFE6F5EA),
          badgeBorder: const Color(0xFFC8E8D0),
          timerZoneFill: const Color(0xFFECF6EF),
          moneyColor: CashierTheme.lightTextPrimary,
          cardShadow: shadow,
        ),
    };
  }

  static TableStatusStyle _dark(BuildContext context, String status, AppPalette p) {
    final shadow = _cardShadow(context);
    return switch (status) {
      'active' => TableStatusStyle(
          accent: const Color(0xFFE87878),
          cardFill: Color.lerp(p.surfaceElevated, const Color(0xFFE87878), 0.10)!,
          cardBorder: const Color(0xFFE87878).withValues(alpha: 0.35),
          badgeFill: const Color(0xFFE87878).withValues(alpha: 0.14),
          badgeBorder: const Color(0xFFE87878).withValues(alpha: 0.28),
          timerZoneFill: const Color(0xFFE87878).withValues(alpha: 0.08),
          moneyColor: CashierTheme.darkTextPrimary,
          cardShadow: shadow,
        ),
      'paused' => TableStatusStyle(
          accent: const Color(0xFFE8A858),
          cardFill: Color.lerp(p.surfaceElevated, const Color(0xFFE8A858), 0.08)!,
          cardBorder: const Color(0xFFE8A858).withValues(alpha: 0.32),
          badgeFill: const Color(0xFFE8A858).withValues(alpha: 0.12),
          badgeBorder: const Color(0xFFE8A858).withValues(alpha: 0.24),
          timerZoneFill: const Color(0xFFE8A858).withValues(alpha: 0.07),
          moneyColor: CashierTheme.darkTextPrimary,
          cardShadow: shadow,
        ),
      'closed' => TableStatusStyle(
          accent: CashierTheme.statusClosed,
          cardFill: p.surface,
          cardBorder: CashierTheme.darkBorder,
          badgeFill: const Color(0xFF9CA3AF).withValues(alpha: 0.12),
          badgeBorder: const Color(0xFF9CA3AF).withValues(alpha: 0.22),
          timerZoneFill: p.surface,
          cardShadow: shadow,
        ),
      _ => TableStatusStyle(
          accent: const Color(0xFF6BCB7E),
          cardFill: Color.lerp(p.surfaceElevated, const Color(0xFF6BCB7E), 0.08)!,
          cardBorder: const Color(0xFF6BCB7E).withValues(alpha: 0.30),
          badgeFill: const Color(0xFF6BCB7E).withValues(alpha: 0.12),
          badgeBorder: const Color(0xFF6BCB7E).withValues(alpha: 0.22),
          timerZoneFill: const Color(0xFF6BCB7E).withValues(alpha: 0.06),
          moneyColor: CashierTheme.darkTextPrimary,
          cardShadow: shadow,
        ),
    };
  }

  static TableStatusStyle expiredOverlay(TableStatusStyle base, double t) {
    const pulse = CashierTheme.statusActive;
    return TableStatusStyle(
      accent: pulse,
      cardFill: Color.lerp(base.cardFill, const Color(0xFFFFF0F0), 0.35 * t)!,
      cardBorder: Color.lerp(base.cardBorder, pulse, 0.25 * t)!,
      badgeFill: Color.lerp(base.badgeFill, pulse, 0.15 * t)!,
      badgeBorder: Color.lerp(base.badgeBorder, pulse, 0.25 * t)!,
      timerZoneFill: Color.lerp(base.timerZoneFill, const Color(0xFFFDF0F0), 0.3 * t)!,
      moneyColor: base.moneyColor,
      borderWidth: 1,
      accentBarWidth: 4,
      cardShadow: [
        BoxShadow(
          color: pulse.withValues(alpha: 0.16 * t),
          blurRadius: 18,
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
