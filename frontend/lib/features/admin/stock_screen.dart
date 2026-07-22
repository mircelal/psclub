import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/json_parse.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../services/pos_service.dart';
import 'product_profile_screen.dart';
import 'widgets/admin_page_layout.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen> {
  List<dynamic> _alerts = [];
  List<dynamic> _movements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final pos = ref.read(posServiceProvider);
    _alerts = await pos.getStockAlerts();
    _movements = await pos.getStockMovements();
    setState(() => _loading = false);
  }

  Future<void> _addMovement() async {
    if (!mounted) return;
    final products = await ref.read(posServiceProvider).getProducts();
    int? productId;
    String type = 'in';
    final qtyCtrl = TextEditingController(text: '10');
    final noteCtrl = TextEditingController();

    final ok = await showAppDialog<bool>(
      context: context,
      title: 'Stok əməliyyatı',
      subtitle: 'Giriş, çıxış və ya düzəliş',
      icon: Icons.warehouse,
      body: StatefulBuilder(
        builder: (ctx, setDlg) => Column(
          children: [
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(labelText: 'Məhsul'),
              initialValue: productId,
              items: products.map((p) {
                final m = p as Map<String, dynamic>;
                return DropdownMenuItem(value: m['id'] as int, child: Text(m['name'] as String));
              }).toList(),
              onChanged: (v) => setDlg(() => productId = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Əməliyyat növü'),
              initialValue: type,
              items: const [
                DropdownMenuItem(value: 'in', child: Text('Anbara giriş')),
                DropdownMenuItem(value: 'out', child: Text('Anbardan çıxış')),
                DropdownMenuItem(value: 'adjustment', child: Text('Düzəliş')),
              ],
              onChanged: (v) => setDlg(() => type = v ?? 'in'),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: qtyCtrl,
              label: type == 'adjustment' ? 'Yeni stok miqdarı' : 'Miqdar',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(controller: noteCtrl, label: 'Qeyd (istəyə bağlı)'),
          ],
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Təsdiq')),
      ],
    );

    if (ok == true && productId != null) {
      try {
        await ref.read(posServiceProvider).addStockMovement(
              productId!,
              type,
              int.tryParse(qtyCtrl.text) ?? 1,
              note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
            );
        if (mounted) _load();
      } catch (e) {
        if (mounted) {
          showAppSnackBar(context, ApiClient.messageFromError(e), isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageLayout(
      title: 'Stok idarəetməsi',
      subtitle: 'Anbar hərəkətləri və xəbərdarlıqlar',
      action: FilledButton.icon(onPressed: _addMovement, icon: const Icon(Icons.add, size: 20), label: const Text('Əməliyyat')),
      child: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  if (_alerts.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.fromLTRB(AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.lg),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: Text('${_alerts.length} məhsul minimum stok həddindədir', style: const TextStyle(fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                  const TabBar(
                    tabs: [Tab(text: 'Xəbərdarlıqlar'), Tab(text: 'Tarixçə')],
                    labelColor: AppColors.primary,
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        ListView(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          children: _alerts.isEmpty
                              ? [const Center(child: Text('Xəbərdarlıq yoxdur', style: TextStyle(color: AppColors.textMuted)))]
                              : _alerts.map((a) {
                                  final m = a as Map<String, dynamic>;
                                  return AdminListTile(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProductProfileScreen(
                                            productId: jsonToInt(m['id']),
                                            initialName: m['name'] as String?,
                                          ),
                                        ),
                                      );
                                    },
                                    leading: const Icon(Icons.warning_amber, color: AppColors.warning),
                                    title: m['name'] as String,
                                    trailing: Text('${m['quantity']} ədəd', style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700)),
                                  );
                                }).toList(),
                        ),
                        ListView(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          children: _movements.map((m) {
                            final x = m as Map<String, dynamic>;
                            final delta = jsonToInt(x['delta']);
                            final deltaText = delta > 0 ? '+$delta' : (delta < 0 ? '$delta' : '→ ${jsonToInt(x['quantity'])}');
                            final label = x['label_az'] as String? ?? x['type'] as String? ?? '';
                            final by = x['created_by_name'] as String?;
                            final note = x['note'] as String?;
                            final balance = x['balance_after'];

                            return AdminListTile(
                              title: x['product_name'] as String? ?? '',
                              subtitle: [
                                label,
                                x['created_at'] as String? ?? '',
                                if (by != null && by.isNotEmpty) 'Edən: $by',
                                if (note != null && note.isNotEmpty) note,
                              ].join('\n'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(deltaText, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  if (balance != null)
                                    Text('Qalıq: $balance', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
