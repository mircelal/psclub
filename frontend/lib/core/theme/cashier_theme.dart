import 'package:flutter/material.dart';

/// Kassir paneli — Apple/macOS tipli vizual dil.
abstract final class CashierTheme {
  static const radiusCard = 18.0;
  static const radiusPill = 100.0;
  static const radiusControl = 12.0;

  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  // Light — macOS Sonoma / iOS system grays
  static const lightScaffold = Color(0xFFF2F2F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceSecondary = Color(0xFFF9F9FB);
  static const lightBorder = Color(0x1A000000);
  static const lightTextPrimary = Color(0xFF1D1D1F);
  static const lightTextSecondary = Color(0xFF6E6E73);
  static const lightTextTertiary = Color(0xFFAEAEB2);
  static const lightAccent = Color(0xFF007AFF);

  static Color scaffoldBg(BuildContext context) =>
      isLight(context) ? lightScaffold : const Color(0xFF000000);

  static Color surface(BuildContext context) =>
      isLight(context) ? lightSurface : const Color(0xFF1C1C1E);

  static Color surfaceSecondary(BuildContext context) =>
      isLight(context) ? lightSurfaceSecondary : const Color(0xFF2C2C2E);

  static Color textPrimary(BuildContext context) =>
      isLight(context) ? lightTextPrimary : const Color(0xFFF5F5F7);

  static Color textSecondary(BuildContext context) =>
      isLight(context) ? lightTextSecondary : const Color(0xFF98989D);

  static List<BoxShadow> cardShadow(BuildContext context) => isLight(context)
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ]
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ];

  static List<BoxShadow> topBarShadow(BuildContext context) => isLight(context)
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ]
      : [];

  static Border cardBorder(BuildContext context) => Border.all(
        color: isLight(context) ? const Color(0x0D000000) : Colors.white.withValues(alpha: 0.08),
        width: 0.5,
      );

  static TextStyle stationTitle(BuildContext context, {double size = 17}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: textPrimary(context),
        height: 1.15,
      );

  static TextStyle heroTimer(BuildContext context, {Color? color}) => TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.2,
        color: color ?? textPrimary(context),
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1.0,
      );

  static TextStyle caption(BuildContext context) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSecondary(context),
        letterSpacing: -0.1,
      );
}
