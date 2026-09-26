import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/json_parse.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../services/pos_service.dart';
import 'admin_page_layout.dart';

/// Müştəri qrup endirimləri — Endirimlər hubunda və ya ayrıca ekranda.
class CustomerGroupsPanel extends ConsumerStatefulWidget {
  const CustomerGroupsPanel({super.key});

  @override
  ConsumerState<CustomerGroupsPanel> createState() => CustomerGroupsPanelState();
}

class CustomerGroupsPanelState extends ConsumerState<CustomerGroupsPanel> {
  List<dynamic> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() => _loading = true);
    try {
      _groups = await ref.read(posServiceProvider).getCustomerGroups();
    } catch (_) {
      _groups = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> showCreateForm() => _showForm();

  Future<void> _showForm({Map<String, dynamic>? group}) async {
    final isEdit = group != null;
    final nameCtrl = TextEditingController(text: group?['name'] as String? ?? '');
    final descCtrl = TextEditingController(text: group?['description'] as String? ?? '');
    final valueCtrl = TextEditingController(
      text: group != null ? jsonToDouble(group['discount_value']).toStringAsFixed(0) : '',
    );
    var discountType = group?['discount_type'] as String? ?? 'percent';
    var appliesTo = group?['applies_to'] as String? ?? 'time_only';
    var isActive = group?['is_active'] != false;

    final ok = await showAppDialog<bool>(
      context: context,
      title: isEdit ? 'Qrupu redaktə et' : 'Yeni müştəri qrupu',
      subtitle: 'VIP, tələbə, korporativ və s.',
      icon: Icons.groups_outlined,
      maxWidth: 520,
      body: StatefulBuilder(
        builder: (context, setDialogState) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(controller: nameCtrl, label: 'Qrup adı', hint: 'VIP'),
                const SizedBox(height: AppSpacing.md),
                AppTextField(controller: descCtrl, label: 'Təsvir (istəyə bağlı)'),
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
                  label: discountType == 'percent' ? 'Endirim faizi' : 'Endirim məbləği (₼)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Tətbiq sahəsi', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'time_only', label: Text('Yalnız vaxt')),
                    ButtonSegment(value: 'all', label: Text('Vaxt + məhsul')),
                  ],
                  selected: {appliesTo},
                  onSelectionChanged: (s) => setDialogState(() => appliesTo = s.first),
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
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(isEdit ? 'Yadda saxla' : 'Yarat')),
      ],
    );

    if (ok != true) {
      nameCtrl.dispose();
      descCtrl.dispose();
      valueCtrl.dispose();
      return;
    }

    final name = nameCtrl.text.trim();
    final description = descCtrl.text.trim();
    final value = double.tryParse(valueCtrl.text.replaceAll(',', '.')) ?? 0;
    nameCtrl.dispose();
    descCtrl.dispose();
    valueCtrl.dispose();

    if (name.isEmpty || value <= 0) {
      if (mounted) showAppSnackBar(context, 'Ad və endirim dəyəri tələb olunur', isError: true);
      return;
    }

    final payload = {
      'name': name,
      if (description.isNotEmpty) 'description': description,
      'discount_type': discountType,
      'discount_value': value,
      'applies_to': appliesTo,
      'is_active': isActive,
    };

    try {
      final service = ref.read(posServiceProvider);
      if (isEdit) {
        await service.updateCustomerGroup(jsonToInt(group['id']), payload);
      } else {
        await service.createCustomerGroup(payload);
      }
      await reload();
      if (mounted) showAppSnackBar(context, isEdit ? 'Qrup yeniləndi' : 'Qrup yaradıldı');
    } catch (e) {
      if (mounted) showAppSnackBar(context, 'Xəta: $e', isError: true);
    }
  }

  Future<void> _showMembers(Map<String, dynamic> group) async {
    final groupId = jsonToInt(group['id']);
    final searchCtrl = TextEditingController();
    var members = <Map<String, dynamic>>[];
    var results = <Map<String, dynamic>>[];
    try {
      members = (await ref.read(posServiceProvider).getGroupMembers(groupId)).cast<Map<String, dynamic>>();
    } catch (e) {
      if (mounted) showAppSnackBar(context, ApiClient.messageFromError(e), isError: true);
      return;
    }
    if (!mounted) return;

    await showAppDialog<void>(
      context: context,
      title: group['name'] as String? ?? 'Qrup',
      subtitle: 'Müştəri axtarıb əlavə edin və ya çıxarın',
      maxWidth: 520,
      body: StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> search() async {
            try {
              final rows = await ref.read(posServiceProvider).searchCustomers(searchCtrl.text.trim());
              final memberIds = members.map((m) => jsonToInt(m['id'])).toSet();
              setDialogState(() {
                results = rows
                    .cast<Map<String, dynamic>>()
                    .where((c) => !memberIds.contains(jsonToInt(c['id'])))
                    .take(12)
                    .toList();
              });
            } catch (e) {
              if (context.mounted) showAppSnackBar(context, ApiClient.messageFromError(e), isError: true);
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(controller: searchCtrl, label: 'Müştəri axtar', onSubmitted: (_) => search()),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: search, child: const Text('Axtar')),
              ),
              ...results.map((c) => ListTile(
                    dense: true,
                    title: Text(c['name'] as String? ?? ''),
                    subtitle: Text(c['phone'] as String? ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        try {
                          members = (await ref.read(posServiceProvider).changeGroupMembers(groupId, add: [jsonToInt(c['id'])]))
                              .cast<Map<String, dynamic>>();
                          await search();
                          await reload();
                        } catch (e) {
                          if (context.mounted) showAppSnackBar(context, ApiClient.messageFromError(e), isError: true);
                        }
                      },
                    ),
                  )),
              const Divider(),
              if (members.isEmpty) const Text('Bu qrupda müştəri yoxdur'),
              ...members.map((m) => ListTile(
                    dense: true,
                    title: Text(m['name'] as String? ?? ''),
                    subtitle: Text(m['phone'] as String? ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () async {
                        try {
                          members = (await ref.read(posServiceProvider).changeGroupMembers(groupId, remove: [jsonToInt(m['id'])]))
                              .cast<Map<String, dynamic>>();
                          setDialogState(() {});
                          await reload();
                        } catch (e) {
                          if (context.mounted) showAppSnackBar(context, ApiClient.messageFromError(e), isError: true);
                        }
                      },
                    ),
                  )),
            ],
          );
        },
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Bağla')),
      ],
    );
    searchCtrl.dispose();
  }

  String _discountLabel(Map<String, dynamic> g) {
    final type = g['discount_type'] as String? ?? 'percent';
    final value = jsonToDouble(g['discount_value']);
    final applies = g['applies_to'] == 'all' ? ' · vaxt+məhsul' : ' · yalnız vaxt';
    return type == 'percent' ? '${value.toStringAsFixed(0)}%$applies' : '${value.toStringAsFixed(2)} ₼$applies';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_groups.isEmpty) {
      return const EmptyState(
        icon: Icons.groups_outlined,
        title: 'Müştəri qrupu yoxdur',
        subtitle: 'VIP, tələbə, korporativ endirim qrupları yaradın',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      itemCount: _groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) {
        final g = _groups[i] as Map<String, dynamic>;
        final active = g['is_active'] != false;
        final members = jsonToInt(g['member_count']);
        return AdminListTile(
          leading: CircleAvatar(
            backgroundColor: BrandColors.brightBlue.withValues(alpha: 0.12),
            child: Icon(Icons.groups_outlined, color: BrandColors.brightBlue, size: 20),
          ),
          title: g['name'] as String? ?? '',
          subtitle: [
            _discountLabel(g),
            if ((g['description'] as String?)?.isNotEmpty == true) g['description'] as String,
            if (members > 0) '$members müştəri',
          ].where((e) => e.isNotEmpty).join(' · '),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!active)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    'Deaktiv',
                    style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12),
                  ),
                ),
              IconButton(
                tooltip: 'Müştərilər',
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
                onPressed: () => _showMembers(g),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _showForm(group: g),
              ),
            ],
          ),
          onTap: () => _showForm(group: g),
          onDelete: () async {
            await ref.read(posServiceProvider).deleteCustomerGroup(jsonToInt(g['id']));
            await reload();
            if (mounted) showAppSnackBar(context, 'Qrup silindi');
          },
        );
      },
    );
  }
}
