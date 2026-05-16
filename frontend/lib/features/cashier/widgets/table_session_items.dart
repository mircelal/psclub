import 'package:flutter/material.dart';
import '../../../core/theme/cashier_theme.dart';
import 'table_live_state.dart';

class TableSessionItems extends StatelessWidget {
  const TableSessionItems({
    super.key,
    required this.items,
    this.compact = true,
    this.maxVisible = 2,
  });

  final List<SessionItemLine> items;
  final bool compact;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final visible = items.take(maxVisible).toList();
    final hidden = items.length - visible.length;

    return Wrap(
      spacing: 5,
      runSpacing: 4,
      children: [
        ...visible.map((i) => _chip(context, i, compact)),
        if (hidden > 0) _chip(context, null, compact, label: '+$hidden'),
      ],
    );
  }

  Widget _chip(BuildContext context, SessionItemLine? item, bool compact, {String? label}) {
    final text = label ?? '${_short(item!.name)} ×${item.quantity}';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 5),
      decoration: BoxDecoration(
        color: CashierTheme.isLight(context) ? const Color(0xFFE5E5EA) : const Color(0xFF3A3A3C),
        borderRadius: BorderRadius.circular(CashierTheme.radiusPill),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w500,
          color: CashierTheme.textSecondary(context),
          height: 1.1,
        ),
      ),
    );
  }

  String _short(String name) {
    if (name.length <= 12) return name;
    return '${name.substring(0, 11)}…';
  }
}
