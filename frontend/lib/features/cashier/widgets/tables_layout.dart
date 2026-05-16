import 'package:flutter/material.dart';
import '../../../core/settings/app_settings.dart';
import 'table_card.dart';
import 'table_list_tile.dart';

class TablesLayout extends StatelessWidget {
  const TablesLayout({
    super.key,
    required this.tables,
    required this.viewMode,
    required this.tick,
    required this.onOpen,
    required this.onSession,
  });

  final List<Map<String, dynamic>> tables;
  final TableViewMode viewMode;
  final int tick;
  final void Function(Map<String, dynamic>) onOpen;
  final void Function(int) onSession;

  @override
  Widget build(BuildContext context) {
    return switch (viewMode) {
      TableViewMode.list => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          itemCount: tables.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => TableListTile(
            table: tables[i],
            tick: tick,
            onTap: () => _tap(tables[i]),
          ),
        ),
      TableViewMode.card => _grid(context, _cardCrossCount(context), 0.88, compact: false),
      TableViewMode.grid => _grid(context, _crossCount(context), 0.72, compact: _isCompactGrid(context)),
    };
  }

  bool _isCompactGrid(BuildContext context) => MediaQuery.sizeOf(context).width < 900;

  int _crossCount(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w > 1600) return 6;
    if (w > 1280) return 5;
    if (w > 1024) return 4;
    if (w > 768) return 3;
    return 2;
  }

  int _cardCrossCount(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w > 1200) return 3;
    if (w > 720) return 2;
    return 1;
  }

  Widget _grid(BuildContext context, int cross, double aspect, {required bool compact}) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cross,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: aspect,
      ),
      itemCount: tables.length,
      itemBuilder: (_, i) => TableCard(
        table: tables[i],
        tick: tick,
        compact: compact,
        onTap: () => _tap(tables[i]),
      ),
    );
  }

  void _tap(Map<String, dynamic> t) {
    final hasSession = t['session_id'] != null;
    final status = t['status'] as String? ?? 'empty';
    if (hasSession) {
      onSession(t['session_id'] as int);
    } else if (status == 'empty') {
      onOpen(t);
    }
  }
}
