import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/utils/json_parse.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../services/pos_service.dart';
import 'admin_page_layout.dart';

class SpendDiscountPanel extends ConsumerStatefulWidget {
  const SpendDiscountPanel({super.key});

  @override
  ConsumerState<SpendDiscountPanel> createState() => SpendDiscountPanelState();
}

class SpendDiscountPanelState extends ConsumerState<SpendDiscountPanel> {
  List<dynamic> _rules = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() => _loading = true);
    try {
      _rules = await ref.read(posServiceProvider).getSpendDiscountRules();
    } catch (_) {
      _rules = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> showCreateForm() => _showForm();

  Future<void> _showForm({Map<String, dynamic>? rule}) async {
    final isEdit = rule != null;
    final nameCtrl = TextEditingController(text: rule?['name'] as String? ?? '');
    final spendCtrl = TextEditingController(
      text: rule != null ? jsonToDouble(rule['min_spend']).toStringAsFixed(0) : '100',
    );
    final valueCtrl = TextEditingController(
      text: rule != null ? jsonToDouble(rule['discount_value']).toStringAsFixed(0) : '10',
    );
    final daysCtrl = TextEditingController(text: '${rule?['window_days'] ?? 30}');
    var window = rule?['window_type'] as String? ?? 'lifetime';
    var discountType = rule?['discount_type'] as String? ?? 'percent';
    var appliesTo = rule?['applies_to'] as String? ?? 'all';
    var isActive = rule?['is_active'] != false;

    final ok = await showAppDialog<bool>(
      context: context,
      title: isEdit ? 'Xərc endirimini düzəlt' : 'Xərc endirimi',
      subtitle: 'Məsələn, 100 manatdan çox xərcləyənə bu ay 10%',
      maxWidth: 480,
      body: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(controller: nameCtrl, label: 'Ad'),
              const SizedBox(height: AppSpacing.md),
              AppTextField(controller: spendCtrl, label: 'Minimum xərc (₼)', keyboardType: TextInputType.number),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'lifetime', label: Text('Daimi')),
                  ButtonSegment(value: 'calendar_month', label: Text('Bu ay')),
                  ButtonSegment(value: 'rolling_days', label: Text('Son günlər')),
                ],
                selected: {window},
                onSelectionChanged: (s) => setDialogState(() => window = s.first),
              ),
              if (window == 'rolling_days') ...[
                const SizedBox(height: AppSpacing.md),
                AppTextField(controller: daysCtrl, label: 'Son neçə gün', keyboardType: TextInputType.number),
              ],
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'percent', label: Text('Faiz %')),
                  ButtonSegment(value: 'fixed', label: Text('Məbləğ ₼')),
                ],
                selected: {discountType},
                onSelectionChanged: (s) => setDialogState(() => discountType = s.first),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(controller: valueCtrl, label: 'Endirim', keyboardType: TextInputType.number),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('Hamısı')),
                  ButtonSegment(value: 'time_only', label: Text('Yalnız vaxt')),
                ],
                selected: {appliesTo},
                onSelectionChanged: (s) => setDialogState(() => appliesTo = s.first),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktiv'),
                value: isActive,
                onChanged: (v) => setDialogState(() => isActive = v),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Saxla')),
      ],
    );
    if (ok != true || !mounted) return;

    final payload = {
      'name': nameCtrl.text.trim(),
      'min_spend': double.tryParse(spendCtrl.text.replaceAll(',', '.')) ?? 0,
      'window_type': window,
      'window_days': int.tryParse(daysCtrl.text) ?? 30,
      'discount_type': discountType,
      'discount_value': double.tryParse(valueCtrl.text.replaceAll(',', '.')) ?? 0,
      'applies_to': appliesTo,
      'is_active': isActive,
    };
    nameCtrl.dispose();
    spendCtrl.dispose();
    valueCtrl.dispose();
    daysCtrl.dispose();
    if ((payload['name'] as String).isEmpty || (payload['discount_value'] as double) <= 0) {
      showAppSnackBar(context, 'Ad və endirim dəyəri tələb olunur', isError: true);
      return;
    }

    try {
      final service = ref.read(posServiceProvider);
      if (isEdit) {
        await service.updateSpendDiscountRule(jsonToInt(rule['id']), payload);
      } else {
        await service.createSpendDiscountRule(payload);
      }
      await reload();
      if (mounted) showAppSnackBar(context, isEdit ? 'Yeniləndi' : 'Əlavə edildi');
    } catch (e) {
      if (mounted) showAppSnackBar(context, ApiClient.messageFromError(e), isError: true);
    }
  }

  String _windowLabel(Map<String, dynamic> rule) {
    return switch (rule['window_type']) {
      'calendar_month' => 'bu ay',
      'rolling_days' => 'son ${rule['window_days'] ?? ''} gün',
      _ => 'daimi',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (_rules.isEmpty) {
      return const EmptyState(
        icon: Icons.savings_outlined,
        title: 'Xərc endirimi yoxdur',
        subtitle: '100 manatdan çox xərcləyənə endirim qoyun',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      itemCount: _rules.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final rule = _rules[i] as Map<String, dynamic>;
        final type = rule['discount_type'] == 'fixed'
            ? '${jsonToDouble(rule['discount_value']).toStringAsFixed(2)} ₼'
            : '${jsonToDouble(rule['discount_value']).toStringAsFixed(0)}%';
        return AdminListTile(
          leading: CircleAvatar(
            backgroundColor: BrandColors.brightBlue.withValues(alpha: 0.12),
            child: Icon(Icons.savings_outlined, color: BrandColors.brightBlue, size: 20),
          ),
          title: rule['name'] as String? ?? '',
          subtitle:
              '${jsonToDouble(rule['min_spend']).toStringAsFixed(0)} ₼+ · ${_windowLabel(rule)} · $type',
          onTap: () => _showForm(rule: rule),
          onDelete: () async {
            await ref.read(posServiceProvider).deleteSpendDiscountRule(jsonToInt(rule['id']));
            await reload();
          },
        );
      },
    );
  }
}
