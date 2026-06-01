import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/json_parse.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/empty_state.dart';
import '../../services/pos_service.dart';
import 'widgets/admin_page_layout.dart';
import 'widgets/customer_groups_panel.dart';

enum DiscountAdminTab { packages, customerGroups }

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

  List<dynamic> _promotions = [];
  List<String> _tariffNames = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final service = ref.read(posServiceProvider);
    final results = await Future.wait([service.getPromotions(), service.getTables()]);
    _promotions = results[0];
    final tables = results[1];
    final names = <String>{};
    for (final raw in tables) {
      final table = raw as Map<String, dynamic>;
      for (final t in (table['tariffs'] as List<dynamic>? ?? [])) {
        final name = (t as Map)['name']?.toString().trim();
        if (name != null && name.isNotEmpty) names.add(name);
      }
    }
    _tariffNames = names.toList()..sort();
    if (mounted) setState(() => _loading = false);
  }

  void _onPrimaryAction() {
    if (_tab == DiscountAdminTab.customerGroups) {
      _groupsPanelKey.currentState?.showCreateForm();
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
    var isActive = promo?['is_active'] != false;
    final selectedTariffs = <String>{
      ...((promo?['tariff_names'] as List<dynamic>? ?? []).map((e) => e.toString())),
    };

    final ok = await showAppDialog<bool>(
      context: context,
      title: isEdit ? 'Endirim paketini redaktə et' : 'Yeni endirim paketi',
      subtitle: 'Yalnız PlayStation vaxt haqqına tətbiq olunur',
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
                Text('Hədəf masalar', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all_tables', label: Text('Bütün masalar')),
                    ButtonSegment(value: 'tariffs', label: Text('Tarif seçimi')),
                  ],
                  selected: {scope},
                  onSelectionChanged: (s) => setDialogState(() => scope = s.first),
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
    if (scope == 'tariffs' && selectedTariffs.isEmpty) {
      showAppSnackBar(context, 'Ən azı bir tarif seçin', isError: true);
      return;
    }

    final payload = {
      'name': nameCtrl.text.trim(),
      'discount_type': discountType,
      'discount_value': value,
      'scope': scope,
      'tariff_names': selectedTariffs.toList(),
      'is_active': isActive,
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

  Future<void> _toggleActive(Map<String, dynamic> promo) async {
    try {
      await ref.read(posServiceProvider).updatePromotion(jsonToInt(promo['id']), {
        'is_active': !(promo['is_active'] == true),
      });
      await _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
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
        ],
        selected: {_tab},
        onSelectionChanged: (selection) {
          setState(() => _tab = selection.first);
          if (_tab == DiscountAdminTab.customerGroups) {
            _groupsPanelKey.currentState?.reload();
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
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final p = _promotions[i] as Map<String, dynamic>;
        final active = p['is_active'] == true;
        final type = p['discount_type'] as String? ?? 'percent';
        final value = jsonToDouble(p['discount_value']);
        final scope = p['scope'] as String? ?? 'all_tables';
        final scopeLabel =
            scope == 'all_tables' ? 'Bütün masalar' : (p['tariff_names'] as List<dynamic>? ?? []).join(', ');

        return AdminListTile(
          leading: CircleAvatar(
            backgroundColor: active ? AppColors.accentSoft : AppColors.surfaceElevated,
            child: Icon(
              Icons.local_offer_outlined,
              color: active ? AppColors.accent : AppColors.textMuted,
              size: 20,
            ),
          ),
          title: p['name'] as String? ?? '',
          subtitle: '${type == 'percent' ? '${value.toStringAsFixed(0)}%' : '${value.toStringAsFixed(2)} ₼'} · $scopeLabel',
          trailing: Switch(
            value: active,
            onChanged: (_) => _toggleActive(p),
          ),
          onTap: () => _showPackageForm(promo: p),
          onDelete: () async {
            await ref.read(posServiceProvider).deletePromotion(jsonToInt(p['id']));
            await _load();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGroups = _tab == DiscountAdminTab.customerGroups;

    return AdminPageLayout(
      title: 'Endirimlər',
      subtitle: isGroups
          ? 'Müştəri qrupları — VIP, tələbə, korporativ'
          : 'Endirim paketləri — xüsusi gün və tarif endirimləri',
      action: FilledButton.icon(
        onPressed: _onPrimaryAction,
        icon: Icon(isGroups ? Icons.group_add_outlined : Icons.add, size: 20),
        label: Text(isGroups ? 'Qrup əlavə et' : 'Paket əlavə et'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tabSwitcher(),
          Expanded(
            child: isGroups
                ? CustomerGroupsPanel(key: _groupsPanelKey)
                : _packagesBody(),
          ),
        ],
      ),
    );
  }
}

/// Geriyə uyğunluq.
typedef PromotionsScreen = DiscountsScreen;
