import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/cashier_theme.dart';
import '../../core/utils/json_parse.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/money_text.dart';
import '../../services/pos_service.dart';
import 'widgets/admin_page_layout.dart';

class ShiftsScreen extends ConsumerStatefulWidget {
  const ShiftsScreen({super.key});

  @override
  ConsumerState<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends ConsumerState<ShiftsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _shifts = [];
  List<dynamic> _movements = [];
  Map<String, dynamic> _categories = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final pos = ref.read(posServiceProvider);
    final from = DateTime.now().subtract(const Duration(days: 30));
    final fromStr = '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    final toStr = DateTime.now().toIso8601String().substring(0, 10);
    _categories = await pos.getShiftCategories();
    _shifts = await pos.getShifts(from: fromStr, to: toStr);
    _movements = await pos.getCashMovements(from: fromStr, to: toStr);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addExpense() async {
    final expenseCats = (_categories['expense_categories'] as Map<String, dynamic>?) ?? {};
    String type = 'expense';
    String category = expenseCats.keys.isNotEmpty ? expenseCats.keys.first as String : 'diger';
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final ok = await showAppDialog<bool>(
      context: context,
      title: 'Xərc / ödəniş əlavə et',
      subtitle: 'İnternet, işıq, vergi və s. — növbədən asılı olmaya bilər',
      icon: Icons.receipt_long_outlined,
      maxWidth: 480,
      body: StatefulBuilder(
        builder: (ctx, setDlg) => Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Növ'),
              value: type,
              items: const [
                DropdownMenuItem(value: 'expense', child: Text('Xərc (internet, işıq, vergi…)')),
                DropdownMenuItem(value: 'owner_withdrawal', child: Text('Sahibkarə verilmə')),
                DropdownMenuItem(value: 'pay_in', child: Text('Kassaya əlavə')),
              ],
              onChanged: (v) => setDlg(() => type = v ?? 'expense'),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (type == 'expense')
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Kateqoriya'),
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
              decoration: const InputDecoration(labelText: 'Qeyd'),
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Saxla')),
      ],
    );

    if (ok != true || !mounted) return;
    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) {
      showAppSnackBar(context, 'Məbləğ düzgün deyil', isError: true);
      return;
    }

