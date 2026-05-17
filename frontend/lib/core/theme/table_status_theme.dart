import 'package:flutter/material.dart';
import 'app_palette.dart';
import 'brand_colors.dart';
import 'cashier_theme.dart';

/// Masa kartı — status rəngi (light pastel / dark neytral + oxunaqlı qırmızı).
class TableStatusStyle {
  const TableStatusStyle({
    required this.accent,
    required this.cardFill,
    required this.cardBorder,
    required this.badgeFill,
    required this.badgeBorder,
    required this.timerZoneFill,
    this.moneyColor,
    this.badgeTextColor,
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
  /// Badge mətni — tünd qırmızı fonda accent çox tünd olanda.
  final Color? badgeTextColor;
  final List<BoxShadow>? cardShadow;
  final double borderWidth;
  final double accentBarWidth;

  Color badgeLabelColor() => badgeTextColor ?? accent;
}

/// Sessiya status rəngləri — dark/light ayrıca.
abstract final class SessionStatusColors {
  // Light
  static const activeAccentLight = Color(0xFFC62828);
  static const activeFillLight = Color(0xFFFFF6F6);
  static const expiredAccentLight = Color(0xFFB71C1C);
  static const expiredFillLight = Color(0xFFFFEBEE);

  // Dark — aktiv: oxunaqlı coral; bitmiş: daha tünd qırmızı fon
  static const activeAccentDark = Color(0xFFF28B82);
  static const activeFillDark = Color(0xFF2A2224);
  static const activeBorderDark = Color(0xFF5C3D42);
  static const expiredAccentDark = Color(0xFF8B2E2E);
  static const expiredFillDark = Color(0xFF1F1618);
  static const expiredBorderDark = Color(0xFF6B3035);
  static const expiredLabelDark = Color(0xFFEF9A9A);
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
          accent: SessionStatusColors.activeAccentLight,
          cardFill: SessionStatusColors.activeFillLight,
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
          accent: BrandColors.brightBlue,
          cardFill: const Color(0xFFF0F6FF),
          cardBorder: const Color(0xFFB8D4F5),
          badgeFill: const Color(0xFFE3EEFC),
          badgeBorder: const Color(0xFFC5D9F5),
          timerZoneFill: const Color(0xFFE8F2FD),
          moneyColor: BrandColors.navy,
          cardShadow: shadow,
        ),
    };
  }

  static TableStatusStyle _dark(BuildContext context, String status, AppPalette p) {
    final shadow = _cardShadow(context);
    return switch (status) {
      'active' => TableStatusStyle(
          accent: SessionStatusColors.activeAccentDark,
          cardFill: SessionStatusColors.activeFillDark,
          cardBorder: SessionStatusColors.activeBorderDark,
          badgeFill: const Color(0xFF3A2829),
          badgeBorder: const Color(0xFF6D4548),
          timerZoneFill: const Color(0xFF322628),
          moneyColor: DarkNeutral.textHigh,
          badgeTextColor: SessionStatusColors.activeAccentDark,
          cardShadow: shadow,
        ),
      'paused' => TableStatusStyle(
          accent: const Color(0xFFE8B86D),
          cardFill: const Color(0xFF2A2722),
          cardBorder: const Color(0xFF5C4F3A),
          badgeFill: const Color(0xFF3A3428),
          badgeBorder: const Color(0xFF6D5F42),
          timerZoneFill: const Color(0xFF322E26),
          moneyColor: DarkNeutral.textHigh,
          badgeTextColor: const Color(0xFFE8B86D),
          cardShadow: shadow,
        ),
      'closed' => TableStatusStyle(
          accent: const Color(0xFF9AA0A6),
          cardFill: p.surface,
          cardBorder: CashierTheme.darkBorder,
          badgeFill: const Color(0xFF2C2C2C),
          badgeBorder: const Color(0xFF4A4A4A),
          timerZoneFill: p.surface,
          moneyColor: DarkNeutral.textHigh,
          badgeTextColor: DarkNeutral.textMedium,
          cardShadow: shadow,
        ),
      _ => TableStatusStyle(
          accent: const Color(0xFF8AB4F8),
          cardFill: Color.lerp(p.surfaceElevated, BrandColors.brightBlue, 0.08)!,
          cardBorder: const Color(0xFF3D4F66),
          badgeFill: const Color(0xFF252D38),
          badgeBorder: const Color(0xFF3D4F66),
          timerZoneFill: const Color(0xFF222A34),
          moneyColor: DarkNeutral.textHigh,
          badgeTextColor: const Color(0xFF8AB4F8),
          cardShadow: shadow,
        ),
    };
  }

  /// Vaxt bitmiş — aktivdən daha tünd qırmızı (dark/light ayrı).
  static TableStatusStyle expiredOverlay(
    BuildContext context,
    TableStatusStyle base,
    double t,
  ) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    if (isLight) {
      const pulse = SessionStatusColors.expiredAccentLight;
      return TableStatusStyle(
        accent: Color.lerp(base.accent, pulse, t)!,
        cardFill: Color.lerp(base.cardFill, SessionStatusColors.expiredFillLight, 0.35 * t)!,
        cardBorder: Color.lerp(base.cardBorder, pulse, 0.3 * t)!,
        badgeFill: Color.lerp(base.badgeFill, pulse, 0.15 * t)!,
        badgeBorder: Color.lerp(base.badgeBorder, pulse, 0.25 * t)!,
        timerZoneFill: Color.lerp(base.timerZoneFill, const Color(0xFFFDF0F0), 0.3 * t)!,
        moneyColor: base.moneyColor,
        badgeTextColor: pulse,
        borderWidth: 1 + t * 0.5,
        accentBarWidth: 4 + t,
        cardShadow: [
          BoxShadow(
            color: pulse.withValues(alpha: 0.18 * t),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
          ...(base.cardShadow ?? []),
        ],
      );
    }

    const accent = SessionStatusColors.expiredAccentDark;
    const fill = SessionStatusColors.expiredFillDark;
    const border = SessionStatusColors.expiredBorderDark;
    const label = SessionStatusColors.expiredLabelDark;

    return TableStatusStyle(
      accent: Color.lerp(base.accent, accent, 0.5 + 0.5 * t)!,
      cardFill: Color.lerp(base.cardFill, fill, 0.55 + 0.45 * t)!,
      cardBorder: Color.lerp(base.cardBorder, border, 0.5 + 0.5 * t)!,
      badgeFill: Color.lerp(base.badgeFill, const Color(0xFF2A1819), 0.5 + 0.5 * t)!,
      badgeBorder: Color.lerp(base.badgeBorder, border, 0.5 + 0.5 * t)!,
      timerZoneFill: Color.lerp(base.timerZoneFill, const Color(0xFF261A1C), 0.5 + 0.5 * t)!,
      moneyColor: DarkNeutral.textHigh,
      badgeTextColor: label,
      borderWidth: 1 + t * 0.5,
      accentBarWidth: 5,
      cardShadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.35 * t),
          blurRadius: 14,
          offset: const Offset(0, 2),
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
