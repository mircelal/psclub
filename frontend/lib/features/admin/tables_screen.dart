import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/json_parse.dart';
import '../../core/utils/table_tariff_utils.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../services/pos_service.dart';
import 'widgets/admin_page_layout.dart';

class TablesScreen extends ConsumerStatefulWidget {
  const TablesScreen({super.key});

  @override
  ConsumerState<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends ConsumerState<TablesScreen> {
  List<dynamic> _tables = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _tables = await ref.read(posServiceProvider).getTables();
    setState(() => _loading = false);
  }

  Future<void> _showForm({Map<String, dynamic>? table}) async {
    final isEdit = table != null;
    final nameCtrl = TextEditingController(text: table?['name'] as String? ?? '');
    final tariffRows = <_TariffRowState>[];

    final existing = table != null ? parseTableTariffs(table) : <TableTariff>[];
    if (existing.isNotEmpty) {
      for (final t in existing) {
        tariffRows.add(_TariffRowState(name: t.name, rate: t.hourlyRate.toStringAsFixed(2)));
      }
    } else {
      tariffRows.add(_TariffRowState(name: 'Standart', rate: '5'));
    }

    final ok = await showAppDialog<bool>(
      context: context,
      title: isEdit ? 'Masanı redaktə et' : 'Yeni masa / stansiya',
      subtitle: 'Hər PS modeli və ya zona üçün ayrı tarif əlavə edin',
      icon: Icons.table_bar,
      body: StatefulBuilder(
        builder: (context, setDialogState) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(controller: nameCtrl, label: 'Masa adı', hint: 'PS Stansiya 5'),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(child: Text('Tariflər', style: Theme.of(context).textTheme.titleSmall)),
                    TextButton.icon(
                      onPressed: () {
                        setDialogState(() => tariffRows.add(_TariffRowState()));
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Tarif'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ...tariffRows.asMap().entries.map((entry) {
                  final i = entry.key;
                  final row = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: AppTextField(
                            controller: row.nameCtrl,
                            label: i == 0 ? 'Ad (PS modeli)' : null,
                            hint: 'PS5 Pro',
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 2,
                          child: AppTextField(
                            controller: row.rateCtrl,
                            label: i == 0 ? '₼/saat' : null,
                            hint: '5.00',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        if (tariffRows.length > 1)
                          IconButton(
                            tooltip: 'Sil',
                            onPressed: () {
                              setDialogState(() {
                                row.dispose();
                                tariffRows.removeAt(i);
                              });
                            },
                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
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
      for (final row in tariffRows) {
        row.dispose();
      }
      nameCtrl.dispose();
      return;
    }

    final tariffs = <Map<String, dynamic>>[];
    for (var i = 0; i < tariffRows.length; i++) {
      final row = tariffRows[i];
      final name = row.nameCtrl.text.trim();
      final rate = double.tryParse(row.rateCtrl.text.replaceAll(',', '.'));
      if (name.isEmpty || rate == null || rate <= 0) continue;
      tariffs.add({'name': name, 'hourly_rate': rate, 'sort_order': i});
    }

    for (final row in tariffRows) {
      row.dispose();
    }

    if (!mounted) {
      nameCtrl.dispose();
      return;
    }

    if (tariffs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ən azı bir düzgün tarif daxil edin')),
      );
      nameCtrl.dispose();
      return;
    }

    final service = ref.read(posServiceProvider);
    if (isEdit) {
      await service.updateTable(table['id'] as int, {
        'name': nameCtrl.text.trim(),
        'tariffs': tariffs,
      });
    } else {
      await service.createTable(nameCtrl.text.trim(), tariffs: tariffs);
    }
    nameCtrl.dispose();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageLayout(
      title: 'Masalar',
      subtitle: '${_tables.length} stansiya · hər masada bir və ya bir neçə tarif',
      action: FilledButton.icon(onPressed: () => _showForm(), icon: const Icon(Icons.add, size: 20), label: const Text('Əlavə et')),
      child: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _tables.isEmpty
              ? const EmptyState(icon: Icons.table_bar_outlined, title: 'Masa yoxdur', subtitle: 'İlk masanı əlavə edin')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  itemCount: _tables.length,
                  itemBuilder: (_, i) {
                    final t = _tables[i] as Map<String, dynamic>;
                    final tariffs = parseTableTariffs(t);
                    final subtitle = tariffs.isEmpty
                        ? '${jsonToDouble(t['hourly_rate']).toStringAsFixed(2)} ₼/saat'
                        : tariffs.map((x) => '${x.name}: ${x.hourlyRate.toStringAsFixed(2)} ₼').join(' · ');

                    return AdminListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primarySoft,
                        child: Text('${i + 1}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                      ),
                      title: t['name'] as String,
                      subtitle: subtitle,
                      trailing: Chip(label: Text(t['status'] as String? ?? 'empty', style: const TextStyle(fontSize: 11))),
                      onTap: () => _showForm(table: t),
                      onDelete: () async {
                        await ref.read(posServiceProvider).deleteTable(t['id'] as int);
                        _load();
                      },
                    );
                  },
                ),
    );
  }
}

class _TariffRowState {
  _TariffRowState({String name = '', String rate = ''})
      : nameCtrl = TextEditingController(text: name),
        rateCtrl = TextEditingController(text: rate);

  final TextEditingController nameCtrl;
  final TextEditingController rateCtrl;

  void dispose() {
    nameCtrl.dispose();
    rateCtrl.dispose();
  }
}
