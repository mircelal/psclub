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
    this.scrollable = false,
    this.dense = false,
  });

  final int active;
  final int empty;
  final int total;
  final double liveRevenue;
  final bool vertical;
  final bool scrollable;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _MetricTile(
        label: 'Aktiv sessiya',
        value: '$active',
        icon: Icons.play_circle_outline_rounded,
        accent: CashierTheme.statusActive,
        dense: dense,
      ),
      _MetricTile(
        label: 'Boş stansiya',
        value: '$empty',
        icon: Icons.check_circle_outline_rounded,
        accent: CashierTheme.statusEmpty,
        dense: dense,
      ),
      _MetricTile(
        label: 'Ümumi',
        value: '$total',
        icon: Icons.grid_view_rounded,
        accent: CashierTheme.accent(context),
        dense: dense,
      ),
      if (liveRevenue > 0)
        _MetricTile(
          label: 'Açıq hesab',
          value: '${liveRevenue.toStringAsFixed(2)} ₼',
          icon: Icons.account_balance_wallet_outlined,
          accent: const Color(0xFF7C6CF0),
          emphasize: true,
          dense: dense,
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

    if (scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) SizedBox(width: dense ? 6 : 8),
              SizedBox(width: dense ? 124 : 148, child: tiles[i]),
            ],
          ],
        ),
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
    this.dense = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final bool emphasize;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final iconBox = dense ? 28.0 : 32.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 12, vertical: dense ? 8 : 10),
      decoration: CashierTheme.elevatedCardDecoration(
        context,
        fill: CashierTheme.surfaceRaised(context),
        borderColor: CashierTheme.border(context),
      ),
      child: Row(
        children: [
          Container(
            width: iconBox,
            height: iconBox,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(CashierTheme.radiusControl + 2),
              border: Border.all(color: accent.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, size: dense ? 16 : 18, color: accent),
          ),
          SizedBox(width: dense ? 8 : 10),
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
