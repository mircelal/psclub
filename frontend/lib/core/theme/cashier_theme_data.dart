import 'package:flutter/material.dart';
import 'brand_colors.dart';
import 'cashier_typography.dart';

/// Kassir marşrutu üçün Material Theme (düymələr, chip, input).
abstract final class CashierThemeData {
  static Widget wrap(BuildContext context, Widget child) {
    final brightness = Theme.of(context).brightness;
    return Theme(
      data: forBrightness(brightness),
      child: child,
    );
  }

  static ThemeData forBrightness(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = isLight ? _lightScheme : _darkScheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      textTheme: CashierTypography.textTheme(brightness),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BrandColors.brightBlue,
          foregroundColor: Colors.white,
          textStyle: CashierTypography.ui(size: 14, color: Colors.white, weight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrandColors.brightBlue,
          side: const BorderSide(color: BrandColors.brightBlue),
          textStyle: CashierTypography.ui(size: 14, color: BrandColors.brightBlue, weight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : DarkNeutral.surface2,
        labelStyle: CashierTypography.ui(size: 13, color: scheme.onSurfaceVariant, weight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: BrandColors.brightBlue, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isLight ? BrandColors.skyPale : DarkNeutral.surface2,
        selectedColor: BrandColors.brightBlue.withValues(alpha: 0.2),
        labelStyle: CashierTypography.ui(size: 13, color: scheme.onSurface, weight: FontWeight.w500),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static final _lightScheme = ColorScheme.light(
    primary: BrandColors.brightBlue,
    onPrimary: Colors.white,
    secondary: BrandColors.navy,
    onSecondary: Colors.white,
    surface: BrandColors.skyPale,
    onSurface: BrandColors.navy,
    surfaceContainerHighest: Colors.white,
    onSurfaceVariant: BrandColors.textMutedLight,
    outline: BrandColors.skyLight,
  );

  static final _darkScheme = ColorScheme.dark(
    primary: BrandColors.brightBlue,
    onPrimary: Colors.white,
    secondary: const Color(0xFF8AB4F8),
    onSecondary: DarkNeutral.textHigh,
    surface: DarkNeutral.surface1,
    onSurface: DarkNeutral.textHigh,
    surfaceContainerHighest: DarkNeutral.surface2,
    onSurfaceVariant: DarkNeutral.textMedium,
    outline: DarkNeutral.border,
  );
}
