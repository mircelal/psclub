import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/theme/cashier_theme.dart';
import '../../core/theme/cashier_theme_data.dart';
import '../../core/utils/json_parse.dart';
import '../../core/utils/phone_utils.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/phone_text_field.dart';
import '../../services/pos_service.dart';

class CustomerProfileScreen extends ConsumerStatefulWidget {
  const CustomerProfileScreen({
    super.key,
    required this.customerId,
    this.onUpdated,
  });

  final int customerId;
  final VoidCallback? onUpdated;

  @override
  ConsumerState<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends ConsumerState<CustomerProfileScreen> {
  bool _loading = true;
  Map<String, dynamic>? _customer;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _sessions = [];
  String? _error;

  static final _dateFmt = DateFormat('dd.MM.yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref.read(posServiceProvider).getCustomerProfile(widget.customerId);
      _customer = data['customer'] as Map<String, dynamic>?;
      _stats = data['stats'] as Map<String, dynamic>?;
      _sessions = (data['sessions'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      _error = e.toString();
      _customer = null;
      _stats = null;
      _sessions = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _editCustomer() async {
    final customer = _customer;
    if (customer == null) return;

    final nameCtrl = TextEditingController(text: customer['name'] as String? ?? '');
    final phoneCtrl = TextEditingController(text: PhoneUtils.fieldValue(stored: customer['phone'] as String?));
    final emailCtrl = TextEditingController(text: customer['email'] as String? ?? '');
    final notesCtrl = TextEditingController(text: customer['notes'] as String? ?? '');

    final ok = await showAppDialog<bool>(
      context: context,
      title: 'Müştərini redaktə et',
      icon: Icons.person_outline,
      maxWidth: 480,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(controller: nameCtrl, label: 'Ad soyad', prefixIcon: Icons.badge_outlined),
          const SizedBox(height: AppSpacing.lg),
          PhoneTextField(controller: phoneCtrl),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: emailCtrl, label: 'E-poçt (istəyə bağlı)', prefixIcon: Icons.email_outlined),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(controller: notesCtrl, label: 'Qeyd (istəyə bağlı)'),
        ],
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yadda saxla')),
      ],
    );

    if (ok != true) {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      emailCtrl.dispose();
      notesCtrl.dispose();
      return;
    }

    final name = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final notes = notesCtrl.text.trim();
    final phone = PhoneUtils.normalize(phoneCtrl.text);

    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    notesCtrl.dispose();

    if (name.isEmpty || phone == null) {
      if (mounted) {
        showAppSnackBar(
          context,
          phone == null ? 'Düzgün telefon daxil edin' : 'Ad daxil edin',
          isError: true,
        );
      }
      return;
    }

    try {
      await ref.read(posServiceProvider).updateCustomer(widget.customerId, {
        'name': name,
        'phone': phone,
        if (email.isNotEmpty) 'email': email,
        if (notes.isNotEmpty) 'notes': notes,
      });
      await _load();
      widget.onUpdated?.call();
      if (mounted) showAppSnackBar(context, 'Müştəri yeniləndi');
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          e.toString().contains('409') ? 'Bu telefon artıq qeydiyyatdadır' : 'Xəta: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customer = _customer;
    final stats = _stats;

    return CashierThemeData.wrap(
      context,
      Scaffold(
      backgroundColor: CashierTheme.scaffoldBg(context),
      appBar: AppBar(
        title: Text(customer?['name'] as String? ?? 'Müştəri profili'),
        actions: [
          if (customer != null)
            IconButton(
              onPressed: _editCustomer,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Redaktə et',
            ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Yenilə',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _load, child: const Text('Yenidən')),
                    ],
                  ),
                )
              : customer == null
                  ? const Center(child: Text('Müştəri tapılmadı'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpacing.xxl),
                        children: [
                          _ProfileHeader(customer: customer),
                          const SizedBox(height: AppSpacing.xl),
                          if (stats != null) _StatsGrid(stats: stats),
                          const SizedBox(height: AppSpacing.xl),
                          Text('Sessiyalar və alışlar', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: AppSpacing.md),
                          if (_sessions.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'Bu müştəri üçün sessiya qeydi yoxdur',
                                  style: CashierTheme.caption(context),
                                ),
                              ),
                            )
                          else
                            ..._sessions.map((s) => _SessionCard(session: s, dateFmt: _dateFmt)),
                        ],
                      ),
                    ),
    ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.customer});

  final Map<String, dynamic> customer;

