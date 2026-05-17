import 'package:flutter/material.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/cashier_breakpoints.dart';
import 'table_card.dart';
import 'table_list_tile.dart';
import 'table_session_state.dart';

/// Grid/kart rejimində bir masa hüceyrəsinin maksimum eni (böyük monitorlarda kart böyüməsin).
class _TableTileLimits {
  const _TableTileLimits({
    required this.maxWidth,
    required this.minWidth,
    required this.minColumns,
    required this.maxColumns,
    required this.aspectRatio,
  });

  final double maxWidth;
  final double minWidth;
  final int minColumns;
  final int maxColumns;
  final double aspectRatio;
}

class TablesLayout extends StatelessWidget {
  const TablesLayout({
    super.key,
    required this.tables,
    required this.viewMode,
    required this.tick,
    required this.onOpen,
    required this.onSession,
    this.onTableContextMenu,
  });

  final List<Map<String, dynamic>> tables;
  final TableViewMode viewMode;
  final int tick;
  final void Function(Map<String, dynamic>) onOpen;
  final void Function(int) onSession;
  final void Function(Map<String, dynamic> table, TapDownDetails details)? onTableContextMenu;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final bp = CashierBreakpoints.fromWidth(w);
        final padding = EdgeInsets.all(bp.isMobile ? 10 : 16);
        final spacing = bp.isMobile ? 8.0 : 12.0;

        return switch (viewMode) {
          TableViewMode.list => ListView.separated(
              padding: padding,
              itemCount: tables.length,
              separatorBuilder: (_, __) => SizedBox(height: bp.isMobile ? 8 : 10),
              itemBuilder: (_, i) => TableListTile(
                table: tables[i],
                tick: tick,
                onTap: () => _tap(tables[i]),
                onSecondaryTap: (d) => _contextMenu(tables[i], d),
              ),
            ),
          TableViewMode.card => _buildGrid(
              width: w,
              limits: _limitsForCard(bp),
              padding: padding,
              spacing: spacing,
              compact: bp.isMobile,
            ),
          TableViewMode.grid => _buildGrid(
              width: w,
              limits: _limitsForGrid(bp),
              padding: padding,
              spacing: spacing,
              compact: bp.isMobile || bp.isTablet,
            ),
        };
      },
    );
  }

  _TableTileLimits _limitsForGrid(CashierBreakpoints bp) {
    return switch (bp.size) {
      CashierLayoutSize.mobile => const _TableTileLimits(
          maxWidth: 520,
          minWidth: 140,
          minColumns: 1,
          maxColumns: 2,
          aspectRatio: 0.82,
        ),
      CashierLayoutSize.tablet => const _TableTileLimits(
          maxWidth: 220,
          minWidth: 150,
          minColumns: 2,
          maxColumns: 6,
          aspectRatio: 0.72,
        ),
      CashierLayoutSize.desktop => const _TableTileLimits(
          maxWidth: 200,
          minWidth: 148,
          minColumns: 3,
          maxColumns: 12,
          aspectRatio: 0.72,
        ),
    };
  }

  _TableTileLimits _limitsForCard(CashierBreakpoints bp) {
    return switch (bp.size) {
      CashierLayoutSize.mobile => const _TableTileLimits(
          maxWidth: 520,
          minWidth: 260,
          minColumns: 1,
          maxColumns: 1,
          aspectRatio: 0.95,
        ),
      CashierLayoutSize.tablet => const _TableTileLimits(
          maxWidth: 340,
          minWidth: 240,
          minColumns: 2,
          maxColumns: 4,
          aspectRatio: 0.88,
        ),
      CashierLayoutSize.desktop => const _TableTileLimits(
          maxWidth: 300,
          minWidth: 220,
          minColumns: 2,
          maxColumns: 8,
          aspectRatio: 0.88,
        ),
    };
  }

  /// Maksimum hüceyrə eninə görə sütun sayı — 27" və s. geniş ekranda daha çox masa.
  static int _columnCount(double innerWidth, double spacing, _TableTileLimits limits) {
    if (innerWidth <= 0) return limits.minColumns;

    var cols = ((innerWidth + spacing) / (limits.maxWidth + spacing)).floor();
    cols = cols.clamp(limits.minColumns, limits.maxColumns);

    var tileW = (innerWidth - spacing * (cols - 1)) / cols;
    if (tileW < limits.minWidth && cols > limits.minColumns) {
      cols = ((innerWidth + spacing) / (limits.minWidth + spacing)).floor();
      cols = cols.clamp(limits.minColumns, limits.maxColumns);
      tileW = (innerWidth - spacing * (cols - 1)) / cols;
    }

    return cols;
  }

  Widget _buildGrid({
    required double width,
    required _TableTileLimits limits,
    required EdgeInsets padding,
    required double spacing,
    required bool compact,
  }) {
    final inner = width - padding.horizontal;
    final cross = _columnCount(inner, spacing, limits);
    final tileW = cross > 0 ? (inner - spacing * (cross - 1)) / cross : inner;
    final useCompact = compact || tileW < 195;

    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: limits.aspectRatio,
      ),
      itemCount: tables.length,
      itemBuilder: (_, i) => TableCard(
        table: tables[i],
        tick: tick,
        compact: useCompact,
        onTap: () => _tap(tables[i]),
        onSecondaryTap: (d) => _contextMenu(tables[i], d),
      ),
    );
  }

  void _contextMenu(Map<String, dynamic> t, TapDownDetails details) {
    onTableContextMenu?.call(t, details);
  }

  void _tap(Map<String, dynamic> t) {
    final sessionId = TableSessionState.openSessionId(t);
    if (sessionId != null) {
      onSession(sessionId);
    } else if (TableSessionState.canOpenSession(t)) {
      onOpen(t);
    }
  }
}
