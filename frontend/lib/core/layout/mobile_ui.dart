import 'package:flutter/material.dart';

import '../settings/app_settings.dart';

/// Material toxunma hədəfi — kassir terminalı (mobil / planşet).
const double kMinTouchTarget = 48;

/// Telefon üçün mətn miqyasını məhdudlaşdırır (sistem böyütməsi UI pozmasın).
double clampMobileTextScale(BuildContext context, {double max = 1.12}) {
  final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
  if (scale <= max) return scale;
  return max;
}

/// Kassir əsas sahəsi — çentik / home indicator.
Widget cashierSafeArea({required Widget child, bool top = false}) {
  return SafeArea(
    top: top,
    bottom: true,
    left: false,
    right: false,
    minimum: const EdgeInsets.only(bottom: 8),
    child: child,
  );
}

/// Mobil üçün effektiv masa görünüşü.
TableViewMode effectiveTableViewMode(TableViewMode stored, double width, {bool isMobile = false}) {
  if (isMobile) {
    return switch (stored) {
      TableViewMode.card => TableViewMode.grid,
      TableViewMode.grid when width < 360 => TableViewMode.list,
      TableViewMode.list => TableViewMode.list,
      _ => TableViewMode.grid,
    };
  }
  if (width < 380 && stored == TableViewMode.grid) {
    return TableViewMode.list;
  }
  return stored;
}
