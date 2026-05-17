import 'package:flutter/material.dart';
import 'brand_colors.dart';
import 'cashier_typography.dart';

/// Kassir UI — brend palitrası (Pantone 281 C / 2727 C).
abstract final class CashierTheme {
  static const radiusCard = 12.0;
  static const radiusControl = 8.0;
  static const radiusPill = 6.0;
  static const sideRailWidth = 272.0;

  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  // ── Light ───────────────────────────────────────────────────────────────
  static const lightScaffold = BrandColors.skyPale;
  static const lightSurfaceSidebar = Color(0xFFFFFFFF);
  static const lightSurfaceMain = Color(0xFFF4F8FD);
  static const lightSurfaceCanvas = BrandColors.skyLight;
  static const lightSurfaceTopBar = Color(0xFFFFFFFF);
  static const lightSurfaceRaised = Color(0xFFFFFFFF);
  static const lightSurfaceSecondary = Color(0xFFE8F1FC);

  static const lightBorder = Color(0xFFB8CCE8);
  static const lightBorderStrong = Color(0xFF8FAFD4);

  static const lightTextPrimary = BrandColors.navy;
  static const lightTextSecondary = BrandColors.textMutedLight;
  static const lightTextTertiary = Color(0xFF6B85A3);

  static const lightAccent = BrandColors.brightBlue;
  static const lightAccentSubtle = Color(0x1A2463E7);

  // ── Dark (neytral qara-boz — Google / Material 3) ─────────────────────
  static const darkScaffold = DarkNeutral.scaffold;
  static const darkSurfaceSidebar = DarkNeutral.surface1;
  static const darkSurfaceMain = DarkNeutral.scaffold;
  static const darkSurfaceCanvas = Color(0xFF1A1A1A);
  static const darkSurfaceTopBar = DarkNeutral.surface1;
  static const darkSurfaceRaised = DarkNeutral.surface2;
  static const darkSurfaceSecondary = Color(0xFF252525);
  static const darkBorder = DarkNeutral.border;
  static const darkBorderStrong = DarkNeutral.borderStrong;
  static const darkTextPrimary = DarkNeutral.textHigh;
  static const darkTextSecondary = DarkNeutral.textMedium;
  static const darkTextTertiary = DarkNeutral.textLow;
  static const darkAccent = BrandColors.brightBlue;

  // Status — brendə uyğun, oxunaqlı
  static const statusEmpty = BrandColors.brightBlue;
  static const statusActive = Color(0xFFE04B4B);
  static const statusPaused = Color(0xFFE89B2E);
  static const statusClosed = Color(0xFF6B85A3);

  static Color scaffoldBg(BuildContext context) =>
      isLight(context) ? lightScaffold : darkScaffold;

  static Color surfaceSidebar(BuildContext context) =>
      isLight(context) ? lightSurfaceSidebar : darkSurfaceSidebar;

  static Color surface(BuildContext context) => surfaceSidebar(context);

  static Color surfaceMain(BuildContext context) =>
      isLight(context) ? lightSurfaceMain : darkSurfaceMain;

  static Color surfaceCanvas(BuildContext context) =>
      isLight(context) ? lightSurfaceCanvas : darkSurfaceCanvas;

  static Color surfaceTopBar(BuildContext context) =>
      isLight(context) ? lightSurfaceTopBar : darkSurfaceTopBar;

  static Color surfaceSecondary(BuildContext context) =>
      isLight(context) ? lightSurfaceSecondary : darkSurfaceSecondary;

  static Color surfaceRaised(BuildContext context) =>
      isLight(context) ? lightSurfaceRaised : darkSurfaceRaised;

  static Color border(BuildContext context) =>
      isLight(context) ? lightBorder : darkBorder;

  static Color borderStrong(BuildContext context) =>
      isLight(context) ? lightBorderStrong : darkBorderStrong;

  static Color accent(BuildContext context) =>
      isLight(context) ? lightAccent : darkAccent;

  static Color accentSubtle(BuildContext context) =>
      isLight(context)
          ? lightAccent.withValues(alpha: 0.10)
          : BrandColors.brightBlue.withValues(alpha: 0.14);

  static Color textPrimary(BuildContext context) =>
      isLight(context) ? lightTextPrimary : darkTextPrimary;

  static Color textSecondary(BuildContext context) =>
      isLight(context) ? lightTextSecondary : darkTextSecondary;

  static Color textTertiary(BuildContext context) =>
      isLight(context) ? lightTextTertiary : darkTextTertiary;

  static List<BoxShadow> cardShadow(BuildContext context) => isLight(context)
      ? [
          BoxShadow(
            color: BrandColors.navy.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ]
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ];

  static List<BoxShadow> panelShadow(BuildContext context) => isLight(context)
      ? [
          BoxShadow(
            color: BrandColors.brightBlue.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ]
      : cardShadow(context);

  static List<BoxShadow> sideRailShadow(BuildContext context) => isLight(context)
      ? [
          BoxShadow(
            color: BrandColors.navy.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(2, 0),
          ),
        ]
      : const [];

  static Border cardBorder(BuildContext context) => Border.all(
        color: border(context),
        width: 1,
      );

  static BoxDecoration elevatedCardDecoration(
    BuildContext context, {
    Color? fill,
    Color? borderColor,
  }) =>
      BoxDecoration(
        color: fill ?? surfaceRaised(context),
        borderRadius: BorderRadius.circular(radiusCard),
        border: Border.all(color: borderColor ?? border(context), width: 1),
        boxShadow: cardShadow(context),
      );

  static BoxDecoration contentPanelDecoration(BuildContext context) => BoxDecoration(
        color: surfaceCanvas(context),
        border: Border.all(color: borderStrong(context).withValues(alpha: 0.65)),
        borderRadius: BorderRadius.circular(radiusCard + 4),
        boxShadow: panelShadow(context),
      );

  static BoxDecoration sideRailDecoration(BuildContext context) => BoxDecoration(
        color: surfaceSidebar(context),
        border: Border(right: BorderSide(color: border(context))),
        boxShadow: sideRailShadow(context),
      );

  static BoxDecoration topBarDecoration(BuildContext context) => BoxDecoration(
        color: surfaceTopBar(context),
        border: Border(
          bottom: BorderSide(color: border(context)),
        ),
        boxShadow: isLight(context)
            ? [
                BoxShadow(
                  color: BrandColors.navy.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : const [],
      );

  static TextStyle stationTitle(BuildContext context, {double size = 14}) =>
      CashierTypography.ui(
        size: size,
        color: textPrimary(context),
        weight: FontWeight.w600,
        height: 1.3,
      );

  static TextStyle sectionTitle(BuildContext context) => CashierTypography.label(
        size: 11,
        color: isLight(context) ? BrandColors.brightBlue : darkTextSecondary,
        weight: FontWeight.w600,
        letterSpacing: 0.6,
      );

  static TextStyle heroTimer(BuildContext context, {Color? color}) =>
      CashierTypography.display(
        size: 26,
        color: color ?? textPrimary(context),
        weight: FontWeight.w600,
        height: 1.1,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  static TextStyle caption(BuildContext context) => CashierTypography.ui(
        size: 12,
        color: textSecondary(context),
        weight: FontWeight.w400,
        height: 1.4,
      );

  static TextStyle metricValue(BuildContext context, {bool large = false}) =>
      CashierTypography.display(
        size: large ? 18 : 22,
        color: textPrimary(context),
        weight: FontWeight.w600,
        height: 1.15,
      ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
}
