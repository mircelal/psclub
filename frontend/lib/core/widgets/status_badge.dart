import 'package:flutter/material.dart';
import '../theme/cashier_theme.dart';
import '../theme/table_status_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.status, this.hasSession = false});

  final String label;
  final String status;
  final bool hasSession;

  @override
  Widget build(BuildContext context) {
    final style = context.tableStatusStyle(status, hasSession: hasSession);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.badgeFill,
        borderRadius: BorderRadius.circular(CashierTheme.radiusPill + 4),
        border: Border.all(color: style.badgeBorder.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: style.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: style.accent, fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
