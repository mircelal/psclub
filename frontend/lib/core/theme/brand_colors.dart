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
