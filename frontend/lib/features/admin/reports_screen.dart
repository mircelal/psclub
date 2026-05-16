import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/json_parse.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/stat_card.dart';
import '../../services/pos_service.dart';
import 'widgets/admin_page_layout.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  Map<String, dynamic>? _report;
  bool _loading = false;
  DateTime _date = DateTime.now();

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = DateFormat('yyyy-MM-dd').format(_date);
    _report = await ref.read(posServiceProvider).getDailyReport(d);
    setState(() => _loading = false);
  }

  Future<void> _closeDay() async {
    final d = DateFormat('yyyy-MM-dd').format(_date);
    await ref.read(posServiceProvider).dailyClose(d);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gün uğurla bağlandı')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageLayout(
      title: 'Günlük hesabat',
      subtitle: DateFormat('dd.MM.yyyy').format(_date),
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _date = picked);
                _load();
              }
            },
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(DateFormat('dd.MM.yyyy').format(_date)),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(onPressed: _load, child: const Text('Yüklə')),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(onPressed: _closeDay, child: const Text('Gün sonu')),
        ],
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _report == null
              ? Center(child: Text('Tarix seçib "Yüklə" basın', style: Theme.of(context).textTheme.bodyMedium))
              : _buildReport(),
    );
  }

  Widget _buildReport() {
    final summary = _report!['summary'] as Map<String, dynamic>? ?? {};
    final payments = _report!['payments'] as List<dynamic>? ?? [];
    final products = _report!['product_breakdown'] as List<dynamic>? ?? [];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        Row(
          children: [
            Expanded(child: StatCard(label: 'Session', value: '${summary['sessions_count'] ?? 0}', icon: Icons.play_circle_outline)),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: StatCard(label: 'Ümumi gəlir', value: '${summary['total_revenue'] ?? 0}', icon: Icons.trending_up, isMoney: true, color: AppColors.accent)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: StatCard(label: 'Vaxt gəliri', value: '${summary['time_revenue'] ?? 0}', isMoney: true, color: AppColors.primary)),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: StatCard(label: 'Məhsul gəliri', value: '${summary['products_revenue'] ?? 0}', isMoney: true, color: AppColors.info)),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text('Ödəniş üsulları', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        ...payments.map((p) {
          final m = p as Map<String, dynamic>;
          return AdminListTile(
            leading: Icon(_paymentIcon(m['method'] as String?), color: AppColors.textSecondary, size: 20),
            title: _paymentLabel(m['method'] as String?),
            trailing: MoneyText(amount: jsonToDouble(m['total']), size: MoneySize.small),
          );
        }),
        const SizedBox(height: AppSpacing.xxl),
        Text('Məhsul satışı', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        ...products.map((p) {
          final m = p as Map<String, dynamic>;
          return AdminListTile(
            title: m['product_name'] as String? ?? '',
            subtitle: '${m['qty']} ədəd satılıb',
            trailing: MoneyText(amount: jsonToDouble(m['revenue']), size: MoneySize.small),
          );
        }),
      ],
    );
  }

  IconData _paymentIcon(String? m) => switch (m) {
        'cash' => Icons.payments_outlined,
        'card' => Icons.credit_card,
        'mixed' => Icons.account_balance_wallet_outlined,
        _ => Icons.payment,
      };

  String _paymentLabel(String? m) => switch (m) {
        'cash' => 'Nağd',
        'card' => 'Bank kartı',
        'mixed' => 'Qarışıq ödəniş',
        _ => m ?? '—',
      };
}
