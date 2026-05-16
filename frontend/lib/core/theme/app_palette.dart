import 'package:flutter/material.dart';
import 'app_colors.dart';

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

  static const dark = AppPalette(
    bg: AppColors.bg,
    surface: AppColors.surface,
    surfaceElevated: AppColors.surfaceElevated,
    border: AppColors.border,
    borderLight: AppColors.borderLight,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textMuted: AppColors.textMuted,
    primarySoft: AppColors.primarySoft,
  );

  static const light = AppPalette(
    bg: Color(0xFFE8ECF1),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    border: Color(0xFFC5CED8),
    borderLight: Color(0xFFB0BBC8),
    textPrimary: Color(0xFF15202B),
    textSecondary: Color(0xFF4A5568),
    textMuted: Color(0xFF718096),
    primarySoft: Color(0x1A5B4CE6),
  );

  static AppPalette resolve(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

extension PaletteContext on BuildContext {
  AppPalette get palette => AppPalette.resolve(Theme.of(this).brightness);
}
