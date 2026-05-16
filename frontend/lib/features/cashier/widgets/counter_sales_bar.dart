import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/cashier_theme.dart';

/// Birbaşa satış — masaüstündə əlavə toolbar (mobil/planşetdə top bar + drawer).
class CounterSaleToolbar extends StatelessWidget {
  const CounterSaleToolbar({
    super.key,
    required this.onNewSale,
    this.compact = false,
  });

  final VoidCallback onNewSale;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.md : AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: CashierTheme.surfaceSecondary(context),
        border: Border(bottom: BorderSide(color: CashierTheme.border(context))),
      ),
      child: Row(
        children: [
          FilledButton.tonalIcon(
            onPressed: onNewSale,
            icon: const Icon(Icons.shopping_bag_outlined, size: 18),
            label: Text(compact ? 'Satış' : 'Birbaşa satış'),
            style: FilledButton.styleFrom(
              padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 10, compact ? 10 : 14, 10),
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Ödəniş alındıqdan sonra satış tamamlanır — masa kimi açıq qalmır',
                style: CashierTheme.caption(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
