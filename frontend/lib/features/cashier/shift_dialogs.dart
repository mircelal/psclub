import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/business_config_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/json_parse.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/money_text.dart';
import '../../services/pos_service.dart';
import 'shift_provider.dart';

Future<bool> showOpenShiftDialog(BuildContext context, WidgetRef ref) async {
  final ctrl = TextEditingController(text: '100');
  final ok = await showAppDialog<bool>(
    context: context,
    title: 'Növbəni aç',
    subtitle: 'Kassada olan nağd pulu daxil edin (dəyişiklik fond)',
    icon: Icons.point_of_sale_outlined,
    body: TextField(
      controller: ctrl,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      decoration: const InputDecoration(labelText: 'Başlanğıc kassa (AZN)'),
    ),
    actions: [
      OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv')),
      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Növbəni aç')),
    ],
  );
  if (ok != true || !context.mounted) return false;

  try {
    await ref.read(posServiceProvider).openShift(double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0);
    ref.invalidate(currentShiftProvider);
    if (context.mounted) {
      showAppSnackBar(context, 'Növbə açıldı');
    }
    return true;
  } catch (e) {
    if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
    return false;
  }
}

const _payInNoteHints = [
  'Sahibkar verdi',
  'Dəyişiklik üçün əlavə',
  'Bankdan nağd götürüldü',
  'Digər',
];

/// Kassaya nağd əlavə (sahibkar verdi, dəyişiklik və s.).
Future<void> showCashPayInDialog(BuildContext context, WidgetRef ref, int shiftId) async {
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  var selectedHint = _payInNoteHints.first;

  if (!context.mounted) return;

  final ok = await showAppDialog<bool>(
    context: context,
    title: 'Kassaya nağd əlavə',
    subtitle: 'Sahibkar və ya kassaya daxil olan əlavə pul',
    icon: Icons.add_circle_outline,
    maxWidth: 480,
    body: StatefulBuilder(
      builder: (ctx, setDlg) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: amountCtrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
            decoration: const InputDecoration(labelText: 'Məbləğ (AZN)'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Səbəb', style: Theme.of(ctx).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _payInNoteHints.map((hint) {
              final selected = selectedHint == hint;
              return ChoiceChip(
                label: Text(hint, style: const TextStyle(fontSize: 12)),
                selected: selected,
                onSelected: (_) => setDlg(() {
                  selectedHint = hint;
                  if (noteCtrl.text.isEmpty || _payInNoteHints.contains(noteCtrl.text.trim())) {
                    noteCtrl.text = hint == 'Digər' ? '' : hint;
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: noteCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Qeyd',
              hintText: 'Məs: Sahibkar Əli verdi — dəyişiklik üçün',
            ),
          ),
        ],
      ),
    ),
    actions: [
      OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv')),
      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kassaya əlavə et')),
    ],
  );

  if (ok != true || !context.mounted) return;
  final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
  if (amount <= 0) {
    showAppSnackBar(context, 'Məbləğ düzgün deyil', isError: true);
    return;
  }

  final note = noteCtrl.text.trim();
  if (note.isEmpty) {
    showAppSnackBar(context, 'Zəhmət olmasa qeyd yazın (kim verdi, nə üçün)', isError: true);
    return;
  }

  try {
    await ref.read(posServiceProvider).addShiftMovement(
      shiftId,
      type: 'pay_in',
      amount: amount,
      description: note,
    );
    ref.invalidate(currentShiftProvider);
    if (context.mounted) showAppSnackBar(context, 'Kassaya $amount AZN əlavə edildi');
  } catch (e) {
    if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
  }
}

/// Kassadan çıxarış — xərc və ya sahibkarə.
Future<void> showCashOutDialog(BuildContext context, WidgetRef ref, int shiftId) async {
  final cats = await ref.read(shiftCategoriesProvider.future);
  final expenseCats = (cats['expense_categories'] as Map<String, dynamic>?) ?? {};

  String type = 'expense';
  String category = expenseCats.keys.isNotEmpty ? expenseCats.keys.first as String : 'diger';
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  if (!context.mounted) return;

  final ok = await showAppDialog<bool>(
    context: context,
    title: 'Kassadan pul çıxar',
    subtitle: 'Xərc və ya sahibkarə verilmə',
    icon: Icons.remove_circle_outline,
    maxWidth: 480,
    body: StatefulBuilder(
      builder: (ctx, setDlg) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'expense', label: Text('Xərc')),
              ButtonSegment(value: 'owner_withdrawal', label: Text('Sahibkarə')),
            ],
            selected: {type},
            onSelectionChanged: (s) => setDlg(() => type = s.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (type == 'expense')
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Xərc növü'),
              value: category,
              items: expenseCats.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.toString())))
                  .toList(),
              onChanged: (v) => setDlg(() => category = v ?? category),
            ),
          if (type == 'expense') const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
            decoration: const InputDecoration(labelText: 'Məbləğ (AZN)'),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Qeyd',
              hintText: type == 'owner_withdrawal' ? 'Məs: Sahibkarə günün gəliri' : 'Məs: Çay, təmizlik materialları',
            ),
          ),
        ],
      ),
    ),
    actions: [
      OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv')),
      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Təsdiq')),
    ],
  );

  if (ok != true || !context.mounted) return;
  final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
  if (amount <= 0) {
    showAppSnackBar(context, 'Məbləğ düzgün deyil', isError: true);
    return;
  }

  try {
    await ref.read(posServiceProvider).addShiftMovement(
      shiftId,
      type: type,
      amount: amount,
      category: type == 'expense' ? category : null,
      description: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
    );
    ref.invalidate(currentShiftProvider);
    if (context.mounted) showAppSnackBar(context, 'Əməliyyat qeydə alındı');
  } catch (e) {
    if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
  }
}

