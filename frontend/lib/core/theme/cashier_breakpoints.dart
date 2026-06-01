/// Kassir UI — mobil / planşet / masaüstü breakpoint-ləri.
enum CashierLayoutSize { mobile, tablet, desktop }

enum CashierTopBarLayout { mobile, compact, desktop }

class CashierBreakpoints {
  const CashierBreakpoints._(this.width, this.size);

  /// Telefon (< 600)
  static const mobile = 600.0;

  /// Planşet / sessiya paneli (< 900)
  static const tablet = 900.0;

  /// Daimi yan panel (≥ 1100)
  static const desktop = 1100.0;

  final double width;
  final CashierLayoutSize size;

  factory CashierBreakpoints.fromWidth(double width) {
    final size = width < mobile
        ? CashierLayoutSize.mobile
        : width < desktop
            ? CashierLayoutSize.tablet
            : CashierLayoutSize.desktop;
    return CashierBreakpoints._(width, size);
  }

  bool get isMobile => size == CashierLayoutSize.mobile;
  bool get isTablet => size == CashierLayoutSize.tablet;
  bool get isDesktop => size == CashierLayoutSize.desktop;

  /// Yan panel həmişə görünür (geniş ekran).
  bool get showPermanentRail => isDesktop;

  /// Menyu drawer (planşet + mobil).
  bool get showDrawer => !showPermanentRail;

  bool get isCompact => width < tablet;

  CashierTopBarLayout get topBarLayout => switch (size) {
        CashierLayoutSize.mobile => CashierTopBarLayout.mobile,
        CashierLayoutSize.tablet => CashierTopBarLayout.compact,
        CashierLayoutSize.desktop => CashierTopBarLayout.desktop,
      };

  double get contentPaddingH => isMobile ? 10.0 : (isTablet ? 12.0 : 16.0);
  double get contentPaddingV => isMobile ? 6.0 : (isTablet ? 10.0 : 12.0);

  /// Mobil kassir — kompakt üst panel, böyük toxunma zonası.
  bool get useCompactCashierChrome => isMobile || width < 720;

  /// Dar telefon — tək sütun masa grid.
  bool get isNarrowPhone => width < 360;

  /// Mobil masa sahəsi — əlavə çərçivə olmadan düz fon.
  bool get useFlatTableCanvas => isMobile;

  /// Grid-də 2 sütun (geniş telefon).
  int get mobileTableColumns => isNarrowPhone ? 1 : 2;

  /// F1/F5 və s. — yalnız planşet (klaviaturalı) və masaüstü.
  bool get supportsKeyboardShortcuts => !isMobile;
}
