import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
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

  Future<void> _add() async {
    final nameCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '5');
    final ok = await showAppDialog<bool>(
      context: context,
      title: 'Yeni masa / stansiya',
      subtitle: 'PlayStation otağı və ya konsol',
      icon: Icons.table_bar,
      body: Column(
        children: [
          AppTextField(controller: nameCtrl, label: 'Masa adı', hint: 'PS Stansiya 5'),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: rateCtrl, label: 'Saatlıq qiymət (AZN)', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        ],
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yarat')),
      ],
    );
    if (ok == true) {
      await ref.read(posServiceProvider).createTable(nameCtrl.text, double.tryParse(rateCtrl.text) ?? 5);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageLayout(
      title: 'Masalar',
      subtitle: '${_tables.length} stansiya qeydiyyatda',
      action: FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add, size: 20), label: const Text('Əlavə et')),
      child: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _tables.isEmpty
              ? const EmptyState(icon: Icons.table_bar_outlined, title: 'Masa yoxdur', subtitle: 'İlk masanı əlavə edin')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  itemCount: _tables.length,
                  itemBuilder: (_, i) {
                    final t = _tables[i] as Map<String, dynamic>;
                    return AdminListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primarySoft,
                        child: Text('${i + 1}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                      ),
                      title: t['name'] as String,
                      subtitle: '${t['hourly_rate']} AZN/saat',
                      trailing: Chip(label: Text(t['status'] as String? ?? 'empty', style: const TextStyle(fontSize: 11))),
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
