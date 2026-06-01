import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/money_text.dart';

enum CounterUnpaidChoice { pay, clearCart, cancel }

/// Birbaşa satışda səbətdə məhsul varkən bağlamağa cəhd.
Future<CounterUnpaidChoice?> showCounterUnpaidDialog(
  BuildContext context, {
  required int itemCount,
  required double total,
}) {
  return showDialog<CounterUnpaidChoice>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: Theme.of(ctx).colorScheme.error, size: 32),
      title: const Text('Ödəniş alınmayıb'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Səbətdə $itemCount məhsul var (${total.toStringAsFixed(2)} ₼). '
            'Satışı açıq saxlamaq olmaz — ödəniş alın və ya səbəti tam boşaldın.',
            style: Theme.of(ctx).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Pəncərəni bağlamaq üçün mütləq birini seçin.',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(child: MoneyText(amount: total, size: MoneySize.large, suffix: ' ₼')),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, CounterUnpaidChoice.cancel),
          child: const Text('Geri qayıt'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, CounterUnpaidChoice.clearCart),
          child: const Text('Səbəti boşalt'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, CounterUnpaidChoice.pay),
          icon: const Icon(Icons.payment, size: 18),
          label: const Text('Ödənişi al'),
        ),
      ],
    ),
  );
}
