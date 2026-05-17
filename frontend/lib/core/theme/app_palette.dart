import 'package:flutter/material.dart';
import 'brand_colors.dart';
import 'cashier_theme.dart';

class AppPalette {
  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.borderLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primarySoft,
  });

  final Color bg;
  final Color surface;
  final Color surfaceElevated;
  final Color border;
  final Color borderLight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color primarySoft;

  static AppPalette resolve(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;

  static const _dark = AppPalette(
    bg: CashierTheme.darkScaffold,
    surface: CashierTheme.darkSurfaceSidebar,
    surfaceElevated: CashierTheme.darkSurfaceRaised,
    border: CashierTheme.darkBorder,
    borderLight: CashierTheme.darkBorderStrong,
    textPrimary: CashierTheme.darkTextPrimary,
    textSecondary: CashierTheme.darkTextSecondary,
    textMuted: DarkNeutral.textLow,
    primarySoft: Color(0x332463E7),
  );

  static const _light = AppPalette(
    bg: CashierTheme.lightScaffold,
    surface: CashierTheme.lightSurfaceSidebar,
    surfaceElevated: CashierTheme.lightSurfaceRaised,
    border: CashierTheme.lightBorder,
    borderLight: CashierTheme.lightBorderStrong,
    textPrimary: CashierTheme.lightTextPrimary,
    textSecondary: CashierTheme.lightTextSecondary,
    textMuted: Color(0xFF6B85A3),
    primarySoft: Color(0x1A2463E7),
  );
}

extension PaletteContext on BuildContext {
  AppPalette get palette => AppPalette.resolve(Theme.of(this).brightness);
}
