import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/cashier_theme.dart';
import '../../../core/utils/json_parse.dart';

/// Açıq birbaşa satış sessiyaları — kassir tez qayıda bilsin.
class CounterSalesBar extends StatelessWidget {
  const CounterSalesBar({
    super.key,
    required this.sessions,
    required this.onNewSale,
    required this.onOpenSession,
  });

  final List<Map<String, dynamic>> sessions;
  final VoidCallback onNewSale;
  final ValueChanged<int> onOpenSession;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: CashierTheme.surfaceSecondary(context),
        border: Border(bottom: BorderSide(color: CashierTheme.border(context))),
      ),
      child: Row(
        children: [
          FilledButton.tonalIcon(
            onPressed: onNewSale,
            icon: const Icon(Icons.add_shopping_cart, size: 18),
            label: const Text('Birbaşa satış'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          if (sessions.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.lg),
            Text('Açıq:', style: CashierTheme.caption(context)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: sessions.map((s) {
                    final id = jsonToInt(s['id']);
                    final bill = s['bill_preview'] as Map<String, dynamic>? ?? {};
                    final total = jsonToDouble(bill['total_amount']);
                    final customer = s['customer_name'] as String?;
                    final label = customer != null && customer.isNotEmpty
                        ? customer
                        : 'Satış #$id';

                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ActionChip(
                        avatar: Icon(Icons.receipt_long_outlined, size: 16, color: CashierTheme.accent(context)),
                        label: Text(
                          '$label · ${total.toStringAsFixed(2)} ₼',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () => onOpenSession(id),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
