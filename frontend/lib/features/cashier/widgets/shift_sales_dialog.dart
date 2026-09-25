import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/cashier_theme.dart';
import '../../../core/utils/json_parse.dart';
import '../../../services/pos_service.dart';
import '../../admin/widgets/shift_activity_visual.dart';
import '../shift_provider.dart';

enum _SalesFilter { all, sessions, deleted }

/// Kassir üçün oxumaq-yalnız növbə satışları (Sil/Qaytar/Düzəliş yoxdur).
Future<void> showShiftSalesDialog(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> shiftHint,
) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => _ShiftSalesDialog(shiftHint: shiftHint),
  );
}

class _ShiftSalesDialog extends ConsumerStatefulWidget {
  const _ShiftSalesDialog({required this.shiftHint});

  final Map<String, dynamic> shiftHint;

  @override
  ConsumerState<_ShiftSalesDialog> createState() => _ShiftSalesDialogState();
}

class _ShiftSalesDialogState extends ConsumerState<_ShiftSalesDialog> {
  Map<String, dynamic>? _shift;
  bool _loading = true;
  String? _error;
  _SalesFilter _filter = _SalesFilter.all;
  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();
    _shift = widget.shiftHint;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // current() indi activity qaytarır — kassir üçün təhlükəsiz endpoint.
      final current = await ref.read(posServiceProvider).getCurrentShift();
      if (!mounted) return;
      if (current == null) {
        setState(() {
          _error = 'Açıq növbə tapılmadı';
          _loading = false;
        });
        return;
      }
      setState(() {
        _shift = current;
        _loading = false;
      });
      refreshCurrentShift(ref);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _filteredActivity() {
    final raw = _shift?['activity'] as List<dynamic>? ?? [];
    final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    list.sort((a, b) => (a['at']?.toString() ?? '').compareTo(b['at']?.toString() ?? ''));
    return switch (_filter) {
      _SalesFilter.sessions => list
          .where((a) => a['kind'] == 'session')
          .toList(),
      _SalesFilter.deleted => list.where((a) => a['kind'] == 'order_deleted').toList(),
      _ => list.where((a) {
          final k = a['kind'] as String? ?? '';
          return k == 'session' || k == 'order_deleted' || k == 'cash_movement';
        }).toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final dialogWidth = (screen.width * 0.86).clamp(420.0, 720.0);
    final dialogHeight = (screen.height * 0.86).clamp(420.0, 820.0);
    final bg = CashierTheme.surfaceRaised(context);

    return Dialog(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CashierTheme.radiusCard + 4),
        side: BorderSide(color: CashierTheme.border(context)),
      ),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: CashierTheme.accent(context),
                ),
              )
            : _error != null
                ? _ErrorBody(message: _error!, onRetry: _load, onClose: () => Navigator.pop(context))
                : _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final shift = _shift!;
    final totals = shift['totals'] as Map<String, dynamic>? ?? {};
    final activity = _filteredActivity();
    final timeFmt = DateFormat('HH:mm');
    final cashSales = jsonToDouble(totals['cash_sales']);
    final cardSales = jsonToDouble(totals['card_sales']);
    final sessionCount = activity.where((a) => a['kind'] == 'session').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bugünkü satışlar', style: CashierTheme.stationTitle(context, size: 20)),
                    const SizedBox(height: 4),
                    Text(
                      'Növbə #${shift['id']} · Nağd ${cashSales.toStringAsFixed(2)} · Kart ${cardSales.toStringAsFixed(2)} · $sessionCount satış',
                      style: CashierTheme.caption(context),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _load,
                tooltip: 'Yenilə',
                icon: Icon(Icons.refresh, color: CashierTheme.textTertiary(context)),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: CashierTheme.textTertiary(context)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Wrap(
            spacing: AppSpacing.sm,
            children: [
              FilterChip(
                label: const Text('Hamısı'),
                selected: _filter == _SalesFilter.all,
                onSelected: (_) => setState(() => _filter = _SalesFilter.all),
              ),
              FilterChip(
                label: const Text('Satışlar'),
                selected: _filter == _SalesFilter.sessions,
                onSelected: (_) => setState(() => _filter = _SalesFilter.sessions),
              ),
              FilterChip(
                label: const Text('Ləğv edilənlər'),
                selected: _filter == _SalesFilter.deleted,
                selectedColor: AdminTheme.danger(context).withValues(alpha: 0.18),
                checkmarkColor: AdminTheme.danger(context),
                onSelected: (_) => setState(() => _filter = _SalesFilter.deleted),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Divider(height: 1, color: CashierTheme.border(context)),
        Expanded(
          child: activity.isEmpty
              ? Center(
                  child: Text(
                    'Bu filtrdə satış yoxdur',
                    style: CashierTheme.caption(context),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  itemCount: activity.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final row = activity[i];
                    final kind = row['kind'] as String? ?? '';
                    final sid = jsonToInt(row['session_id']);
                    final expandable = kind == 'session' || kind == 'order_deleted';
                    final expanded = expandable && _expanded.contains(sid);
                    return _SaleTile(
                      index: i + 1,
                      row: row,
                      timeFmt: timeFmt,
                      expanded: expanded,
                      onTap: expandable
                          ? () {
                              setState(() {
                                if (_expanded.contains(sid)) {
                                  _expanded.remove(sid);
                                } else {
                                  _expanded.add(sid);
                                }
                              });
                            }
                          : null,
                    );
                  },
                ),
        ),
        Divider(height: 1, color: CashierTheme.border(context)),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Bağla'),
            ),
          ),
        ),
      ],
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({
    required this.index,
    required this.row,
    required this.timeFmt,
    required this.expanded,
    this.onTap,
  });

  final int index;
  final Map<String, dynamic> row;
  final DateFormat timeFmt;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final kind = row['kind'] as String? ?? '';
    final sign = row['sign'] as String? ?? '+';
    final amount = jsonToDouble(row['amount']);
    final at = row['at']?.toString() ?? '';
    final title = row['title']?.toString() ?? '—';
    final closedBy = row['closed_by_name']?.toString();
    final lines = row['lines'] as List<dynamic>? ?? [];
    DateTime? parsed;
    try {
      parsed = DateTime.parse(at);
    } catch (_) {}
    final timeLabel = parsed != null ? timeFmt.format(parsed.toLocal()) : at;
    final visual = ShiftActivityVisual.resolve(context, row);
    final danger = AdminTheme.danger(context);
    final isDeleted = kind == 'order_deleted';

    return Material(
      color: visual.surface ?? CashierTheme.surfaceSecondary(context),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: visual.border, width: isDeleted ? 2 : 1),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$index.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: visual.index,
                      ),
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: visual.iconBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(visual.icon, size: 18, color: visual.accent),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: CashierTheme.stationTitle(context, size: 14).copyWith(
                            color: isDeleted ? danger : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            timeLabel,
                            if (closedBy != null && closedBy.isNotEmpty) closedBy,
                          ].join(' · '),
                          style: CashierTheme.caption(context),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$sign${amount.toStringAsFixed(2)} ₼',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: visual.amount,
                    ),
                  ),
                  if (onTap != null && lines.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: CashierTheme.textTertiary(context),
                    ),
                  ],
                ],
              ),
              if (expanded && lines.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Divider(height: 1, color: CashierTheme.border(context)),
                const SizedBox(height: AppSpacing.sm),
                ...lines.map((raw) {
                  final line = Map<String, dynamic>.from(raw as Map);
                  final label = line['label']?.toString() ?? '';
                  final lineAmt = line['amount'];
                  final amt = lineAmt == null ? null : jsonToDouble(lineAmt);
                  return Padding(
                    padding: const EdgeInsets.only(left: 50, bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(label, style: CashierTheme.caption(context).copyWith(fontSize: 13)),
                        ),
                        if (amt != null)
                          Text(
                            '${amt.toStringAsFixed(2)} ₼',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: amt < 0 ? danger : CashierTheme.textPrimary(context),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message,
    required this.onRetry,
    required this.onClose,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_outlined, size: 48, color: CashierTheme.textTertiary(context)),
          const SizedBox(height: AppSpacing.lg),
          Text(message, textAlign: TextAlign.center, style: CashierTheme.caption(context)),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(onPressed: onClose, child: const Text('Bağla')),
              const SizedBox(width: AppSpacing.md),
              FilledButton(onPressed: onRetry, child: const Text('Yenidən')),
            ],
          ),
        ],
      ),
    );
  }
}
