import 'package:flutter/material.dart';
import '../../../core/theme/cashier_theme.dart';

enum CashierTableFilter { all, active, empty }

class CashierFilterBar extends StatelessWidget {
  const CashierFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
    required this.unitLabel,
    this.compact = false,
    this.horizontalScroll = false,
  });

  final CashierTableFilter filter;
  final ValueChanged<CashierTableFilter> onChanged;
  final String unitLabel;
  final bool compact;
  final bool horizontalScroll;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('STANSİYALAR', style: CashierTheme.sectionTitle(context)),
          const SizedBox(height: 4),
          Text(unitLabel, style: CashierTheme.stationTitle(context, size: 16)),
          const SizedBox(height: 10),
          _SegmentedFilter(selected: filter, onChanged: onChanged, stretch: true),
        ],
      );
    }

    final filterWidget = _SegmentedFilter(selected: filter, onChanged: onChanged);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: horizontalScroll
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: filterWidget,
            )
          : Row(
              children: [
                Flexible(
                  child: Text(
                    unitLabel,
                    style: CashierTheme.stationTitle(context, size: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                filterWidget,
              ],
            ),
    );
  }
}

class _SegmentedFilter extends StatelessWidget {
  const _SegmentedFilter({
    required this.selected,
    required this.onChanged,
    this.stretch = false,
  });

  final CashierTableFilter selected;
  final ValueChanged<CashierTableFilter> onChanged;
  final bool stretch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: CashierTheme.surfaceSecondary(context),
        borderRadius: BorderRadius.circular(CashierTheme.radiusCard),
        border: Border.all(color: CashierTheme.border(context)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A5568).withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: stretch
          ? Column(
              children: [
                _seg(context, 'Hamısı', CashierTableFilter.all, stretch: true),
                _seg(context, 'Aktiv', CashierTableFilter.active, stretch: true),
                _seg(context, 'Boş', CashierTableFilter.empty, stretch: true),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _seg(context, 'Hamısı', CashierTableFilter.all),
                _seg(context, 'Aktiv', CashierTableFilter.active),
                _seg(context, 'Boş', CashierTableFilter.empty),
              ],
            ),
    );
  }

  Widget _seg(BuildContext context, String label, CashierTableFilter value, {bool stretch = false}) {
    final isSelected = selected == value;
    final child = Material(
      color: isSelected ? CashierTheme.surfaceRaised(context) : Colors.transparent,
      borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
        hoverColor: CashierTheme.accentSubtle(context),
        child: Container(
          width: stretch ? double.infinity : null,
          padding: EdgeInsets.symmetric(horizontal: stretch ? 12 : 14, vertical: stretch ? 9 : 7),
          decoration: isSelected
              ? BoxDecoration(
                  color: CashierTheme.surfaceRaised(context),
                  borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
                  border: Border.all(color: CashierTheme.accent(context).withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: CashierTheme.accent(context).withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                )
              : null,
          child: Text(
            label,
            textAlign: stretch ? TextAlign.left : TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? CashierTheme.accent(context) : CashierTheme.textSecondary(context),
            ),
          ),
        ),
      ),
    );
    return stretch ? child : child;
  }
}
