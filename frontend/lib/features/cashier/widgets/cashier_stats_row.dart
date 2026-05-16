import 'package:flutter/material.dart';
import '../../../core/theme/cashier_theme.dart';

class CashierStatsRow extends StatelessWidget {
  const CashierStatsRow({
    super.key,
    required this.active,
    required this.empty,
    required this.total,
    this.liveRevenue = 0,
  });

  final int active;
  final int empty;
  final int total;
  final double liveRevenue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: _MetricTile(
              label: 'Aktiv',
              value: '$active',
              icon: Icons.circle,
              iconColor: const Color(0xFFFF3B30),
              tint: const Color(0xFFFF3B30),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MetricTile(
              label: 'Boş',
              value: '$empty',
              icon: Icons.circle,
              iconColor: const Color(0xFF34C759),
              tint: const Color(0xFF34C759),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MetricTile(
              label: 'Cəmi',
              value: '$total',
              icon: Icons.grid_view_rounded,
              iconColor: CashierTheme.lightAccent,
              tint: CashierTheme.lightAccent,
            ),
          ),
          if (liveRevenue > 0) ...[
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _MetricTile(
                label: 'Açıq hesab',
                value: '${liveRevenue.toStringAsFixed(0)} ₼',
                icon: Icons.payments_rounded,
                iconColor: const Color(0xFF5856D6),
                tint: const Color(0xFF5856D6),
                emphasize: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.tint,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color tint;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: CashierTheme.surface(context),
        borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
        border: CashierTheme.cardBorder(context),
        boxShadow: CashierTheme.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: emphasize ? 14 : 8, color: iconColor),
              const SizedBox(width: 6),
              Text(label, style: CashierTheme.caption(context)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 22 : 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              color: CashierTheme.textPrimary(context),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
