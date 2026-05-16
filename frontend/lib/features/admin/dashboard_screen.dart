import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/json_parse.dart';
import '../../core/widgets/money_text.dart';
import '../../services/pos_service.dart';
import 'widgets/admin_page_layout.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  DateTime _from = DateTime.now().subtract(const Duration(days: 29));
  DateTime _to = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _data = await ref.read(posServiceProvider).getDashboard(
            from: DateFormat('yyyy-MM-dd').format(_from),
            to: DateFormat('yyyy-MM-dd').format(_to),
          );
    } catch (_) {
      _data = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (range != null) {
      setState(() {
        _from = range.start;
        _to = range.end;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fmt = DateFormat('dd.MM.yyyy');

    return AdminPageLayout(
      subtitle: '${fmt.format(_from)} — ${fmt.format(_to)}',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range, size: 18),
            label: const Text('Dövr'),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Yenilə'),
          ),
        ],
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _data == null
              ? Center(child: Text('Məlumat yüklənmədi', style: TextStyle(color: p.textMuted)))
              : _buildContent(p),
    );
  }

  Widget _buildContent(AppPalette p) {
    final overview = _data!['overview'] as Map<String, dynamic>? ?? {};
    final today = overview['today'] as Map<String, dynamic>? ?? {};
    final week = overview['week'] as Map<String, dynamic>? ?? {};
    final month = overview['month'] as Map<String, dynamic>? ?? {};
    final range = overview['range'] as Map<String, dynamic>? ?? {};
    final tables = _data!['tables'] as List<dynamic>? ?? [];
    final daily = _data!['daily_trend'] as List<dynamic>? ?? [];
    final topProducts = _data!['top_products'] as List<dynamic>? ?? [];
    final payments = _data!['payment_methods'] as List<dynamic>? ?? [];
    final activeNow = jsonToInt(_data!['active_sessions']);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      children: [
        if (activeNow > 0)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.lg),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 10, color: AppColors.danger),
                const SizedBox(width: AppSpacing.md),
                Text('$activeNow aktiv sessiya indi işləyir', style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
              ],
            ),
          ),
        Text('Ümumi baxış', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth > 1100 ? 4 : (c.maxWidth > 700 ? 2 : 1);
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: cols == 1 ? 2.8 : 2.2,
              children: [
                _periodCard('Bu gün', today, AppColors.accent),
                _periodCard('Bu həftə', week, AppColors.primary),
                _periodCard('Bu ay', month, AppColors.info),
                _periodCard('Seçilmiş dövr', range, AppColors.success),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xxxl),
        Text('Günlük gəlir', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        _DailyChart(days: daily, palette: p),
        const SizedBox(height: AppSpacing.xxxl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Masa üzrə gəlir', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  _TableRevenueList(tables: tables),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xxl),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Top məhsullar', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  ...topProducts.take(8).map((raw) {
                    final m = raw as Map<String, dynamic>;
                    return AdminListTile(
                      title: m['product_name'] as String? ?? '—',
                      subtitle: '${jsonToInt(m['qty'])} ədəd',
                      trailing: MoneyText(amount: jsonToDouble(m['revenue']), size: MoneySize.small),
                    );
                  }),
                  if (topProducts.isEmpty)
                    Text('Məlumat yoxdur', style: TextStyle(color: p.textMuted)),
                  const SizedBox(height: AppSpacing.xxl),
                  Text('Ödəniş üsulları', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  ...payments.map((raw) {
                    final m = raw as Map<String, dynamic>;
                    return AdminListTile(
                      title: _payLabel(m['method'] as String?),
                      trailing: MoneyText(amount: jsonToDouble(m['total']), size: MoneySize.small),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _periodCard(String label, Map<String, dynamic> data, Color color) {
    final total = jsonToDouble(data['total_revenue']);
    final sessions = jsonToInt(data['sessions_count']);
    final timeRev = jsonToDouble(data['time_revenue']);
    final prodRev = jsonToDouble(data['products_revenue']);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          MoneyText(amount: total, size: MoneySize.large),
          const SizedBox(height: AppSpacing.xs),
          Text('$sessions sessiya', style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            'Vaxt: ${timeRev.toStringAsFixed(0)} ₼ • Məhsul: ${prodRev.toStringAsFixed(0)} ₼',
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _payLabel(String? m) => switch (m) {
        'cash' => 'Nağd',
        'card' => 'Kart',
        'mixed' => 'Qarışıq',
        _ => m ?? '—',
      };
}

class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.days, required this.palette});

  final List<dynamic> days;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: palette.border),
        ),
        child: Text('Bu dövrdə bağlanmış sessiya yoxdur', style: TextStyle(color: palette.textMuted)),
      );
    }

    final values = days.map((d) => jsonToDouble((d as Map)['revenue'])).toList();
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final maxBar = maxV > 0 ? maxV : 1.0;

    return Container(
      height: 160,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(days.length, (i) {
          final d = days[i] as Map<String, dynamic>;
          final rev = jsonToDouble(d['revenue']);
          final h = (rev / maxBar) * 100;
          final day = d['day']?.toString() ?? '';
          final label = day.length >= 10 ? day.substring(8) : day;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Tooltip(
                    message: '${rev.toStringAsFixed(0)} ₼',
                    child: Container(
                      height: h.clamp(4, 100),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(label, style: TextStyle(fontSize: 9, color: palette.textMuted)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TableRevenueList extends StatelessWidget {
  const _TableRevenueList({required this.tables});

  final List<dynamic> tables;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (tables.isEmpty) {
      return Text('Masa gəliri yoxdur', style: TextStyle(color: p.textMuted));
    }

    final sorted = [...tables]..sort((a, b) {
        final ta = jsonToDouble((a as Map)['total_revenue']);
        final tb = jsonToDouble((b as Map)['total_revenue']);
        return tb.compareTo(ta);
      });

    return Column(
      children: sorted.map((raw) {
        final t = raw as Map<String, dynamic>;
        final total = jsonToDouble(t['total_revenue']);
        final sessions = jsonToInt(t['sessions_count']);
        final timeRev = jsonToDouble(t['time_revenue']);
        final prodRev = jsonToDouble(t['products_revenue']);

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(Icons.sports_esports, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t['name'] as String? ?? 'Masa', style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '$sessions sessiya • Vaxt ${timeRev.toStringAsFixed(0)} ₼ • Məhsul ${prodRev.toStringAsFixed(0)} ₼',
                      style: TextStyle(fontSize: 11, color: p.textMuted),
                    ),
                  ],
                ),
              ),
              MoneyText(amount: total, size: MoneySize.small),
            ],
          ),
        );
      }).toList(),
    );
  }
}
