import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'brand_colors.dart'; // DarkNeutral

/// Brend şriftləri — vebdə sistem şrifti (Google Fonts yaddaş/şəbəkə problemi verir).
abstract final class CashierTypography {
  static TextStyle _style({
    required double size,
    required Color color,
    required FontWeight weight,
    double? height,
    double letterSpacing = 0,
    double defaultHeight = 1.35,
  }) {
    if (kIsWeb) {
      return TextStyle(
        fontFamily: 'Segoe UI, Roboto, Helvetica, Arial, sans-serif',
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height ?? defaultHeight,
        letterSpacing: letterSpacing,
      );
    }
    return GoogleFonts.barlow(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height ?? defaultHeight,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle display({
    required double size,
    Color color = BrandColors.navy,
    FontWeight weight = FontWeight.w600,
    double? height,
    double letterSpacing = 0,
  }) =>
      _style(
        size: size,
        color: color,
        weight: weight,
        height: height,
        letterSpacing: letterSpacing,
        defaultHeight: 1.2,
      );

  static TextStyle ui({
    required double size,
    Color color = BrandColors.navy,
    FontWeight weight = FontWeight.w500,
    double? height,
    double letterSpacing = 0,
  }) =>
      _style(
        size: size,
        color: color,
        weight: weight,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle label({
    required double size,
    Color color = BrandColors.brightBlue,
    FontWeight weight = FontWeight.w600,
    double letterSpacing = 0.5,
  }) =>
      _style(
        size: size,
        color: color,
        weight: weight,
        letterSpacing: letterSpacing,
        defaultHeight: 1.25,
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
