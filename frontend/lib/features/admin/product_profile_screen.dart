import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/admin_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/theme/cashier_theme.dart';
import '../../core/theme/cashier_theme_data.dart';
import '../../core/utils/json_parse.dart';
import '../../core/widgets/product_image.dart';
import '../../services/pos_service.dart';
import 'product_delete_action.dart';

class ProductProfileScreen extends ConsumerStatefulWidget {
  const ProductProfileScreen({
    super.key,
    required this.productId,
    this.initialName,
  });

  final int productId;
  final String? initialName;

  @override
  ConsumerState<ProductProfileScreen> createState() => _ProductProfileScreenState();
}

class _ProductProfileScreenState extends ConsumerState<ProductProfileScreen> with SingleTickerProviderStateMixin {
  bool _initialLoading = true;
  bool _refreshing = false;
  Map<String, dynamic>? _product;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _reconciliation;
  List<Map<String, dynamic>> _movements = [];
  List<Map<String, dynamic>> _dailySales = [];
  List<Map<String, dynamic>> _hourlySales = [];
  List<Map<String, dynamic>> _salesLines = [];
  String? _error;
  late TabController _tabs;
  DateTime _from = DateTime.now().subtract(const Duration(days: 29));
  DateTime _to = DateTime.now();
  final Set<String> _expandedDays = {};

