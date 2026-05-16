import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/json_parse.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/money_text.dart';
import '../../services/pos_service.dart';
import 'widgets/admin_page_layout.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;
  DateTime _date = DateTime.now();
  String? _stateFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = DateFormat('yyyy-MM-dd').format(_date);
      _orders = await ref.read(posServiceProvider).getOrders(
            from: d,
            to: d,
            orderState: _stateFilter,
          );
    } catch (_) {
      _orders = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickDate() async {
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
  }

  Future<void> _openOrder(int id) async {
    try {
      final order = await ref.read(posServiceProvider).getOrder(id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => _OrderDetailDialog(
          order: order,
          onChanged: () {
            _load();
            Navigator.pop(ctx);
          },
        ),
      );
      _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd.MM.yyyy');

    return AdminPageLayout(
      title: 'Sifarişlər',
      subtitle: 'Bağlanmış hesablar • ${fmt.format(_date)}',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(fmt.format(_date)),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh, size: 18), label: const Text('Yenilə')),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Wrap(
              spacing: AppSpacing.sm,
              children: [
                FilterChip(
                  label: const Text('Hamısı'),
                  selected: _stateFilter == null,
                  onSelected: (_) {
                    setState(() => _stateFilter = null);
                    _load();
                  },
                ),
                FilterChip(
                  label: const Text('Ödənilib'),
                  selected: _stateFilter == 'paid',
                  onSelected: (_) {
                    setState(() => _stateFilter = 'paid');
                    _load();
                  },
                ),
                FilterChip(
                  label: const Text('Düzəldilib'),
                  selected: _stateFilter == 'adjusted',
                  onSelected: (_) {
                    setState(() => _stateFilter = 'adjusted');
                    _load();
                  },
                ),
                FilterChip(
                  label: const Text('Qaytarılıb'),
                  selected: _stateFilter == 'refunded',
                  onSelected: (_) {
                    setState(() => _stateFilter = 'refunded');
                    _load();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _orders.isEmpty
                    ? Center(child: Text('Bu gün bağlanmış sifariş yoxdur', style: Theme.of(context).textTheme.bodyMedium))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                        itemCount: _orders.length,
                        itemBuilder: (_, i) {
                          final o = _orders[i] as Map<String, dynamic>;
                          return _OrderListTile(order: o, onTap: () => _openOrder(jsonToInt(o['id'])));
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _OrderListTile extends StatelessWidget {
  const _OrderListTile({required this.order, required this.onTap});

  final Map<String, dynamic> order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = order['order_state'] as String? ?? 'paid';
    final total = jsonToDouble(order['total_amount']);
    final timeCharge = jsonToDouble(order['time_charge']);
    final productsTotal = jsonToDouble(order['products_total']);
    final tableName = order['table_name'] as String? ?? (order['session_type'] == 'counter' ? 'Kassa' : '—');
    final closedAt = order['closed_at']?.toString() ?? '';
    final time = closedAt.length >= 16 ? closedAt.substring(11, 16) : closedAt;
    final duration = _formatDuration(jsonToInt(order['active_seconds']));

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: p.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                _OrderStateBadge(state: state),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#${order['id']} • $tableName', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        '$time • ${order['customer_name'] ?? 'Anonim'} • ${_payLabel(order['payment_method'])}',
                        style: TextStyle(fontSize: 11, color: p.textMuted),
                      ),
                      if (timeCharge > 0 || productsTotal > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (timeCharge > 0) 'Vaxt $duration: ${timeCharge.toStringAsFixed(2)} ₼',
                            if (productsTotal > 0) 'Məhsul: ${productsTotal.toStringAsFixed(2)} ₼',
                          ].join(' • '),
                          style: TextStyle(fontSize: 10, color: p.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                MoneyText(amount: state == 'refunded' ? jsonToDouble(order['refund_amount']) : total, size: MoneySize.small),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.chevron_right, color: p.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _payLabel(dynamic m) => switch (m) {
        'cash' => 'Nağd',
        'card' => 'Kart',
        'mixed' => 'Qarışıq',
        _ => '—',
      };

  static String _formatDuration(int seconds) {
    if (seconds <= 0) return '0 dəq';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return '${h}s ${m}dəq';
    return '${m}dəq';
  }
}

class _OrderBillSummary extends StatelessWidget {
  const _OrderBillSummary({required this.order});

  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final timeCharge = jsonToDouble(order['time_charge']);
    final productsTotal = jsonToDouble(order['products_total']);
    final discount = jsonToDouble(order['discount']);
    final total = jsonToDouble(order['total_amount']);
    final seconds = jsonToInt(order['active_seconds']);
    final rate = jsonToDouble(order['hourly_rate_snapshot']);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          if (timeCharge > 0 || seconds > 0)
            _row(context, 'Vaxt (${_OrderListTile._formatDuration(seconds)})', timeCharge, subtitle: rate > 0 ? '${rate.toStringAsFixed(2)} ₼/saat' : null),
          if (productsTotal > 0) _row(context, 'Məhsullar', productsTotal),
          if (discount > 0) _row(context, 'Endirim', discount, valueColor: AppColors.danger, negative: true),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(height: 1),
          ),
          _row(context, 'Ümumi', total, bold: true),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    double amount, {
    String? subtitle,
    Color? valueColor,
    bool bold = false,
    bool negative = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500, fontSize: bold ? 14 : 13)),
                if (subtitle != null) Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            '${negative ? '−' : ''}${amount.toStringAsFixed(2)} ₼',
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              fontSize: bold ? 16 : 14,
              color: valueColor ?? (bold ? AppColors.accent : null),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderDetailLeftColumn extends StatelessWidget {
  const _OrderDetailLeftColumn({
    required this.order,
    required this.payment,
    required this.isRefunded,
    required this.refundAmount,
  });

  final Map<String, dynamic> order;
  final Map<String, dynamic>? payment;
  final bool isRefunded;
  final double refundAmount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OrderBillSummary(order: order),
        if (payment != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _PaymentInfoCard(payment: payment!),
        ],
        if (isRefunded) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Qaytarılan: ${refundAmount.toStringAsFixed(2)} ₼',
            style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

class _OrderDetailRightColumn extends StatelessWidget {
  const _OrderDetailRightColumn({
    required this.items,
    required this.isRefunded,
    required this.timeCtrl,
    required this.prodCtrl,
    required this.discCtrl,
    required this.totalCtrl,
    required this.noteCtrl,
    required this.onRecalc,
  });

  final List<dynamic> items;
  final bool isRefunded;
  final TextEditingController timeCtrl;
  final TextEditingController prodCtrl;
  final TextEditingController discCtrl;
  final TextEditingController totalCtrl;
  final TextEditingController noteCtrl;
  final VoidCallback onRecalc;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OrderItemsSection(items: items),
        if (!isRefunded) ...[
          const SizedBox(height: AppSpacing.xl),
          _OrderAdjustSection(
            timeCtrl: timeCtrl,
            prodCtrl: prodCtrl,
            discCtrl: discCtrl,
            totalCtrl: totalCtrl,
            noteCtrl: noteCtrl,
            onRecalc: onRecalc,
          ),
        ],
      ],
    );
  }
}

class _OrderDetailSingleColumn extends StatelessWidget {
  const _OrderDetailSingleColumn({
    required this.order,
    required this.items,
    required this.payment,
    required this.isRefunded,
    required this.timeCtrl,
    required this.prodCtrl,
    required this.discCtrl,
    required this.totalCtrl,
    required this.noteCtrl,
    required this.onRecalc,
  });

  final Map<String, dynamic> order;
  final List<dynamic> items;
  final Map<String, dynamic>? payment;
  final bool isRefunded;
  final TextEditingController timeCtrl;
  final TextEditingController prodCtrl;
  final TextEditingController discCtrl;
  final TextEditingController totalCtrl;
  final TextEditingController noteCtrl;
  final VoidCallback onRecalc;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OrderBillSummary(order: order),
        if (payment != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _PaymentInfoCard(payment: payment!),
        ],
        const SizedBox(height: AppSpacing.lg),
        _OrderItemsSection(items: items),
        if (!isRefunded) ...[
          const SizedBox(height: AppSpacing.xl),
          _OrderAdjustSection(
            timeCtrl: timeCtrl,
            prodCtrl: prodCtrl,
            discCtrl: discCtrl,
            totalCtrl: totalCtrl,
            noteCtrl: noteCtrl,
            onRecalc: onRecalc,
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              'Qaytarılan: ${jsonToDouble(order['refund_amount']).toStringAsFixed(2)} ₼',
              style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class _PaymentInfoCard extends StatelessWidget {
  const _PaymentInfoCard({required this.payment});

  final Map<String, dynamic> payment;

  String _methodLabel(String? m) => switch (m) {
        'cash' => 'Nağd',
        'card' => 'Kart',
        'mixed' => 'Qarışıq',
        _ => m ?? '—',
      };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final method = payment['method'] as String?;
    final cash = jsonToDouble(payment['cash_amount']);
    final card = jsonToDouble(payment['card_amount']);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ödəniş', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(_methodLabel(method), style: const TextStyle(fontWeight: FontWeight.w600)),
          if (method == 'mixed' || cash > 0) ...[
            const SizedBox(height: 4),
            Text('Nağd: ${cash.toStringAsFixed(2)} ₼', style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (method == 'mixed' || card > 0) ...[
            const SizedBox(height: 2),
            Text('Kart: ${card.toStringAsFixed(2)} ₼', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _OrderItemsSection extends StatelessWidget {
  const _OrderItemsSection({required this.items});

  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Məhsullar', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          if (items.isEmpty)
            Text('Məhsul yoxdur', style: Theme.of(context).textTheme.bodySmall)
          else
            ...items.map((raw) {
              final i = raw as Map<String, dynamic>;
              final lineTotal = jsonToDouble(i['unit_price']) * jsonToInt(i['quantity'], 1);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(i['product_name'] as String, style: const TextStyle(fontWeight: FontWeight.w500))),
                    Text('${i['quantity']} × ${jsonToDouble(i['unit_price']).toStringAsFixed(2)}', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: AppSpacing.md),
                    Text('${lineTotal.toStringAsFixed(2)} ₼', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _OrderAdjustSection extends StatelessWidget {
  const _OrderAdjustSection({
    required this.timeCtrl,
    required this.prodCtrl,
    required this.discCtrl,
    required this.totalCtrl,
    required this.noteCtrl,
    required this.onRecalc,
  });

  final TextEditingController timeCtrl;
  final TextEditingController prodCtrl;
  final TextEditingController discCtrl;
  final TextEditingController totalCtrl;
  final TextEditingController noteCtrl;
  final VoidCallback onRecalc;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Düzəliş', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 420;
              final fields = [
                AppTextField(controller: timeCtrl, label: 'Vaxt ₼', onSubmitted: (_) => onRecalc()),
                AppTextField(controller: prodCtrl, label: 'Məhsul ₼', onSubmitted: (_) => onRecalc()),
                AppTextField(controller: discCtrl, label: 'Endirim ₼', onSubmitted: (_) => onRecalc()),
                AppTextField(controller: totalCtrl, label: 'Ümumi ₼'),
              ];
              if (stacked) {
                return Column(
                  children: [
                    for (var i = 0; i < fields.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.sm),
                      fields[i],
                    ],
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: fields[0]),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: fields[1]),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(child: fields[2]),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: fields[3]),
                    ],
                  ),
                ],
              );
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: onRecalc, child: const Text('Ümumi yenidən hesabla')),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(controller: noteCtrl, label: 'Admin qeydi'),
        ],
      ),
    );
  }
}

class _OrderStateBadge extends StatelessWidget {
  const _OrderStateBadge({required this.state});

  final String state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      'refunded' => ('Qaytarıldı', AppColors.danger),
      'adjusted' => ('Düzəldildi', AppColors.warning),
      _ => ('Ödənilib', AppColors.success),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _OrderDetailDialog extends ConsumerStatefulWidget {
  const _OrderDetailDialog({required this.order, required this.onChanged});

  final Map<String, dynamic> order;
  final VoidCallback onChanged;

  @override
  ConsumerState<_OrderDetailDialog> createState() => _OrderDetailDialogState();
}

class _OrderDetailDialogState extends ConsumerState<_OrderDetailDialog> {
  late final _timeCtrl = TextEditingController(text: jsonToDouble(widget.order['time_charge']).toStringAsFixed(2));
  late final _prodCtrl = TextEditingController(text: jsonToDouble(widget.order['products_total']).toStringAsFixed(2));
  late final _discCtrl = TextEditingController(text: jsonToDouble(widget.order['discount']).toStringAsFixed(2));
  late final _totalCtrl = TextEditingController(text: jsonToDouble(widget.order['total_amount']).toStringAsFixed(2));
  late final _noteCtrl = TextEditingController(text: widget.order['admin_note']?.toString() ?? '');
  bool _restoreStock = true;
  bool _busy = false;

  @override
  void dispose() {
    _timeCtrl.dispose();
    _prodCtrl.dispose();
    _discCtrl.dispose();
    _totalCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _recalcTotal() {
    final t = double.tryParse(_timeCtrl.text) ?? 0;
    final p = double.tryParse(_prodCtrl.text) ?? 0;
    final d = double.tryParse(_discCtrl.text) ?? 0;
    _totalCtrl.text = (t + p - d).toStringAsFixed(2);
  }

  Future<void> _adjust() async {
    setState(() => _busy = true);
    try {
      await ref.read(posServiceProvider).adjustOrder(jsonToInt(widget.order['id']), {
        'time_charge': double.tryParse(_timeCtrl.text) ?? 0,
        'products_total': double.tryParse(_prodCtrl.text) ?? 0,
        'discount': double.tryParse(_discCtrl.text) ?? 0,
        'total_amount': double.tryParse(_totalCtrl.text) ?? 0,
        'admin_note': _noteCtrl.text.trim(),
      });
      if (mounted) {
        showAppSnackBar(context, 'Sifariş düzəldildi');
        widget.onChanged();
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refund() async {
    final confirm = await showAppDialog<bool>(
      context: context,
      title: 'Qaytarma təsdiqi',
      body: const Text('Müştəriyə pul qaytarılacaq. Stok bərpa edilsin?'),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Xeyr')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('Qaytar'),
        ),
      ],
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(posServiceProvider).refundOrder(jsonToInt(widget.order['id']), {
        'restore_stock': _restoreStock,
        'admin_note': _noteCtrl.text.trim(),
      });
      if (mounted) {
        showAppSnackBar(context, 'Qaytarma qeydə alındı');
        widget.onChanged();
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final state = o['order_state'] as String? ?? 'paid';
    final items = o['items'] as List<dynamic>? ?? [];
    final payment = o['payment'] as Map<String, dynamic>?;
    final isRefunded = state == 'refunded';

    final screen = MediaQuery.sizeOf(context);
    final dialogWidth = (screen.width * 0.82).clamp(680.0, 960.0);
    final dialogHeight = (screen.height * 0.88).clamp(520.0, 920.0);
    final twoColumns = dialogWidth >= 760;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sifariş #${o['id']}', style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 4),
                        Text(
                          '${o['table_name'] ?? 'Kassa'} • ${o['closed_at']}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (o['receipt'] != null)
                          Text(
                            'Çek: ${(o['receipt'] as Map)['receipt_number']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  _OrderStateBadge(state: state),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: twoColumns
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _OrderDetailLeftColumn(
                              order: o,
                              payment: payment,
                              isRefunded: isRefunded,
                              refundAmount: jsonToDouble(o['refund_amount']),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xxl),
                          Expanded(
                            child: _OrderDetailRightColumn(
                              items: items,
                              isRefunded: isRefunded,
                              timeCtrl: _timeCtrl,
                              prodCtrl: _prodCtrl,
                              discCtrl: _discCtrl,
                              totalCtrl: _totalCtrl,
                              noteCtrl: _noteCtrl,
                              onRecalc: _recalcTotal,
                            ),
                          ),
                        ],
                      )
                    : _OrderDetailSingleColumn(
                        order: o,
                        items: items,
                        payment: payment,
                        isRefunded: isRefunded,
                        timeCtrl: _timeCtrl,
                        prodCtrl: _prodCtrl,
                        discCtrl: _discCtrl,
                        totalCtrl: _totalCtrl,
                        noteCtrl: _noteCtrl,
                        onRecalc: _recalcTotal,
                      ),
              ),
            ),
            if (!isRefunded) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.xl),
                child: Row(
                  children: [
                    Expanded(
                      child: CheckboxListTile(
                        value: _restoreStock,
                        onChanged: (v) => setState(() => _restoreStock = v ?? true),
                        title: const Text('Stoku bərpa et (qaytarma)', style: TextStyle(fontSize: 13)),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                    OutlinedButton(
                      onPressed: _busy ? null : _refund,
                      child: const Text('Qaytarma'),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    FilledButton(
                      onPressed: _busy ? null : _adjust,
                      child: _busy
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Saxla (düzəliş)'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
