import 'package:flutter/material.dart';

/// Brend rəng siyasəti — Pantone 281 C, 2727 C və keçid tonu.
abstract final class BrandColors {
  /// Pantone 281 C — tünd mavi (güvən, peşəkarlıq)
  static const navy = Color(0xFF00205B);

  /// Pantone 2727 C — parlaq mavi (enerji, innovasiya)
  static const brightBlue = Color(0xFF2463E7);

  /// Açıq mavi keçid — balans və rəqəmsal dinamika
  static const sky = Color(0xFF5B9FEF);
  static const skyLight = Color(0xFFD6E6FA);
  static const skyPale = Color(0xFFEEF4FC);

  static const navyDark = Color(0xFF001845);
  static const navyMid = Color(0xFF0A3270);

  static const textOnNavy = Color(0xFFF4F8FF);
  static const textOnLight = navy;
  static const textMutedLight = Color(0xFF4A5F7A);
}

/// Material / Google tipli neytral dark fonlar (mavi ton minimum).
abstract final class DarkNeutral {
  static const scaffold = Color(0xFF121212);
  static const surface1 = Color(0xFF1E1E1E);
  static const surface2 = Color(0xFF2C2C2C);
  static const surface3 = Color(0xFF383838);
  static const border = Color(0xFF3C3C3C);
  static const borderStrong = Color(0xFF5F6368);
  static const textHigh = Color(0xFFE8EAED);
  static const textMedium = Color(0xFF9AA0A6);
  static const textLow = Color(0xFF80868B);
}