  @override
  Widget build(BuildContext context) {
    final name = customer['name'] as String? ?? '';
    final phone = customer['phone'] as String? ?? '';
    final email = customer['email'] as String? ?? '';
    final notes = customer['notes'] as String? ?? '';
    final groupName = customer['customer_group_name'] as String?;
    final groupDiscount = customer['customer_group_discount_type'] != null
        ? (customer['customer_group_discount_type'] == 'percent'
            ? '${jsonToDouble(customer['customer_group_discount_value']).toStringAsFixed(0)}%'
            : '${jsonToDouble(customer['customer_group_discount_value']).toStringAsFixed(2)} ₼')
        : null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: CashierTheme.elevatedCardDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: CashierTheme.accentSubtle(context),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: BrandColors.brightBlue),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleLarge),
                if (groupName != null && groupName.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Chip(
                    avatar: const Icon(Icons.local_offer_outlined, size: 16),
                    label: Text(groupDiscount != null ? '$groupName · $groupDiscount' : groupName),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 16, color: CashierTheme.textSecondary(context)),
                      const SizedBox(width: 6),
                      Text(phone, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ],
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 16, color: CashierTheme.textSecondary(context)),
                      const SizedBox(width: 6),
                      Text(email, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ],
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(notes, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final playSeconds = jsonToInt(stats['play_seconds']);
    final totalSpent = jsonToDouble(stats['total_spent']);
    final productsSpent = jsonToDouble(stats['products_spent']);
    final timeSpent = jsonToDouble(stats['time_spent']);
    final sessionCount = jsonToInt(stats['session_count']);
    final closedCount = jsonToInt(stats['closed_session_count']);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cross = constraints.maxWidth > 700 ? 3 : (constraints.maxWidth > 420 ? 2 : 1);
        final tiles = [
          _StatTile(
            label: 'Ümumi xərcləmə',
            value: '${totalSpent.toStringAsFixed(2)} ₼',
            icon: Icons.payments_outlined,
            accent: BrandColors.brightBlue,
          ),
          _StatTile(
            label: 'Oyun müddəti',
            value: formatDurationHms(playSeconds),
            icon: Icons.timer_outlined,
            accent: AdminTheme.info(context),
          ),
          _StatTile(
            label: 'Məhsul alışı',
            value: '${productsSpent.toStringAsFixed(2)} ₼',
            icon: Icons.shopping_bag_outlined,
            accent: BrandColors.sky,
          ),
          _StatTile(
            label: 'Vaxt haqqı',
            value: '${timeSpent.toStringAsFixed(2)} ₼',
            icon: Icons.schedule_outlined,
            accent: AdminTheme.warning(context),
          ),
          _StatTile(
            label: 'Sessiya sayı',
            value: '$sessionCount',
            subtitle: '$closedCount bağlanmış',
            icon: Icons.receipt_long_outlined,
            accent: CashierTheme.textSecondary(context),
          ),
        ];

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: tiles
              .map(
                (t) => SizedBox(
                  width: cross == 1
                      ? double.infinity
                      : (constraints.maxWidth - (cross - 1) * 10) / cross,
                  child: t,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: CashierTheme.elevatedCardDecoration(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: CashierTheme.caption(context)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.dateFmt});

  final Map<String, dynamic> session;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final status = session['status'] as String? ?? '';
    final sessionType = session['session_type'] as String? ?? 'table';
    final tableName = session['table_name'] as String?;
    final openedAt = session['opened_at'] as String?;
    final closedAt = session['closed_at'] as String?;
    final playSeconds = jsonToInt(session['active_seconds']);
    final total = jsonToDouble(session['total_amount']);
    final products = jsonToDouble(session['products_total']);
    final timeCharge = jsonToDouble(session['time_charge']);
    final setName = session['set_name_snapshot'] as String?;

    final title = sessionType == 'counter'
        ? 'Birbaşa satış'
        : (tableName != null && tableName.isNotEmpty ? tableName : 'Masa sessiyası');

    final statusLabel = switch (status) {
      'active' => 'Aktiv',
      'paused' => 'Pause',
      'closed' => 'Bağlanıb',
      _ => status,
    };

    final statusColor = switch (status) {
      'active' => AdminTheme.danger(context),
      'paused' => AdminTheme.warning(context),
      'closed' => AdminTheme.success(context),
      _ => CashierTheme.textTertiary(context),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: CashierTheme.elevatedCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
                ),
              ),
            ],
          ),
          if (setName != null && setName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Paket: $setName', style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 8),
          if (openedAt != null)
            Text('Açılış: ${_formatDt(openedAt)}', style: Theme.of(context).textTheme.bodySmall),
          if (closedAt != null)
            Text('Bağlanış: ${_formatDt(closedAt)}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              if (sessionType == 'table' && playSeconds > 0)
                _chip(context, Icons.timer_outlined, formatDurationHms(playSeconds)),
              if (timeCharge > 0) _chip(context, Icons.schedule, '${timeCharge.toStringAsFixed(2)} ₼ vaxt'),
              if (products > 0) _chip(context, Icons.shopping_bag_outlined, '${products.toStringAsFixed(2)} ₼ məhsul'),
              if (status == 'closed' || total > 0)
                _chip(context, Icons.payments, '${total.toStringAsFixed(2)} ₼ cəmi', bold: true),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDt(String raw) {
    try {
      return dateFmt.format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }

  Widget _chip(BuildContext context, IconData icon, String label, {bool bold = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: CashierTheme.textSecondary(context)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
            color: bold ? CashierTheme.textPrimary(context) : CashierTheme.textSecondary(context),
          ),
        ),
      ],
    );
  }
}