  static final _dateFmt = DateFormat('dd.MM.yyyy HH:mm');
  static final _dayFmt = DateFormat('dd.MM.yyyy');
  static final _apiDayFmt = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging && mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        if (_product == null) _initialLoading = true;
        _error = null;
      });
    } else {
      setState(() {
        _refreshing = true;
        _error = null;
      });
    }
    try {
      final data = await ref.read(posServiceProvider).getProductProfile(
            widget.productId,
            from: _apiDayFmt.format(_from),
            to: _apiDayFmt.format(_to),
          );
      _product = data['product'] as Map<String, dynamic>?;
      _stats = data['stats'] as Map<String, dynamic>?;
      _reconciliation = data['reconciliation'] as Map<String, dynamic>?;
      _movements = (data['movements'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      _dailySales = (data['daily_sales'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      _hourlySales = (data['hourly_sales'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      _salesLines = (data['sales_lines'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    } catch (e) {
      _error = ApiClient.messageFromError(e);
      if (!silent) {
        _product = null;
        _stats = null;
        _reconciliation = null;
        _movements = [];
        _dailySales = [];
        _hourlySales = [];
        _salesLines = [];
      }
    }
    if (mounted) {
      setState(() {
        _initialLoading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _deleteProduct() async {
    final name = _product?['name'] as String? ?? widget.initialName ?? 'Məhsul';
    final deleted = await confirmAndDeleteProduct(
      ref,
      context,
      id: widget.productId,
      name: name,
    );
    if (deleted && mounted) Navigator.pop(context, true);
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (!mounted || range == null) return;
    setState(() {
      _from = range.start;
      _to = range.end;
      _expandedDays.clear();
    });
    _load(silent: true);
  }

  List<Map<String, dynamic>> _salesLinesForDate(String date) {
    return _salesLines.where((line) {
      final closedAt = line['closed_at'] as String?;
      if (closedAt == null || closedAt.length < 10) return false;
      return closedAt.substring(0, 10) == date;
    }).toList();
  }

  List<Map<String, dynamic>> _hourlyForDate(String date) {
    if (_apiDayFmt.format(_from) == _apiDayFmt.format(_to) && _apiDayFmt.format(_from) == date) {
      return _hourlySales;
    }
    final lines = _salesLinesForDate(date);
    final buckets = <int, Map<String, dynamic>>{};
    for (final line in lines) {
      final closedAt = line['closed_at'] as String?;
      if (closedAt == null) continue;
      final dt = DateTime.tryParse(closedAt);
      if (dt == null) continue;
      final hour = dt.hour;
      final bucket = buckets.putIfAbsent(hour, () => {'hour': hour, 'qty': 0, 'revenue': 0.0});
      bucket['qty'] = (bucket['qty'] as int) + jsonToInt(line['qty']);
      bucket['revenue'] = (bucket['revenue'] as double) + jsonToDouble(line['line_total']);
    }
    final result = buckets.values.toList()
      ..sort((a, b) => (a['hour'] as int).compareTo(b['hour'] as int));
    return result.cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    final stats = _stats;
    final reconciliation = _reconciliation;
    final name = product?['name'] as String? ?? widget.initialName ?? 'Məhsul profili';

    return CashierThemeData.wrap(
      context,
      Scaffold(
        backgroundColor: CashierTheme.scaffoldBg(context),
        appBar: AppBar(
          title: Text(name),
          actions: [
            OutlinedButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range, size: 18),
              label: Text('${_dayFmt.format(_from)} — ${_dayFmt.format(_to)}'),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _refreshing ? null : () => _load(silent: true),
              icon: _refreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              tooltip: 'Yenilə',
            ),
            IconButton(
              onPressed: _deleteProduct,
              icon: Icon(Icons.delete_outline, color: AppColors.danger.withValues(alpha: 0.9)),
              tooltip: 'Məhsulu sil',
            ),
          ],
        ),
        body: _initialLoading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : _error != null && _product == null
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
                : product == null
                    ? const Center(child: Text('Məhsul tapılmadı'))
                    : RefreshIndicator(
                        onRefresh: () => _load(silent: true),
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            if (_error != null)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, 0),
                                  child: _InlineErrorBanner(message: _error!),
                                ),
                              ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.xxl,
                                  AppSpacing.xxl,
                                  AppSpacing.xxl,
                                  0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _ProfileHeader(product: product),
                                    const SizedBox(height: AppSpacing.xl),
                                    if (reconciliation != null &&
                                        reconciliation['initial_stock_without_ledger'] == true)
                                      _InitialStockInfoBanner(),
                                    if (reconciliation != null &&
                                        reconciliation['matches_current'] == false &&
                                        jsonToInt(reconciliation['ledger_entries']) > 0)
                                      _ReconciliationBanner(reconciliation: reconciliation),
                                    if (stats != null) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                        child: Text(
                                          'Statistikalar: ${_dayFmt.format(_from)} — ${_dayFmt.format(_to)}',
                                          style: CashierTheme.caption(context),
                                        ),
                                      ),
                                      _StatsGrid(stats: stats),
                                      const SizedBox(height: AppSpacing.xl),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _TabBarHeaderDelegate(
                                TabBar(
                                  controller: _tabs,
                                  labelColor: BrandColors.brightBlue,
                                  tabs: const [
                                    Tab(text: 'Stok jurnalı'),
                                    Tab(text: 'Satışlar (gün)'),
                                    Tab(text: 'Sifariş sətirləri'),
                                  ],
                                ),
                                CashierTheme.surface(context),
                              ),
                            ),
                            ...switch (_tabs.index) {
                              0 => _MovementsTab.slivers(
                                    movements: _movements,
                                    dateFmt: _dateFmt,
                                  ),
                              1 => _DailySalesTab.slivers(
                                    dailySales: _dailySales,
                                    expandedDays: _expandedDays,
                                    onToggleDay: (date) {
                                      setState(() {
                                        if (_expandedDays.contains(date)) {
                                          _expandedDays.remove(date);
                                        } else {
                                          _expandedDays.add(date);
                                        }
                                      });
                                    },
                                    hourlyForDate: _hourlyForDate,
                                    salesLinesForDate: _salesLinesForDate,
                                    dateFmt: _dateFmt,
                                    dayFmt: _dayFmt,
                                  ),
                              _ => _SalesLinesTab.slivers(
                                    salesLines: _salesLines,
                                    dateFmt: _dateFmt,
                                  ),
                            },
                            const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.xxl)),
                          ],
                        ),
                      ),
      ),
    );
  }
}

