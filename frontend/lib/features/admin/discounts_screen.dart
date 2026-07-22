import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/cashier_theme.dart';
import '../../core/utils/json_parse.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/product_picker_field.dart';
import '../../services/pos_service.dart';
import 'widgets/admin_page_layout.dart';
import 'widgets/customer_groups_panel.dart';
import 'widgets/loyalty_tiers_panel.dart';

enum DiscountAdminTab { packages, customerGroups, loyalty }

/// Bütün endirim növləri — paketlər və müştəri qrupları.
class DiscountsScreen extends ConsumerStatefulWidget {
  const DiscountsScreen({super.key, this.initialTab = DiscountAdminTab.packages});

  final DiscountAdminTab initialTab;

  @override
  ConsumerState<DiscountsScreen> createState() => _DiscountsScreenState();
}

class _DiscountsScreenState extends ConsumerState<DiscountsScreen> {
  late DiscountAdminTab _tab;
  final _groupsPanelKey = GlobalKey<CustomerGroupsPanelState>();
  final _loyaltyPanelKey = GlobalKey<LoyaltyTiersPanelState>();

  List<dynamic> _promotions = [];
  List<String> _tariffNames = [];
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final service = ref.read(posServiceProvider);
      final results = await Future.wait([
        service.getPromotions(),
        service.getTables(),
        service.getProducts(),
      ]);
      if (!mounted) return;
      _promotions = results[0];
      final tables = results[1];
      _products = (results[2] as List).cast<Map<String, dynamic>>();
      final names = <String>{};
      for (final raw in tables) {
        final table = raw as Map<String, dynamic>;
        for (final t in (table['tariffs'] as List<dynamic>? ?? [])) {
          final name = (t as Map)['name']?.toString().trim();
          if (name != null && name.isNotEmpty) names.add(name);
        }
      }
      _tariffNames = names.toList()..sort();
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, ApiClient.messageFromError(e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _productName(int id) {
    for (final p in _products) {
      if (jsonToInt(p['id']) == id) {
        return p['name'] as String? ?? '#$id';
      }
    }
    return '#$id';
  }

  void _onPrimaryAction() {
    if (_tab == DiscountAdminTab.customerGroups) {
      _groupsPanelKey.currentState?.showCreateForm();
    } else if (_tab == DiscountAdminTab.loyalty) {
      _loyaltyPanelKey.currentState?.showCreateForm();
    } else {
      _showPackageForm();
    }
  }

  Future<void> _showPackageForm({Map<String, dynamic>? promo}) async {
    final isEdit = promo != null;
    final nameCtrl = TextEditingController(text: promo?['name'] as String? ?? '');
    final valueCtrl = TextEditingController(
      text: promo != null ? jsonToDouble(promo['discount_value']).toStringAsFixed(0) : '',
    );
    var discountType = promo?['discount_type'] as String? ?? 'percent';
    var scope = promo?['scope'] as String? ?? 'all_tables';
    var isActive = jsonIsActive(promo?['is_active']);
    final selectedTariffs = <String>{
      ...((promo?['tariff_names'] as List<dynamic>? ?? []).map((e) => e.toString())),
    };
    final selectedProductIds = <int>[
      ...((promo?['product_ids'] as List<dynamic>? ?? []).map((e) => jsonToInt(e)).where((id) => id > 0)),
    ];
    if (selectedProductIds.isEmpty && scope == 'products') {
      selectedProductIds.add(0);
    }
    final selectedDays = <int>{
      ...((promo?['valid_days'] as List<dynamic>? ?? []).map((e) => jsonToInt(e))),
    };
    final hourRanges = <Map<String, String>>[
      ...((promo?['valid_hours'] as List<dynamic>? ?? []).map((e) {
        final m = e as Map<String, dynamic>;
        return <String, String>{'from': (m['from'] ?? '').toString(), 'until': (m['until'] ?? '').toString()};
      })),
    ];

    final ok = await showAppDialog<bool>(
      context: context,
      title: isEdit ? 'Endirim paketini redaktə et' : 'Yeni endirim paketi',
      subtitle: 'Masa vaxtı və ya seçilmiş məhsullara tətbiq olunur',
      icon: Icons.local_offer_outlined,
      maxWidth: 520,
      body: StatefulBuilder(
        builder: (context, setDialogState) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(controller: nameCtrl, label: 'Paket adı', hint: 'Uşaqlar günü 50%'),
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
                AppTextField(
                  controller: valueCtrl,
                  label: discountType == 'percent' ? 'Faiz' : 'Məbləğ (₼)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Hədəf', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all_tables', label: Text('Masalar')),
                    ButtonSegment(value: 'tariffs', label: Text('Tarif')),
                    ButtonSegment(value: 'products', label: Text('Məhsullar')),
                  ],
                  selected: {scope},
                  onSelectionChanged: (s) => setDialogState(() {
                    scope = s.first;
                    if (scope == 'products' && selectedProductIds.isEmpty) {
                      selectedProductIds.add(0);
                    }
                  }),
                ),
                if (scope == 'tariffs') ...[
                  const SizedBox(height: AppSpacing.md),
                  if (_tariffNames.isEmpty)
                    Text(
                      'Tarif tapılmadı — əvvəlcə masaları konfiqurasiya edin',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _tariffNames.map((name) {
                        final selected = selectedTariffs.contains(name);
                        return FilterChip(
                          label: Text(name),
                          selected: selected,
                          onSelected: (v) => setDialogState(() {
                            if (v) {
                              selectedTariffs.add(name);
                            } else {
                              selectedTariffs.remove(name);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                ],
                if (scope == 'products') ...[
                  const SizedBox(height: AppSpacing.md),
                  if (_products.isEmpty)
                    Text(
                      'Məhsul tapılmadı — əvvəlcə məhsul əlavə edin',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else ...[
                    ...selectedProductIds.asMap().entries.map((entry) {
                      final i = entry.key;
                      final productId = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ProductPickerField(
                                products: _products,
                                selectedId: productId > 0 ? productId : null,
                                onSelected: (id) => setDialogState(() {
                                  selectedProductIds[i] = id ?? 0;
                                }),
                              ),
                            ),
                            IconButton(
                              onPressed: selectedProductIds.length <= 1
                                  ? null
                                  : () => setDialogState(() => selectedProductIds.removeAt(i)),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: () => setDialogState(() => selectedProductIds.add(0)),
                      icon: const Icon(Icons.add),
                      label: const Text('Məhsul əlavə et'),
                    ),
                  ],
                ],
                const SizedBox(height: AppSpacing.lg),
                Text('Günlər (boş = hər gün)', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _DayChip(0, 'B.E.'),
                    _DayChip(1, 'Ç.A.'),
                    _DayChip(2, 'Ç.'),
                    _DayChip(3, 'C.A.'),
                    _DayChip(4, 'C.'),
                    _DayChip(5, 'Ş.'),
                    _DayChip(6, 'B.'),
                  ].map((chip) {
                    final selected = selectedDays.contains(chip.value);
                    return FilterChip(
                      label: Text(chip.label),
                      selected: selected,
                      onSelected: (v) => setDialogState(() {
                        if (v) {
                          selectedDays.add(chip.value);
                        } else {
                          selectedDays.remove(chip.value);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Saat aralıqları (boş = bütün gün)', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                ...hourRanges.asMap().entries.map((entry) {
                  final i = entry.key;
                  final range = entry.value;
                  final fromCtrl = TextEditingController(text: range['from']);
                  final untilCtrl = TextEditingController(text: range['until']);
                  return Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: fromCtrl,
                          label: 'Başlanğıc',
                          hint: '09:00',
                          onChanged: (v) => range['from'] = v,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppTextField(
                          controller: untilCtrl,
                          label: 'Bitiş',
                          hint: '18:00',
                          onChanged: (v) => range['until'] = v,
                        ),
                      ),
                      IconButton(
                        onPressed: () => setDialogState(() => hourRanges.removeAt(i)),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  );
                }),
                TextButton.icon(
                  onPressed: () => setDialogState(() => hourRanges.add({'from': '', 'until': ''})),
                  icon: const Icon(Icons.add),
                  label: const Text('Aralıq əlavə et'),
                ),
                const SizedBox(height: AppSpacing.lg),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktiv'),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                ),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Saxla')),
      ],
    );

    if (ok != true || !mounted) return;

    final value = double.tryParse(valueCtrl.text.replaceAll(',', '.')) ?? 0;
    if (nameCtrl.text.trim().isEmpty || value <= 0) {
      showAppSnackBar(context, 'Ad və endirim dəyəri tələb olunur', isError: true);
      return;
    }
    if (discountType == 'percent' && value > 100) {
      showAppSnackBar(context, 'Faiz 100-dən çox ola bilməz', isError: true);
      return;
    }
    if (scope == 'tariffs' && selectedTariffs.isEmpty) {
      showAppSnackBar(context, 'Ən azı bir tarif seçin', isError: true);
      return;
    }
    final productIds = selectedProductIds.where((id) => id > 0).toSet().toList();
    if (scope == 'products' && productIds.isEmpty) {
      showAppSnackBar(context, 'Ən azı bir məhsul seçin', isError: true);
      return;
    }

    final payload = {
      'name': nameCtrl.text.trim(),
      'discount_type': discountType,
      'discount_value': value,
      'scope': scope,
      'tariff_names': scope == 'tariffs' ? selectedTariffs.toList() : <String>[],
      'product_ids': scope == 'products' ? productIds : <int>[],
      'is_active': isActive,
      'valid_days': selectedDays.toList(),
      'valid_hours': hourRanges
          .where((r) => (r['from'] ?? '').isNotEmpty && (r['until'] ?? '').isNotEmpty)
          .map((r) => {'from': r['from']!, 'until': r['until']!})
          .toList(),
    };

    try {
      if (isEdit) {
        await ref.read(posServiceProvider).updatePromotion(jsonToInt(promo['id']), payload);
      } else {
        await ref.read(posServiceProvider).createPromotion(payload);
      }
      await _load();
      if (mounted) showAppSnackBar(context, isEdit ? 'Yeniləndi' : 'Əlavə edildi');
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  Future<void> _deletePackage(Map<String, dynamic> promo) async {
    final name = promo['name'] as String? ?? 'Endirim paketi';
    final confirm = await showAppDialog<bool>(
      context: context,
      title: 'Endirim paketini sil',
      subtitle: 'Paket tam silinəcək',
      icon: Icons.delete_outline,
      body: Text('“$name” silinsin?', style: Theme.of(context).textTheme.bodyMedium),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Xeyr')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AdminTheme.danger(context)),
          child: const Text('Sil'),
        ),
      ],
    );
    if (confirm != true) return;

    try {
      await ref.read(posServiceProvider).deletePromotion(jsonToInt(promo['id']));
      await _load();
      if (mounted) showAppSnackBar(context, 'Endirim paketi silindi');
    } catch (e) {
      if (mounted) showAppSnackBar(context, ApiClient.messageFromError(e), isError: true);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> promo) async {
    try {
      await ref.read(posServiceProvider).updatePromotion(jsonToInt(promo['id']), {
        'is_active': !jsonIsActive(promo['is_active']),
      });
      await _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  Widget _closeButton({required VoidCallback onPressed, String tooltip = 'Bağla'}) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: const Icon(Icons.close, size: 22),
      style: IconButton.styleFrom(
        foregroundColor: CashierTheme.textSecondary(context),
      ),
    );
  }

  Widget? _headerLeading(BuildContext context) {
    if (Navigator.canPop(context)) {
      return null;
    }
    if (_tab == DiscountAdminTab.customerGroups || _tab == DiscountAdminTab.loyalty) {
      return _closeButton(
        onPressed: () => setState(() => _tab = DiscountAdminTab.packages),
        tooltip: 'Endirim paketlərinə qayıt',
      );
    }
    return null;
  }

  Widget _tabSwitcher() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.sm),
      child: SegmentedButton<DiscountAdminTab>(
        segments: const [
          ButtonSegment(
            value: DiscountAdminTab.packages,
            label: Text('Endirim paketləri'),
            icon: Icon(Icons.local_offer_outlined, size: 18),
          ),
          ButtonSegment(
            value: DiscountAdminTab.customerGroups,
            label: Text('Müştəri qrupları'),
            icon: Icon(Icons.groups_outlined, size: 18),
          ),
          ButtonSegment(
            value: DiscountAdminTab.loyalty,
            label: Text('Loyallıq'),
            icon: Icon(Icons.card_giftcard_outlined, size: 18),
          ),
        ],
        selected: {_tab},
        onSelectionChanged: (selection) {
          setState(() => _tab = selection.first);
          if (_tab == DiscountAdminTab.customerGroups) {
            _groupsPanelKey.currentState?.reload();
          } else if (_tab == DiscountAdminTab.loyalty) {
            _loyaltyPanelKey.currentState?.reload();
          }
        },
      ),
    );
  }

  Widget _packagesBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_promotions.isEmpty) {
      return const EmptyState(
        icon: Icons.local_offer_outlined,
        title: 'Endirim paketi yoxdur',
        subtitle: 'Məsələn, «Uşaqlar günü 50%» yaradın',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      itemCount: _promotions.length,
      separatorBuilder: (_, ___) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final p = _promotions[i] as Map<String, dynamic>;
        final active = jsonIsActive(p['is_active']);
        final type = p['discount_type'] as String? ?? 'percent';
        final value = jsonToDouble(p['discount_value']);
        final scope = p['scope'] as String? ?? 'all_tables';
        final String scopeLabel;
        if (scope == 'products') {
          final ids = (p['product_ids'] as List<dynamic>? ?? []).map((e) => jsonToInt(e)).where((id) => id > 0);
          scopeLabel = ids.isEmpty ? 'Məhsullar' : ids.map(_productName).join(', ');
        } else if (scope == 'all_tables') {
          scopeLabel = 'Bütün masalar';
        } else {
          scopeLabel = (p['tariff_names'] as List<dynamic>? ?? []).join(', ');
        }
        final days = p['valid_days'] as List<dynamic>? ?? [];
        final hours = p['valid_hours'] as List<dynamic>? ?? [];
        final daysLabel = days.isEmpty
            ? 'hər gün'
            : days.map((d) => const ['B.E.', 'Ç.A.', 'Ç.', 'C.A.', 'C.', 'Ş.', 'B.'][jsonToInt(d)]).join(', ');
        final hoursLabel = hours.isEmpty ? 'bütün gün' : hours.map((h) => '${h['from']}-${h['until']}').join(', ');

        return AdminListTile(
          leading: CircleAvatar(
            backgroundColor: active
                ? CashierTheme.accentSubtle(context)
                : CashierTheme.surfaceSecondary(context),
            child: Icon(
              scope == 'products' ? Icons.shopping_bag_outlined : Icons.local_offer_outlined,
              color: active ? CashierTheme.accent(context) : CashierTheme.textTertiary(context),
              size: 20,
            ),
          ),
          title: p['name'] as String? ?? '',
          subtitle:
              '${type == 'percent' ? '${value.toStringAsFixed(0)}%' : '${value.toStringAsFixed(2)} ₼'} · $scopeLabel · $daysLabel · $hoursLabel',
          trailing: Switch(
            value: active,
            onChanged: (_) => _toggleActive(p),
          ),
          onTap: () => _showPackageForm(promo: p),
          onDelete: () => _deletePackage(p),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGroups = _tab == DiscountAdminTab.customerGroups;
    final isLoyalty = _tab == DiscountAdminTab.loyalty;
    final canPop = Navigator.canPop(context);

    final body = AdminPageLayout(
      title: 'Endirimlər',
      leading: _headerLeading(context),
      subtitle: isLoyalty
          ? 'Loyallıq proqramı — xərc həddinə görə avtomatik bonus'
          : isGroups
              ? 'Müştəri qrupları — VIP, tələbə, korporativ'
              : 'Endirim paketləri — masa, tarif və məhsul endirimləri',
      action: FilledButton.icon(
        onPressed: _onPrimaryAction,
        icon: Icon(
          isLoyalty
              ? Icons.card_giftcard_outlined
              : isGroups
                  ? Icons.group_add_outlined
                  : Icons.add,
          size: 20,
        ),
        label: Text(isLoyalty ? 'Qayda əlavə et' : isGroups ? 'Qrup əlavə et' : 'Paket əlavə et'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tabSwitcher(),
          Expanded(
            child: isLoyalty
                ? LoyaltyTiersPanel(key: _loyaltyPanelKey)
                : isGroups
                    ? CustomerGroupsPanel(key: _groupsPanelKey)
                    : _packagesBody(),
          ),
        ],
      ),
    );

    if (!canPop) return body;

    return Scaffold(
      backgroundColor: CashierTheme.surfaceMain(context),
      appBar: AppBar(
        title: Text(
          isLoyalty ? 'Loyallıq' : isGroups ? 'Müştəri qrupları' : 'Endirimlər',
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Bağla',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: body,
    );
  }
}

class _DayChip {
  const _DayChip(this.value, this.label);
  final int value;
  final String label;
}

/// Geriyə uyğunluq.
typedef PromotionsScreen = DiscountsScreen;
