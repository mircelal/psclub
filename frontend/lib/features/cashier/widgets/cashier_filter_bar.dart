import 'package:flutter/material.dart';
import '../../../core/theme/cashier_theme.dart';

enum CashierTableFilter { all, active, empty }

class CashierFilterBar extends StatelessWidget {
  const CashierFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
    required this.unitLabel,
  });

  final CashierTableFilter filter;
  final ValueChanged<CashierTableFilter> onChanged;
  final String unitLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          Text(
            unitLabel,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: CashierTheme.textPrimary(context),
            ),
          ),
          const Spacer(),
          _SegmentedFilter(
            selected: filter,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SegmentedFilter extends StatelessWidget {
  const _SegmentedFilter({required this.selected, required this.onChanged});

  final CashierTableFilter selected;
  final ValueChanged<CashierTableFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: CashierTheme.isLight(context) ? const Color(0xFFE5E5EA) : const Color(0xFF3A3A3C),
        borderRadius: BorderRadius.circular(CashierTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg('Hamısı', CashierTableFilter.all),
          _seg('Aktiv', CashierTableFilter.active),
          _seg('Boş', CashierTableFilter.empty),
        ],
      ),
    );
  }

  Widget _seg(String label, CashierTableFilter value) {
    final isSelected = selected == value;
    return Builder(
      builder: (context) {
        return Material(
          color: isSelected ? CashierTheme.surface(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(CashierTheme.radiusPill),
          elevation: isSelected ? 1 : 0,
          shadowColor: Colors.black26,
          child: InkWell(
            onTap: () => onChanged(value),
            borderRadius: BorderRadius.circular(CashierTheme.radiusPill),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? CashierTheme.textPrimary(context)
                      : CashierTheme.textSecondary(context),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
