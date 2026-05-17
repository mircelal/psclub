import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'brand_colors.dart';
import 'cashier_theme.dart';
import 'cashier_typography.dart';
import 'app_spacing.dart';

class AppTheme {
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = isLight
        ? const ColorScheme.light(
            primary: BrandColors.brightBlue,
            onPrimary: Colors.white,
            secondary: BrandColors.navy,
            onSecondary: Colors.white,
            surface: CashierTheme.lightSurfaceSidebar,
            onSurface: BrandColors.navy,
            surfaceContainerHighest: Colors.white,
            onSurfaceVariant: BrandColors.textMutedLight,
            outline: CashierTheme.lightBorder,
            error: Color(0xFFE04B4B),
          )
        : const ColorScheme.dark(
            primary: BrandColors.brightBlue,
            onPrimary: Colors.white,
            secondary: Color(0xFF8AB4F8),
            onSecondary: DarkNeutral.textHigh,
            surface: DarkNeutral.surface1,
            onSurface: DarkNeutral.textHigh,
            surfaceContainerHighest: DarkNeutral.surface2,
            surfaceContainerHigh: DarkNeutral.surface3,
            onSurfaceVariant: DarkNeutral.textMedium,
            outline: DarkNeutral.border,
            outlineVariant: Color(0xFF2C2C2C),
            error: Color(0xFFF28B82),
          );

    final onSurface = scheme.onSurface;
    final onSurfaceVariant = scheme.onSurfaceVariant;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isLight ? CashierTheme.lightScaffold : CashierTheme.darkScaffold,
      dividerColor: scheme.outline,
      splashColor: BrandColors.brightBlue.withValues(alpha: 0.08),
      highlightColor: Colors.transparent,
      textTheme: CashierTypography.textTheme(brightness),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: isLight ? CashierTheme.lightSurfaceTopBar : CashierTheme.darkSurfaceTopBar,
        foregroundColor: onSurface,
        systemOverlayStyle: isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
        titleTextStyle: CashierTypography.ui(size: 17, color: onSurface, weight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: isLight ? Colors.white : CashierTheme.darkSurfaceRaised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CashierTheme.radiusCard),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isLight ? Colors.white : CashierTheme.darkSurfaceRaised,
        elevation: 24,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)),
        titleTextStyle: CashierTypography.ui(size: 18, color: onSurface, weight: FontWeight.w600),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isLight ? Colors.white : CashierTheme.darkSurfaceRaised,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight ? Colors.white : CashierTheme.darkSurfaceTopBar,
        indicatorColor: BrandColors.brightBlue.withValues(alpha: isLight ? 0.12 : 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return CashierTypography.ui(
            size: 12,
            color: selected ? BrandColors.brightBlue : onSurfaceVariant,
            weight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? BrandColors.brightBlue : onSurfaceVariant,
            size: 22,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : DarkNeutral.surface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md + 2),
        hintStyle: CashierTypography.ui(size: 14, color: onSurfaceVariant, weight: FontWeight.w400),
        labelStyle: CashierTypography.ui(size: 13, color: onSurfaceVariant, weight: FontWeight.w500),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
          borderSide: const BorderSide(color: BrandColors.brightBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
          borderSide: const BorderSide(color: Color(0xFFE04B4B)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BrandColors.brightBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md + 2),
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CashierTheme.radiusControl)),
          textStyle: CashierTypography.ui(size: 14, color: Colors.white, weight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrandColors.brightBlue,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md + 2),
          minimumSize: const Size(0, 44),
          side: const BorderSide(color: BrandColors.brightBlue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CashierTheme.radiusControl)),
          textStyle: CashierTypography.ui(size: 14, color: BrandColors.brightBlue, weight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: BrandColors.brightBlue),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isLight ? BrandColors.skyPale : DarkNeutral.surface2,
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.7)),
        labelStyle: CashierTypography.ui(size: 13, color: onSurface, weight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CashierTheme.radiusControl)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isLight ? BrandColors.navy : CashierTheme.darkSurfaceRaised,
        contentTextStyle: CashierTypography.ui(
          size: 14,
          color: isLight ? BrandColors.textOnNavy : DarkNeutral.textHigh,
          weight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CashierTheme.radiusControl)),
      ),
      iconTheme: IconThemeData(
        color: isLight ? BrandColors.navy : DarkNeutral.textHigh,
        size: 22,
      ),
      primaryIconTheme: IconThemeData(
        color: isLight ? BrandColors.brightBlue : const Color(0xFF8AB4F8),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: isLight ? BrandColors.textMutedLight : DarkNeutral.textMedium,
        textColor: onSurface,
      ),
      dividerTheme: DividerThemeData(color: scheme.outline.withValues(alpha: 0.65)),
    );
  }

  static Color tableStatusColor(String status) => AppColors.tableStatus(status);
}
