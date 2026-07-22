import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/admin_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/cashier_theme.dart';
import '../../../core/utils/json_parse.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../services/pos_service.dart';
import 'admin_page_layout.dart';

class LoyaltyTiersPanel extends ConsumerStatefulWidget {
  const LoyaltyTiersPanel({super.key});

  @override
  ConsumerState<LoyaltyTiersPanel> createState() => LoyaltyTiersPanelState();
}

class LoyaltyTiersPanelState extends ConsumerState<LoyaltyTiersPanel> {
  List<dynamic> _tiers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    setState(() => _loading = true);
    try {
      _tiers = await ref.read(posServiceProvider).getLoyaltyTiers();
    } catch (_) {
      _tiers = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> showCreateForm() => _showForm();

  String _rewardLabel(Map<String, dynamic> tier) {
    final kind = tier['reward_kind'] as String? ?? 'hours';
    final value = jsonToDouble(tier['reward_value']);
    return switch (kind) {
      'hours' => '${value.toStringAsFixed(0)} dəq pulsuz',
      'hours_percent' => '${value.toStringAsFixed(0)}% → saat balansı',
      'wallet_percent' => '${value.toStringAsFixed(0)}% → endirim balansı',
      'wallet_fixed' => '${value.toStringAsFixed(2)} ₼ endirim balansı',
      _ => value.toString(),
    };
  }

  Future<void> _showForm({Map<String, dynamic>? tier}) async {
    final isEdit = tier != null;
    final nameCtrl = TextEditingController(text: tier?['name'] as String? ?? '');
    final thresholdCtrl = TextEditingController(
      text: tier != null ? jsonToDouble(tier['spend_threshold']).toStringAsFixed(0) : '500',
    );
    final valueCtrl = TextEditingController(
      text: tier != null ? jsonToDouble(tier['reward_value']).toStringAsFixed(0) : '',
    );
    final rateCtrl = TextEditingController(
      text: tier?['reference_hourly_rate'] != null
          ? jsonToDouble(tier!['reference_hourly_rate']).toStringAsFixed(2)
          : '',
    );
    var rewardKind = tier?['reward_kind'] as String? ?? 'hours_percent';
    var isActive = jsonIsActive(tier?['is_active']);

    final ok = await showAppDialog<bool>(
      context: context,
      title: isEdit ? 'Loyallıq qaydasını redaktə et' : 'Yeni loyallıq qaydası',
      subtitle: 'Müştəri xərc həddinə çatanda avtomatik bonus (sessiya üzrə max 1)',
      icon: Icons.card_giftcard_outlined,
      maxWidth: 520,
      body: StatefulBuilder(
        builder: (context, setDialogState) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(controller: nameCtrl, label: 'Qayda adı', hint: '500 ₼ bonus'),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: thresholdCtrl,
                  label: 'Xərc həddi (₼)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Mükafat növü', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  value: rewardKind,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'hours', child: Text('Sabit saat (dəqiqə)')),
                    DropdownMenuItem(value: 'hours_percent', child: Text('Faiz → saat balansı')),
                    DropdownMenuItem(value: 'wallet_percent', child: Text('Faiz → endirim balansı (₼)')),
                    DropdownMenuItem(value: 'wallet_fixed', child: Text('Sabit endirim balansı (₼)')),
                  ],
                  onChanged: (v) => setDialogState(() => rewardKind = v ?? rewardKind),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: valueCtrl,
                  label: rewardKind == 'hours'
                      ? 'Bonus dəqiqə'
                      : rewardKind == 'wallet_fixed'
                          ? 'Bonus məbləğ (₼)'
                          : 'Faiz (%)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                if (rewardKind == 'hours_percent') ...[
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: rateCtrl,
                    label: 'Saatlıq tarif (₼) — boş = 10 ₼',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(isEdit ? 'Yadda saxla' : 'Yarat')),
      ],
    );

    if (ok != true) {
      nameCtrl.dispose();
      thresholdCtrl.dispose();
      valueCtrl.dispose();
      rateCtrl.dispose();
      return;
    }

    final name = nameCtrl.text.trim();
    final threshold = double.tryParse(thresholdCtrl.text.replaceAll(',', '.'));
    final rewardValue = double.tryParse(valueCtrl.text.replaceAll(',', '.'));
    final rateText = rateCtrl.text.trim();
    nameCtrl.dispose();
    thresholdCtrl.dispose();
    valueCtrl.dispose();
    rateCtrl.dispose();

    if (name.isEmpty) {
      if (mounted) showAppSnackBar(context, 'Ad daxil edin', isError: true);
      return;
    }
    if (threshold == null || threshold <= 0) {
      if (mounted) showAppSnackBar(context, 'Xərcləmə həddi 0-dan böyük olmalıdır', isError: true);
      return;
    }
    if (rewardValue == null || rewardValue <= 0) {
      if (mounted) showAppSnackBar(context, 'Mükafat dəyəri 0-dan böyük olmalıdır', isError: true);
      return;
    }

    final payload = <String, dynamic>{
      'name': name,
      'spend_threshold': threshold,
      'reward_kind': rewardKind,
      'reward_value': rewardValue,
      'is_active': isActive,
    };
    if (rewardKind == 'hours_percent' && rateText.isNotEmpty) {
      payload['reference_hourly_rate'] = double.tryParse(rateText.replaceAll(',', '.'));
    }

    try {
      if (isEdit) {
        await ref.read(posServiceProvider).updateLoyaltyTier(tier!['id'] as int, payload);
      } else {
        await ref.read(posServiceProvider).createLoyaltyTier(payload);
      }
      await reload();
      if (mounted) showAppSnackBar(context, isEdit ? 'Qayda yeniləndi' : 'Qayda əlavə edildi');
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> tier) async {
    final currentlyActive = jsonIsActive(tier['is_active']);
    try {
      await ref.read(posServiceProvider).updateLoyaltyTier(tier['id'] as int, {
        'is_active': !currentlyActive,
      });
      await reload();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> tier) async {
    final ok = await showAppDialog<bool>(
      context: context,
      title: 'Qaydanı sil',
      body: Text('«${tier['name']}» silinsin?'),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil')),
      ],
    );
    if (ok != true) return;
    try {
      await ref.read(posServiceProvider).deleteLoyaltyTier(tier['id'] as int);
      await reload();
      if (mounted) showAppSnackBar(context, 'Silindi');
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_tiers.isEmpty) {
      return const EmptyState(
        icon: Icons.card_giftcard_outlined,
        title: 'Loyallıq qaydası yoxdur',
        subtitle: 'Məsələn, hər 500 ₼ xərc üçün 5% saat bonusu yaradın',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      itemCount: _tiers.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final tier = _tiers[i] as Map<String, dynamic>;
        final active = jsonIsActive(tier['is_active']);
        final threshold = jsonToDouble(tier['spend_threshold']);

        return AdminListTile(
          leading: CircleAvatar(
            backgroundColor: active
                ? CashierTheme.accentSubtle(context)
                : CashierTheme.surfaceSecondary(context),
            child: Icon(
              Icons.card_giftcard_outlined,
              color: active ? CashierTheme.accent(context) : CashierTheme.textTertiary(context),
              size: 20,
            ),
          ),
          title: tier['name'] as String? ?? '',
          subtitle: 'Hər ${threshold.toStringAsFixed(0)} ₼ · ${_rewardLabel(tier)}',
          trailing: Switch(value: active, onChanged: (_) => _toggleActive(tier)),
          onTap: () => _showForm(tier: tier),
          onDelete: () => _delete(tier),
        );
      },
    );
  }
}
