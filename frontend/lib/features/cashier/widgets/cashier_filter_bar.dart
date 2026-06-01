import 'package:flutter/material.dart';
import '../../../core/layout/mobile_ui.dart';
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
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
        child: _MobileFilterChips(selected: filter, onChanged: onChanged),
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

/// Mobil — böyük toxunma hədəfi ilə üfüqi çiplər.
class _MobileFilterChips extends StatelessWidget {
  const _MobileFilterChips({required this.selected, required this.onChanged});

  final CashierTableFilter selected;
  final ValueChanged<CashierTableFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _chip(context, 'Hamısı', CashierTableFilter.all),
        const SizedBox(width: 8),
        _chip(context, 'Aktiv', CashierTableFilter.active),
        const SizedBox(width: 8),
        _chip(context, 'Boş', CashierTableFilter.empty),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, CashierTableFilter value) {
    final isSelected = selected == value;
    return Expanded(
      child: Material(
        color: isSelected ? CashierTheme.surfaceRaised(context) : CashierTheme.surfaceSecondary(context),
        borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
          child: Container(
            constraints: const BoxConstraints(minHeight: kMinTouchTarget),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: isSelected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
                    border: Border.all(color: CashierTheme.accent(context).withValues(alpha: 0.4)),
                  )
                : null,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? CashierTheme.accent(context) : CashierTheme.textSecondary(context),
              ),
            ),
          ),
        ),
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
    return Material(
      color: isSelected ? CashierTheme.surfaceRaised(context) : Colors.transparent,
      borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
        hoverColor: CashierTheme.accentSubtle(context),
        child: Container(
          width: stretch ? double.infinity : null,
          constraints: BoxConstraints(minHeight: stretch ? kMinTouchTarget : 0),
          padding: EdgeInsets.symmetric(horizontal: stretch ? 12 : 14, vertical: stretch ? 12 : 7),
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
            textAlign: stretch ? TextAlign.center : TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? CashierTheme.accent(context) : CashierTheme.textSecondary(context),
            ),
          ),
        ),
      ),
    );
  }
}
