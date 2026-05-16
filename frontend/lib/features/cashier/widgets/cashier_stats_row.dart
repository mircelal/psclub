import 'package:flutter/material.dart';
import '../../../core/theme/cashier_theme.dart';

class CashierStatsRow extends StatelessWidget {
  const CashierStatsRow({
    super.key,
    required this.active,
    required this.empty,
    required this.total,
    this.liveRevenue = 0,
    this.vertical = false,
  });

  final int active;
  final int empty;
  final int total;
  final double liveRevenue;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _MetricTile(
        label: 'Aktiv sessiya',
        value: '$active',
        icon: Icons.play_circle_outline_rounded,
        accent: CashierTheme.statusActive,
      ),
      _MetricTile(
        label: 'Boş stansiya',
        value: '$empty',
        icon: Icons.check_circle_outline_rounded,
        accent: CashierTheme.statusEmpty,
      ),
      _MetricTile(
        label: 'Ümumi',
        value: '$total',
        icon: Icons.grid_view_rounded,
        accent: CashierTheme.accent(context),
      ),
      if (liveRevenue > 0)
        _MetricTile(
          label: 'Açıq hesab',
          value: '${liveRevenue.toStringAsFixed(2)} ₼',
          icon: Icons.account_balance_wallet_outlined,
          accent: const Color(0xFF7C6CF0),
          emphasize: true,
        ),
    ];

    if (vertical) {
      return Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            tiles[i],
          ],
        ],
      );
    }

    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: CashierTheme.elevatedCardDecoration(
        context,
        fill: CashierTheme.surfaceRaised(context),
        borderColor: CashierTheme.border(context),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(CashierTheme.radiusControl + 2),
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: CashierTheme.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: CashierTheme.metricValue(context, large: emphasize),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