class _TabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  _TabBarHeaderDelegate(this.tabBar, this.backgroundColor);

  final TabBar tabBar;
  final Color backgroundColor;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: backgroundColor,
      elevation: overlapsContent ? 1 : 0,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarHeaderDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar || backgroundColor != oldDelegate.backgroundColor;
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.product});

  final Map<String, dynamic> product;

  @override
  Widget build(BuildContext context) {
    final name = product['name'] as String? ?? '';
    final sku = product['sku'] as String? ?? '';
    final catName = product['category_name'] as String?;
    final price = jsonToDouble(product['price']);
    final stock = jsonToInt(product['stock_quantity']);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: CashierTheme.elevatedCardDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductImage(
            imageUrl: product['image_url'] as String?,
            categoryName: catName,
            size: 72,
            radius: AppSpacing.radiusMd,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  '${price.toStringAsFixed(2)} AZN • Stok: $stock',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (catName != null && catName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(catName, style: Theme.of(context).textTheme.bodyMedium),
                ],
                if (sku.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('SKU: $sku', style: CashierTheme.caption(context)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReconciliationBanner extends StatelessWidget {
  const _ReconciliationBanner({required this.reconciliation});

  final Map<String, dynamic> reconciliation;

  @override
  Widget build(BuildContext context) {
    final expected = jsonToInt(reconciliation['expected_stock_from_ledger']);
    final gap = jsonToInt(reconciliation['ledger_gap']);
    final gapText = gap == 0 ? '' : ' (fərq: ${gap > 0 ? '+' : ''}$gap)';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Stok jurnalı ilə cari qalıq uyğun gəlmir (jurnal: $expected$gapText). '
              'Köhnə admin düzəlişi və ya birbaşa stok dəyişikliyi ola bilər.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialStockInfoBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AdminTheme.info(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AdminTheme.info(context).withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AdminTheme.info(context)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Bu məhsul üçün stok jurnalı qeydi yoxdur — ilkin stok köhnə məlumat ola bilər. '
              'Yeni əməliyyatlardan sonra jurnal tam görünəcək.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineErrorBanner extends StatelessWidget {
  const _InlineErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
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
    final tiles = [
      _StatTile(
        label: 'Anbara giriş',
        value: '${jsonToInt(stats['stock_in'])}',
        icon: Icons.input_outlined,
        accent: AdminTheme.success(context),
      ),
      _StatTile(
        label: 'Satılan (stok)',
        value: '${jsonToInt(stats['sold_qty'])}',
        icon: Icons.remove_shopping_cart_outlined,
        accent: BrandColors.brightBlue,
      ),
      _StatTile(
        label: 'Qalan stok',
        value: '${jsonToInt(stats['current_stock'])}',
        icon: Icons.inventory_2_outlined,
        accent: BrandColors.sky,
      ),
      _StatTile(
        label: 'Sifarişlərdə satılan',
        value: '${jsonToInt(stats['sold_in_orders_qty'])}',
        icon: Icons.receipt_long_outlined,
        accent: AdminTheme.info(context),
      ),
      _StatTile(
        label: 'Gəlir',
        value: '${jsonToDouble(stats['sold_revenue']).toStringAsFixed(2)} ₼',
        icon: Icons.payments_outlined,
        accent: AdminTheme.warning(context),
      ),
      _StatTile(
        label: 'Açıq sessiyada',
        value: '${jsonToInt(stats['reserved_in_open_sessions'])}',
        subtitle: 'stokdan çıxılıb',
        icon: Icons.hourglass_top_outlined,
        accent: CashierTheme.textSecondary(context),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cross = constraints.maxWidth > 700 ? 3 : (constraints.maxWidth > 420 ? 2 : 1);
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
                Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Text(subtitle!, style: CashierTheme.caption(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementsTab extends StatelessWidget {
  const _MovementsTab({required this.movements, required this.dateFmt});

  final List<Map<String, dynamic>> movements;
  final DateFormat dateFmt;

  static List<Widget> slivers({
    required List<Map<String, dynamic>> movements,
    required DateFormat dateFmt,
  }) {
    return _MovementsTab(movements: movements, dateFmt: dateFmt)._buildSlivers();
  }

  List<Widget> _buildSlivers() {
    if (movements.isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text('Stok hərəkəti yoxdur'),
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        sliver: SliverList.separated(
          itemCount: movements.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, i) => _MovementTile(movement: movements[i], dateFmt: dateFmt),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement, required this.dateFmt});

  final Map<String, dynamic> movement;
  final DateFormat dateFmt;

  String _signedQty(Map<String, dynamic> m) {
    if (m.containsKey('delta')) {
      final delta = jsonToInt(m['delta']);
      if (delta > 0) return '+$delta';
      if (delta < 0) return '$delta';
    }
    final type = m['type'] as String? ?? '';
    final qty = jsonToInt(m['quantity']);
    if (type == 'adjustment') return '→ $qty';
    if (type == 'in') return '+$qty';
    return '-$qty';
  }

  Color _qtyColor(BuildContext context, Map<String, dynamic> m) {
    if (m.containsKey('delta')) {
      final delta = jsonToInt(m['delta']);
      if (delta > 0) return AppColors.success;
      if (delta < 0) return AppColors.danger;
      return AdminTheme.info(context);
    }
    final type = m['type'] as String? ?? '';
    if (type == 'adjustment') return AdminTheme.info(context);
    if (type == 'in') return AppColors.success;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    final m = movement;
    final type = m['type'] as String? ?? '';
    final createdAt = m['created_at'] as String?;
    final dt = createdAt != null ? DateTime.tryParse(createdAt) : null;
    final by = m['created_by_name'] as String?;
    final note = m['note'] as String?;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: CashierTheme.elevatedCardDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m['label_az'] as String? ?? type, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (dt != null) Text(dateFmt.format(dt), style: CashierTheme.caption(context)),
                if (by != null && by.isNotEmpty) Text('İstifadəçi: $by', style: CashierTheme.caption(context)),
                if (note != null && note.isNotEmpty) Text(note, style: CashierTheme.caption(context)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _signedQty(m),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: _qtyColor(context, m),
                ),
              ),
              Text(
                'Qalıq: ${jsonToInt(m['balance_after'])}',
                style: CashierTheme.caption(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailySalesTab extends StatelessWidget {
  const _DailySalesTab({
    required this.dailySales,
    required this.expandedDays,
    required this.onToggleDay,
    required this.hourlyForDate,
    required this.salesLinesForDate,
    required this.dateFmt,
    required this.dayFmt,
  });

  final List<Map<String, dynamic>> dailySales;
  final Set<String> expandedDays;
  final void Function(String date) onToggleDay;
  final List<Map<String, dynamic>> Function(String date) hourlyForDate;
  final List<Map<String, dynamic>> Function(String date) salesLinesForDate;
  final DateFormat dateFmt;
  final DateFormat dayFmt;

  static List<Widget> slivers({
    required List<Map<String, dynamic>> dailySales,
    required Set<String> expandedDays,
    required void Function(String date) onToggleDay,
    required List<Map<String, dynamic>> Function(String date) hourlyForDate,
    required List<Map<String, dynamic>> Function(String date) salesLinesForDate,
    required DateFormat dateFmt,
    required DateFormat dayFmt,
  }) {
    return _DailySalesTab(
      dailySales: dailySales,
      expandedDays: expandedDays,
      onToggleDay: onToggleDay,
      hourlyForDate: hourlyForDate,
      salesLinesForDate: salesLinesForDate,
      dateFmt: dateFmt,
      dayFmt: dayFmt,
    )._buildSlivers();
  }

  List<Widget> _buildSlivers() {
    if (dailySales.isEmpty) {
      return const [
        SliverPadding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text('Seçilmiş dövrdə satış yoxdur'),
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final day = dailySales[i];
              final date = day['date'] as String? ?? '';
              final expanded = expandedDays.contains(date);
              final hourly = expanded ? hourlyForDate(date) : <Map<String, dynamic>>[];
              final lines = expanded ? salesLinesForDate(date) : <Map<String, dynamic>>[];

              return Padding(
                padding: EdgeInsets.only(bottom: i < dailySales.length - 1 ? AppSpacing.sm : 0),
                child: Container(
                  decoration: CashierTheme.elevatedCardDecoration(context),
                  child: Column(
                    children: [
                      ListTile(
                        onTap: () => onToggleDay(date),
                        title: Text(date.isNotEmpty ? dayFmt.format(DateTime.parse(date)) : date),
                        subtitle: Text(
                          '${jsonToInt(day['qty'])} ədəd • ${jsonToDouble(day['revenue']).toStringAsFixed(2)} ₼',
                        ),
                        trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                      ),
                      if (expanded) ...[
                        const Divider(height: 1),
                        if (hourly.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Saat üzrə', style: Theme.of(context).textTheme.labelLarge),
                            ),
                          ),
                          ...hourly.map((h) {
                            final hour = jsonToInt(h['hour']);
                            return ListTile(
                              dense: true,
                              title: Text(
                                '${hour.toString().padLeft(2, '0')}:00 — ${(hour + 1).toString().padLeft(2, '0')}:00',
                              ),
                              trailing: Text(
                                '${jsonToInt(h['qty'])} • ${jsonToDouble(h['revenue']).toStringAsFixed(2)} ₼',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            );
                          }),
                        ],
                        if (lines.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Sifariş sətirləri', style: Theme.of(context).textTheme.labelLarge),
                            ),
                          ),
                          ...lines.map((line) => _SalesLineTile(line: line, dateFmt: dateFmt)),
                        ],
                      ],
                    ],
                  ),
                ),
              );
            },
            childCount: dailySales.length,
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _SalesLinesTab extends StatelessWidget {
  const _SalesLinesTab({required this.salesLines, required this.dateFmt});

  final List<Map<String, dynamic>> salesLines;
  final DateFormat dateFmt;

  static List<Widget> slivers({
    required List<Map<String, dynamic>> salesLines,
    required DateFormat dateFmt,
  }) {
    return _SalesLinesTab(salesLines: salesLines, dateFmt: dateFmt)._buildSlivers();
  }

  List<Widget> _buildSlivers() {
    if (salesLines.isEmpty) {
      return const [
        SliverPadding(
          padding: EdgeInsets.all(AppSpacing.xxl),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Text('Sifariş sətri yoxdur'),
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => Padding(
              padding: EdgeInsets.only(bottom: i < salesLines.length - 1 ? AppSpacing.sm : 0),
              child: _SalesLineTile(line: salesLines[i], dateFmt: dateFmt),
            ),
            childCount: salesLines.length,
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _SalesLineTile extends StatelessWidget {
  const _SalesLineTile({required this.line, required this.dateFmt});

  final Map<String, dynamic> line;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final sessionId = jsonToInt(line['session_id']);
    final closedAt = line['closed_at'] as String?;
    final dt = closedAt != null ? DateTime.tryParse(closedAt) : null;
    final table = line['table_name'] as String?;
    final orderState = line['order_state'] as String?;
    final qty = jsonToInt(line['qty']);
    final total = jsonToDouble(line['line_total']);

    String stateLabel(String? state) {
      switch (state) {
        case 'paid':
          return 'Ödənilib';
        case 'adjusted':
          return 'Düzəldilib';
        case 'refunded':
          return 'Qaytarılıb';
        default:
          return state ?? '';
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: CashierTheme.elevatedCardDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sifariş #$sessionId', style: const TextStyle(fontWeight: FontWeight.w600)),
                if (dt != null) Text(dateFmt.format(dt), style: CashierTheme.caption(context)),
                Text(
                  [
                    if (table != null && table.isNotEmpty) table else 'Kassa',
                    if (orderState != null && orderState.isNotEmpty) stateLabel(orderState),
                  ].join(' • '),
                  style: CashierTheme.caption(context),
                ),
              ],
            ),
          ),
          Text(
            '$qty • ${total.toStringAsFixed(2)} ₼',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