    try {
      await ref.read(posServiceProvider).addAdminExpense(
            type: type,
            amount: amount,
            category: type == 'expense' ? category : null,
            description: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
          );
      if (mounted) {
        showAppSnackBar(context, 'Qeydə alındı');
        _load();
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  Future<void> _showShiftDetail(int id) async {
    final shift = await ref.read(posServiceProvider).getShift(id);
    if (!mounted) return;

    final movements = shift['movements'] as List<dynamic>? ?? [];
    final totals = shift['totals'] as Map<String, dynamic>? ?? {};
    final isOpen = shift['status'] == 'open';

    await showAppDialog<void>(
      context: context,
      title: 'Növbə #${shift['id']}',
      subtitle: isOpen ? 'Açıq' : 'Bağlı · ${shift['opened_at']}',
      icon: Icons.point_of_sale,
      maxWidth: 560,
      body: SizedBox(
        width: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _DetailLine('Operator', shift['opened_by_name']?.toString() ?? '—'),
            _DetailLine('Başlanğıc kassa', '${jsonToDouble(shift['opening_cash']).toStringAsFixed(2)} AZN'),
            if (!isOpen) ...[
              _DetailLine('Gözlənilən', '${jsonToDouble(shift['expected_cash']).toStringAsFixed(2)} AZN'),
              _DetailLine('Sayılan', '${jsonToDouble(shift['closing_cash']).toStringAsFixed(2)} AZN'),
              _DetailLine(
                'Fərq',
                '${jsonToDouble(shift['cash_difference']).toStringAsFixed(2)} AZN',
                highlight: jsonToDouble(shift['cash_difference']) != 0,
              ),
            ] else
              _DetailLine('Gözlənilən kassa', '${jsonToDouble(totals['expected_cash']).toStringAsFixed(2)} AZN'),
            const Divider(height: 24),
            Text('Hərəkətlər', style: CashierTheme.sectionTitle(context)),
            const SizedBox(height: 8),
            if (movements.isEmpty)
              Text('Hərəkət yoxdur', style: CashierTheme.caption(context))
            else
              ...movements.take(15).map((m) {
                final map = m as Map<String, dynamic>;
                final type = map['type'] as String? ?? '';
                final label = _movementLabel(type, map['category'] as String?);
                final amt = jsonToDouble(map['amount']);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(label, style: const TextStyle(fontSize: 13)),
                  subtitle: map['description'] != null ? Text(map['description'].toString(), style: CashierTheme.caption(context)) : null,
                  trailing: Text(
                    '${type == 'pay_in' ? '+' : '−'}${amt.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: type == 'pay_in' ? Colors.green.shade700 : CashierTheme.textSecondary(context),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Bağla'))],
    );
  }

  String _movementLabel(String type, String? category) {
    if (type == 'owner_withdrawal') return 'Sahibkarə verilmə';
    if (type == 'pay_in') return 'Kassaya əlavə';
    final cats = (_categories['expense_categories'] as Map<String, dynamic>?) ?? {};
    return cats[category]?.toString() ?? category ?? 'Xərc';
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageLayout(
      title: 'Növbələr və xərclər',
      subtitle: 'Kassa növbələri, nağd hərəkətləri və əməliyyat xərcləri',
      action: FilledButton.icon(
        onPressed: _addExpense,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Xərc əlavə et'),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TabBar(
                  controller: _tabs,
                  tabs: const [
                    Tab(text: 'Növbələr'),
                    Tab(text: 'Bütün hərəkətlər'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _ShiftsList(shifts: _shifts, onTap: _showShiftDetail),
                      _MovementsList(movements: _movements, labelFor: _movementLabel),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ShiftsList extends StatelessWidget {
  const _ShiftsList({required this.shifts, required this.onTap});

  final List<dynamic> shifts;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    if (shifts.isEmpty) {
      return Center(child: Text('Növbə tapılmadı', style: CashierTheme.caption(context)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: shifts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final s = shifts[i] as Map<String, dynamic>;
        final isOpen = s['status'] == 'open';
        final totals = s['totals'] as Map<String, dynamic>?;
        final expected = totals != null ? jsonToDouble(totals['expected_cash']) : jsonToDouble(s['expected_cash']);
        final diff = jsonToDouble(s['cash_difference']);

        return Card(
          child: ListTile(
            onTap: () => onTap(jsonToInt(s['id'])),
            leading: CircleAvatar(
              backgroundColor: isOpen ? Colors.green.shade50 : CashierTheme.surfaceSecondary(context),
              child: Icon(
                isOpen ? Icons.lock_open : Icons.lock,
                color: isOpen ? Colors.green.shade700 : CashierTheme.textSecondary(context),
                size: 20,
              ),
            ),
            title: Text('Növbə #${s['id']} · ${s['opened_by_name'] ?? ''}'),
            subtitle: Text(
              '${s['opened_at']}${isOpen ? ' · açıq' : ' · bağlı'}',
              style: CashierTheme.caption(context),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                MoneyText(amount: expected, size: MoneySize.small),
                if (!isOpen && diff != 0)
                  Text(
                    'Fərq: ${diff.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 11, color: diff < 0 ? Colors.red : Colors.green.shade700),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MovementsList extends StatelessWidget {
  const _MovementsList({required this.movements, required this.labelFor});

  final List<dynamic> movements;
  final String Function(String type, String? category) labelFor;

  @override
  Widget build(BuildContext context) {
    if (movements.isEmpty) {
      return Center(child: Text('Hərəkət yoxdur', style: CashierTheme.caption(context)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: movements.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final m = movements[i] as Map<String, dynamic>;
        final type = m['type'] as String? ?? '';
        final amt = jsonToDouble(m['amount']);
        final source = m['source'] == 'admin' ? 'Admin' : 'Kassir';

        return ListTile(
          title: Text(labelFor(type, m['category'] as String?)),
          subtitle: Text(
            '${m['created_at']} · $source${m['created_by_name'] != null ? ' · ${m['created_by_name']}' : ''}',
            style: CashierTheme.caption(context),
          ),
          trailing: Text(
            '${type == 'pay_in' ? '+' : '−'}${amt.toStringAsFixed(2)} AZN',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: type == 'pay_in' ? Colors.green.shade700 : null,
            ),
          ),
        );
      },
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value, {this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: CashierTheme.caption(context)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: highlight ? Colors.orange.shade800 : null,
            ),
          ),
        ],
      ),
    );
  }
}
