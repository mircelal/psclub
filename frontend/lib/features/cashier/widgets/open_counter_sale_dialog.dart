import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/customer_picker.dart';
import '../../../services/pos_service.dart';

class CounterSaleStartResult {
  CounterSaleStartResult({required this.confirmed, this.customerId});

  final bool confirmed;
  final int? customerId;
}

Future<CounterSaleStartResult?> showOpenCounterSaleDialog(BuildContext context) {
  return showDialog<CounterSaleStartResult>(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.shopping_bag_outlined, color: Theme.of(ctx).colorScheme.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text('Birbaşa satış', style: Theme.of(ctx).textTheme.titleLarge),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Masa açmadan məhsul satışı — gözləyən qonaq, kənar müştəri və s.',
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              const _CounterSaleBody(),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CounterSaleBody extends ConsumerStatefulWidget {
  const _CounterSaleBody();

  @override
  ConsumerState<_CounterSaleBody> createState() => _CounterSaleBodyState();
}

class _CounterSaleBodyState extends ConsumerState<_CounterSaleBody> {
  int? _customerId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomerPicker(
          pos: ref.read(posServiceProvider),
          selectedId: _customerId,
          onChanged: (id) => setState(() => _customerId = id),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Ləğv'),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  CounterSaleStartResult(confirmed: true, customerId: _customerId),
                ),
                icon: const Icon(Icons.point_of_sale, size: 20),
                label: const Text('Satışa başla'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