Future<void> showCloseShiftDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> shift) async {
  final shiftId = jsonToInt(shift['id']);
  final totals = shift['totals'] as Map<String, dynamic>? ?? {};
  final expected = jsonToDouble(totals['expected_cash']);
  final opening = jsonToDouble(shift['opening_cash']);
  final cashSales = jsonToDouble(totals['cash_sales']);
  final expenses = jsonToDouble(totals['expenses']);
  final owner = jsonToDouble(totals['owner_withdrawals']);
  final payIns = jsonToDouble(totals['pay_ins']);

  final closingCtrl = TextEditingController(text: expected.toStringAsFixed(2));
  final notesCtrl = TextEditingController();
  final currency = ref.read(businessConfigProvider).valueOrNull?.currency ?? 'AZN';

  if (!context.mounted) return;

  final ok = await showAppDialog<bool>(
    context: context,
    title: 'Növbəni bağla',
    subtitle: 'Kassadakı nağdı sayın və daxil edin',
    icon: Icons.lock_clock_outlined,
    maxWidth: 520,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryRow(label: 'Başlanğıc kassa', value: opening, currency: currency),
        _SummaryRow(label: 'Nağd satışlar', value: cashSales, currency: currency),
        if (expenses > 0) _SummaryRow(label: 'Xərclər', value: -expenses, currency: currency),
        if (owner > 0) _SummaryRow(label: 'Sahibkarə', value: -owner, currency: currency),
        if (payIns > 0) _SummaryRow(label: 'Kassaya əlavə', value: payIns, currency: currency),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Gözlənilən kassa', style: TextStyle(fontWeight: FontWeight.w600)),
            MoneyText(amount: expected, size: MoneySize.medium, suffix: ' $currency'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: closingCtrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
          decoration: InputDecoration(labelText: 'Sayılan nağd ($currency)'),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: notesCtrl,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Qeyd (fərq varsa)'),
        ),
      ],
    ),
    actions: [
      OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv')),
      FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Növbəni bağla')),
    ],
  );

  if (ok != true || !context.mounted) return;

  try {
    final result = await ref.read(posServiceProvider).closeShift(
          shiftId,
          closingCash: double.tryParse(closingCtrl.text.replaceAll(',', '.')) ?? 0,
          notes: notesCtrl.text.trim(),
        );
    ref.invalidate(currentShiftProvider);
    if (!context.mounted) return;

    final summary = result['summary'] as Map<String, dynamic>? ?? {};
    final diff = jsonToDouble(summary['cash_difference']);
    final diffText = diff == 0
        ? 'Kassa uyğundur.'
        : diff > 0
            ? 'Artıq: ${diff.toStringAsFixed(2)} $currency'
            : 'Çatışmazlıq: ${diff.abs().toStringAsFixed(2)} $currency';

    await showAppDialog<void>(
      context: context,
      title: 'Növbə bağlandı',
      subtitle: diffText,
      icon: Icons.check_circle_outline,
      body: const SizedBox.shrink(),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Bağla'))],
    );
  } catch (e) {
    if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, required this.currency});

  final String label;
  final double value;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            '${value >= 0 ? '' : '−'}${value.abs().toStringAsFixed(2)} $currency',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
