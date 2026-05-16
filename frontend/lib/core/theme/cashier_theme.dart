import 'package:flutter/material.dart';

/// Premium kassir palitrası — hər zona öz rəngi, harmonik keçidlər.
abstract final class CashierTheme {
  static const radiusCard = 12.0;
  static const radiusControl = 8.0;
  static const radiusPill = 6.0;
  static const sideRailWidth = 272.0;

  static bool isLight(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light;

  // ── Light: təbəqəli premium (xarici → daxili → kart) ──────────────────
  /// Pəncərə fonu — ən tünd, çərçivə hissi
  static const lightScaffold = Color(0xFFD5DAE4);

  /// Sol nav panel — isti ağ
  static const lightSurfaceSidebar = Color(0xFFFAFBFE);

  /// Sağ iş zonası zolağı
  static const lightSurfaceMain = Color(0xFFE8ECF3);

  /// Stansiya cədvəli sahəsi — sakit göy-boz
  static const lightSurfaceCanvas = Color(0xFFDEE4EF);

  /// Üst başlıq
  static const lightSurfaceTopBar = Color(0xFFF4F6FB);

  /// Kartlar, chip-lər
  static const lightSurfaceRaised = Color(0xFFFFFFFF);
  static const lightSurfaceSecondary = Color(0xFFEFF2F8);

  static const lightBorder = Color(0xFFCDD4E0);
  static const lightBorderStrong = Color(0xFFB8C2D4);

  static const lightTextPrimary = Color(0xFF1E2433);
  static const lightTextSecondary = Color(0xFF5C6578);
  static const lightTextTertiary = Color(0xFF8B95A8);

  static const lightAccent = Color(0xFF4F6BF6);
  static const lightAccentSubtle = Color(0x184F6BF6);

  // Status — dolğun, amma pastel
  static const statusEmpty = Color(0xFF3D9B5A);
  static const statusActive = Color(0xFFD45353);
  static const statusPaused = Color(0xFFC9822E);
  static const statusClosed = Color(0xFF7A8499);

  // ── Dark ────────────────────────────────────────────────────────────────
  static const darkScaffold = Color(0xFF181A20);
  static const darkSurfaceSidebar = Color(0xFF22242C);
  static const darkSurfaceMain = Color(0xFF1C1E26);
  static const darkSurfaceCanvas = Color(0xFF262830);
  static const darkSurfaceTopBar = Color(0xFF2A2C36);
  static const darkSurfaceRaised = Color(0xFF30323C);
  static const darkSurfaceSecondary = Color(0xFF2C2E38);
  static const darkBorder = Color(0xFF3E4250);
  static const darkBorderStrong = Color(0xFF4E5464);
  static const darkTextPrimary = Color(0xFFF0F2F8);
  static const darkTextSecondary = Color(0xFFA8B0C4);
  static const darkAccent = Color(0xFF7B9AFF);

  static Color scaffoldBg(BuildContext context) =>
      isLight(context) ? lightScaffold : darkScaffold;

  /// Sol panel
  static Color surfaceSidebar(BuildContext context) =>
      isLight(context) ? lightSurfaceSidebar : darkSurfaceSidebar;

  /// Köhnə ad — sidebar ilə eyni
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
      accent(context).withValues(alpha: isLight(context) ? 0.10 : 0.16);

  static Color textPrimary(BuildContext context) =>
      isLight(context) ? lightTextPrimary : darkTextPrimary;

  static Color textSecondary(BuildContext context) =>
      isLight(context) ? lightTextSecondary : darkTextSecondary;

  static Color textTertiary(BuildContext context) =>
      isLight(context) ? lightTextTertiary : const Color(0xFF8B909A);

  static List<BoxShadow> cardShadow(BuildContext context) => isLight(context)
      ? [
          BoxShadow(
            color: const Color(0xFF4A5568).withValues(alpha: 0.09),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ]
      : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ];

  static List<BoxShadow> panelShadow(BuildContext context) => isLight(context)
      ? [
          BoxShadow(
            color: const Color(0xFF3D4F6E).withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ]
      : cardShadow(context);

  static List<BoxShadow> sideRailShadow(BuildContext context) => isLight(context)
      ? [
          BoxShadow(
            color: const Color(0xFF3D4F6E).withValues(alpha: 0.06),
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
        border: Border.all(color: borderStrong(context).withValues(alpha: 0.7)),
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
        border: Border(bottom: BorderSide(color: border(context))),
        boxShadow: isLight(context)
            ? [
                BoxShadow(
                  color: const Color(0xFF4A5568).withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : const [],
      );

  static TextStyle stationTitle(BuildContext context, {double size = 14}) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: textPrimary(context),
        height: 1.25,
        letterSpacing: -0.2,
      );

  static TextStyle sectionTitle(BuildContext context) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textTertiary(context),
        letterSpacing: 0.55,
      );

  static TextStyle heroTimer(BuildContext context, {Color? color}) => TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: color ?? textPrimary(context),
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1.0,
        letterSpacing: -0.5,
      );

  static TextStyle caption(BuildContext context) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textSecondary(context),
        height: 1.35,
      );

  static TextStyle metricValue(BuildContext context, {bool large = false}) => TextStyle(
        fontSize: large ? 18 : 22,
        fontWeight: FontWeight.w600,
        color: textPrimary(context),
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1.0,
        letterSpacing: -0.3,
      );
}
