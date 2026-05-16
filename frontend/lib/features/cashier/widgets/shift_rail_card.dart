import 'package:flutter/material.dart';
import '../../../core/config/business_config_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/cashier_theme.dart';
import '../../../core/utils/json_parse.dart';
import '../../../core/widgets/money_text.dart';

class ShiftRailCard extends StatelessWidget {
  const ShiftRailCard({
    super.key,
    required this.biz,
    required this.shift,
    required this.onOpenShift,
    this.onCashIn,
    this.onCashOut,
    required this.onCloseShift,
  });

  final BusinessConfig biz;
  final Map<String, dynamic>? shift;
  final VoidCallback onOpenShift;
  final VoidCallback? onCashIn;
  final VoidCallback? onCashOut;
  final VoidCallback onCloseShift;

  @override
  Widget build(BuildContext context) {
    final isOpen = shift != null;
    final totals = shift?['totals'] as Map<String, dynamic>?;
    final expected = totals != null ? jsonToDouble(totals['expected_cash']) : 0.0;
    final opening = shift != null ? jsonToDouble(shift!['opening_cash']) : 0.0;
    final cashSales = totals != null ? jsonToDouble(totals['cash_sales']) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOpen ? CashierTheme.accentSubtle(context) : CashierTheme.surfaceSecondary(context),
        borderRadius: BorderRadius.circular(CashierTheme.radiusCard),
        border: Border.all(
          color: isOpen ? CashierTheme.accent(context).withValues(alpha: 0.35) : CashierTheme.border(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                isOpen ? Icons.lock_open_rounded : Icons.lock_outline,
                size: 18,
                color: isOpen ? CashierTheme.accent(context) : CashierTheme.textTertiary(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isOpen ? 'Növbə açıq' : 'Növbə bağlı',
                  style: CashierTheme.stationTitle(context, size: 13),
                ),
              ),
            ],
          ),
          if (isOpen) ...[
            const SizedBox(height: 8),
            Text('Gözlənilən kassa', style: CashierTheme.caption(context)),
            MoneyText(
              amount: expected,
              size: MoneySize.small,
              suffix: ' ${biz.currency}',
              color: CashierTheme.accent(context),
            ),
            const SizedBox(height: 4),
            Text(
              'Başlanğıc ${opening.toStringAsFixed(2)} · Satış ${cashSales.toStringAsFixed(2)}',
              style: CashierTheme.caption(context),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onCashIn,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Nağd əlavə', style: TextStyle(fontSize: 11)),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCashOut,
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    ),
                    child: const Text('Pul çıxar', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onCloseShift,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: const Text('Növbəni bağla', style: TextStyle(fontSize: 12)),
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Satış üçün əvvəlcə növbəni açın',
              style: CashierTheme.caption(context),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onOpenShift,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Növbəni aç'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
