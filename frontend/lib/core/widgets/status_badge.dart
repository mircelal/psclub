import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.badgeFill,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: style.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: style.accent, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: -0.1),
          ),
        ],
      ),
    );
  }
}
