import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'brand_colors.dart'; // DarkNeutral

/// Brend şriftləri — oxunaqlıq üçün Barlow (condensed yalnız kiçik etiketlər).
abstract final class CashierTypography {
  /// Böyük başlıqlar və rəqəmlər
  static TextStyle display({
    required double size,
    Color color = BrandColors.navy,
    FontWeight weight = FontWeight.w600,
    double? height,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.barlow(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height ?? 1.2,
        letterSpacing: letterSpacing,
      );

  /// Əsas UI mətn — normal en, orta qalınlıq
  static TextStyle ui({
    required double size,
    Color color = BrandColors.navy,
    FontWeight weight = FontWeight.w500,
    double? height,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.barlow(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height ?? 1.35,
        letterSpacing: letterSpacing,
      );

  /// Kiçik bölmə etiketləri (STANSİYALAR, GÜNDƏLİK)
  static TextStyle label({
    required double size,
    Color color = BrandColors.brightBlue,
    FontWeight weight = FontWeight.w600,
    double letterSpacing = 0.5,
  }) =>
      GoogleFonts.barlow(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: 1.25,
        letterSpacing: letterSpacing,
      );

  static TextTheme textTheme(Brightness brightness) {
    final primary = brightness == Brightness.light ? BrandColors.navy : DarkNeutral.textHigh;
    final secondary = brightness == Brightness.light ? BrandColors.textMutedLight : DarkNeutral.textMedium;

    return TextTheme(
      headlineLarge: display(size: 26, color: primary, weight: FontWeight.w600),
      headlineMedium: display(size: 20, color: primary, weight: FontWeight.w600),
      titleLarge: ui(size: 18, color: primary, weight: FontWeight.w600),
      titleMedium: ui(size: 16, color: primary, weight: FontWeight.w500),
      titleSmall: ui(size: 14, color: primary, weight: FontWeight.w500),
      bodyLarge: ui(size: 15, color: primary, weight: FontWeight.w400),
      bodyMedium: ui(size: 14, color: secondary, weight: FontWeight.w400),
      bodySmall: ui(size: 12, color: secondary, weight: FontWeight.w400),
      labelLarge: label(size: 13, color: primary, weight: FontWeight.w600),
    );
  }
}
