import 'package:flutter/material.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/cashier_breakpoints.dart';
import 'table_card.dart';
import 'table_list_tile.dart';
import 'table_session_state.dart';

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
          TableViewMode.card => _grid(
              w,
              _cardCrossCount(w),
              bp.isMobile ? 0.95 : 0.88,
              padding: padding,
              compact: bp.isMobile,
            ),
          TableViewMode.grid => _grid(
              w,
              _crossCount(w),
              bp.isMobile ? 0.82 : (bp.isCompact ? 0.68 : 0.72),
              padding: padding,
              compact: bp.isCompact,
            ),
        };
      },
    );
  }

  int _crossCount(double w) {
    if (w < 380) return 1;
    if (w < 560) return 2;
    if (w < 768) return 2;
    if (w < 1024) return 3;
    if (w < 1280) return 4;
    if (w < 1600) return 5;
    return 6;
  }

  int _cardCrossCount(double w) {
    if (w < 480) return 1;
    if (w < 720) return 2;
    if (w < 1200) return 2;
    return 3;
  }

  Widget _grid(
    double width,
    int cross,
    double aspect, {
    required EdgeInsets padding,
    required bool compact,
  }) {
    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        crossAxisSpacing: compact ? 8 : 12,
        mainAxisSpacing: compact ? 8 : 12,
        childAspectRatio: aspect,
      ),
      itemCount: tables.length,
      itemBuilder: (_, i) => TableCard(
        table: tables[i],
        tick: tick,
        compact: compact,
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
