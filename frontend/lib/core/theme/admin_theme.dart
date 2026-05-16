import 'package:flutter/material.dart';
import 'brand_colors.dart';
import 'cashier_theme.dart';

/// Admin panel — kassir ilə eyni brend (Pantone 281 C / 2727 C).
abstract final class AdminTheme {
  static const sideNavWidth = 248.0;

  static Color success(BuildContext context) =>
      CashierTheme.isLight(context) ? const Color(0xFF1B8F5A) : const Color(0xFF3DDB8A);

  static Color warning(BuildContext context) => CashierTheme.statusPaused;

  static Color danger(BuildContext context) => CashierTheme.statusActive;

  static Color info(BuildContext context) => BrandColors.brightBlue;

  static Color accent(BuildContext context) => CashierTheme.accent(context);

  static Color primarySoft(BuildContext context) => CashierTheme.accentSubtle(context);
}
