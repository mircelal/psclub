import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/cashier_theme.dart';
import '../../../core/utils/json_parse.dart';

Future<void> showCashierShiftJournal(BuildContext context, Map<String, dynamic> shift) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _CashierShiftJournal(shift: shift),
  );
}

class _CashierShiftJournal extends StatefulWidget {
  const _CashierShiftJournal({required this.shift});

  final Map<String, dynamic> shift;

  @override
  State<_CashierShiftJournal> createState() => _CashierShiftJournalState();
}

class _CashierShiftJournalState extends State<_CashierShiftJournal> {
  final Set<int> _open = {};

  @override
  Widget build(BuildContext context) {
    final notes = widget.shift['notes']?.toString().trim() ?? '';
    final activity = (widget.shift['activity'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text('Növbə jurnalı', style: Theme.of(context).textTheme.titleLarge),
            ),
            if (notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text('Qeyd: $notes', style: CashierTheme.caption(context)),
              ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: activity.length,
                itemBuilder: (context, i) {
                  final row = activity[i];
                  final lines = (row['lines'] as List<dynamic>? ?? []);
                  final open = _open.contains(i);
                  return ListTile(
                    title: Text(row['title']?.toString() ?? ''),
                    subtitle: open && lines.isNotEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: lines.map((raw) {
                              final line = raw as Map<String, dynamic>;
                              final amount = line['amount'];
                              final suffix = amount == null ? '' : ' · ${jsonToDouble(amount).toStringAsFixed(2)}';
                              return Text('${line['label'] ?? ''}$suffix', style: CashierTheme.caption(context));
                            }).toList(),
                          )
                        : null,
                    trailing: lines.isEmpty
                        ? null
                        : Icon(open ? Icons.expand_less : Icons.expand_more),
                    onTap: lines.isEmpty
                        ? null
                        : () => setState(() {
                              if (open) {
                                _open.remove(i);
                              } else {
                                _open.add(i);
                              }
                            }),
                  );
                },
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Bağla')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
