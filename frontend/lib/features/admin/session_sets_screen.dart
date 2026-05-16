import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/json_parse.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/product_picker_field.dart';
import '../../services/pos_service.dart';
import 'widgets/admin_page_layout.dart';

class SessionSetsScreen extends ConsumerStatefulWidget {
  const SessionSetsScreen({super.key});

  @override
  ConsumerState<SessionSetsScreen> createState() => _SessionSetsScreenState();
}

class _SessionSetsScreenState extends ConsumerState<SessionSetsScreen> {
  List<dynamic> _sets = [];
  List<dynamic> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final service = ref.read(posServiceProvider);
    final results = await Future.wait([service.getSessionSets(), service.getProducts()]);
    _sets = results[0];
    _products = results[1];
    setState(() => _loading = false);
  }

  Future<void> _showForm({Map<String, dynamic>? set}) async {
    final isEdit = set != null;
    final nameCtrl = TextEditingController(text: set?['name'] as String? ?? '');
    final descCtrl = TextEditingController(text: set?['description'] as String? ?? '');
    final priceCtrl = TextEditingController(
      text: set != null ? jsonToDouble(set['fixed_price']).toStringAsFixed(2) : '',
    );
    final minutesCtrl = TextEditingController(
      text: set?['planned_minutes']?.toString() ?? '120',
    );

    final rows = <_SetItemRow>[];
    final existingItems = (set?['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    if (existingItems.isNotEmpty) {
      for (final i in existingItems) {
        rows.add(_SetItemRow(
          productId: jsonToInt(i['product_id']),
          quantity: jsonToInt(i['quantity'], 1),
        ));
      }
    } else {
      rows.add(_SetItemRow());
    }

    final productMaps = _products.cast<Map<String, dynamic>>();

    final ok = await showAppDialog<bool>(
      context: context,
      title: isEdit ? 'Paketi redaktə et' : 'Yeni paket',
      subtitle: 'Məhsullar + vaxt + sabit qiymət (restoran seti kimi)',
      icon: Icons.restaurant_menu,
      maxWidth: 560,
      body: StatefulBuilder(
        builder: (context, setDialogState) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(controller: nameCtrl, label: 'Paket adı', hint: 'VIP 2 saat'),
                const SizedBox(height: AppSpacing.md),
                AppTextField(controller: descCtrl, label: 'Təsvir (istəyə bağlı)'),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: priceCtrl,
                        label: 'Qiymət (₼)',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppTextField(
                        controller: minutesCtrl,
                        label: 'Vaxt (dəqiqə)',
                        hint: '120',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(child: Text('Daxil olan məhsullar', style: Theme.of(context).textTheme.titleSmall)),
                    TextButton.icon(
                      onPressed: () => setDialogState(() => rows.add(_SetItemRow())),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Məhsul'),
                    ),
                  ],
                ),
                ...rows.asMap().entries.map((entry) {
                  final i = entry.key;
                  final row = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ProductPickerField(
                            products: productMaps,
                            selectedId: row.productId > 0 ? row.productId : null,
                            label: i == 0 ? 'Məhsul' : 'Məhsul ${i + 1}',
                            onSelected: (v) => setDialogState(() => row.productId = v ?? 0),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        SizedBox(
                          width: 80,
                          child: AppTextField(
                            controller: row.qtyCtrl,
                            label: i == 0 ? 'Say' : null,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        if (rows.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: IconButton(
                              onPressed: () => setDialogState(() {
                                row.dispose();
                                rows.removeAt(i);
                              }),
                              icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(isEdit ? 'Yadda saxla' : 'Yarat')),
      ],
    );

    if (ok != true) {
      nameCtrl.dispose();
      descCtrl.dispose();
      priceCtrl.dispose();
      minutesCtrl.dispose();
      for (final r in rows) {
        r.dispose();
      }
      return;
    }

    final items = <Map<String, dynamic>>[];
    for (final row in rows) {
      final qty = int.tryParse(row.qtyCtrl.text) ?? 0;
      if (row.productId > 0 && qty > 0) {
        items.add({'product_id': row.productId, 'quantity': qty});
      }
    }
    for (final r in rows) {
      r.dispose();
    }

    if (items.isEmpty) {
      if (mounted) showAppSnackBar(context, 'Ən azı bir məhsul seçin', isError: true);
      nameCtrl.dispose();
      descCtrl.dispose();
      priceCtrl.dispose();
      minutesCtrl.dispose();
      return;
    }

    final price = double.tryParse(priceCtrl.text.replaceAll(',', '.'));
    final minutes = int.tryParse(minutesCtrl.text);
    final payload = {
      'name': nameCtrl.text.trim(),
      'description': descCtrl.text.trim(),
      'fixed_price': price ?? 0,
      if (minutes != null && minutes > 0) 'planned_minutes': minutes,
      'items': items,
    };

    nameCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
    minutesCtrl.dispose();

    final service = ref.read(posServiceProvider);
    if (isEdit) {
      await service.updateSessionSet(jsonToInt(set['id']), payload);
    } else {
      await service.createSessionSet(payload);
    }
    ref.invalidate(sessionSetsProvider);
    _load();
    if (mounted) showAppSnackBar(context, isEdit ? 'Paket yeniləndi' : 'Paket yaradıldı');
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageLayout(
      title: 'Paketlər (Set)',
      subtitle: 'Məhsul + vaxt + sabit qiymət — kassir masa açanda seçir',
      action: FilledButton.icon(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Paket əlavə et'),
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _sets.isEmpty
              ? const EmptyState(
                  icon: Icons.restaurant_menu_outlined,
                  title: 'Paket yoxdur',
                  subtitle: 'İlk paketi əlavə edin — məs: 2 saat + içkilər 25 ₼',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  itemCount: _sets.length,
                  itemBuilder: (_, i) {
                    final s = _sets[i] as Map<String, dynamic>;
                    final items = (s['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
                    final minutes = jsonToIntOrNull(s['planned_minutes']);
                    final itemText = items
                        .map((it) {
                          final q = jsonToInt(it['quantity'], 1);
                          final n = it['product_name'] as String? ?? '';
                          return q > 1 ? '$n ×$q' : n;
                        })
                        .join(', ');

                    return AdminListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.accentSoft,
                        child: Text(
                          '${jsonToDouble(s['fixed_price']).toStringAsFixed(0)}',
                          style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                      title: s['name'] as String? ?? '',
                      subtitle: [
                        if (minutes != null) '${minutes ~/ 60 > 0 ? "${minutes ~/ 60} saat" : "$minutes dəq"}',
                        '${jsonToDouble(s['fixed_price']).toStringAsFixed(2)} ₼',
                        if (itemText.isNotEmpty) itemText,
                      ].join(' · '),
                      onTap: () => _showForm(set: s),
                      onDelete: () async {
                        await ref.read(posServiceProvider).deleteSessionSet(jsonToInt(s['id']));
                        ref.invalidate(sessionSetsProvider);
                        _load();
                      },
                    );
                  },
                ),
    );
  }
}

class _SetItemRow {
  _SetItemRow({this.productId = 0, int quantity = 1}) : qtyCtrl = TextEditingController(text: '$quantity');

  int productId;
  final TextEditingController qtyCtrl;

  void dispose() => qtyCtrl.dispose();
}
