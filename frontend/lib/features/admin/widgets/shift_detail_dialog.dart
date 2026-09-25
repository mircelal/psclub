import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/cashier_theme.dart';
import '../../../core/utils/json_parse.dart';
import '../../../services/pos_service.dart';
import '../orders_screen.dart';
import 'shift_activity_visual.dart';

enum _ShiftActivityFilter { all, sessions, movements, deleted }

Future<void> showShiftDetailDialog(
  BuildContext context,
  WidgetRef ref,
  int shiftId, {
  Map<String, dynamic>? categories,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => _ShiftDetailDialog(
      shiftId: shiftId,
      categories: categories ?? {},
    ),
  );
}

class _ShiftDetailDialog extends ConsumerStatefulWidget {
  const _ShiftDetailDialog({
    required this.shiftId,
    required this.categories,
  });

  final int shiftId;
  final Map<String, dynamic> categories;

  @override
  ConsumerState<_ShiftDetailDialog> createState() => _ShiftDetailDialogState();
}

class _ShiftDetailDialogState extends ConsumerState<_ShiftDetailDialog> {
  Map<String, dynamic>? _shift;
  bool _loading = true;
  String? _error;
  _ShiftActivityFilter _filter = _ShiftActivityFilter.all;
  final Set<int> _expandedSessions = {};
  final Set<int> _expandedMovements = {};

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
      final shift = await ref.read(posServiceProvider).getShift(widget.shiftId);
      if (!mounted) return;
      setState(() {
        _shift = shift;
        _loading = false;
      });
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
    final list = raw.map((e) => e as Map<String, dynamic>).toList();
    list.sort((a, b) => (a['at']?.toString() ?? '').compareTo(b['at']?.toString() ?? ''));
    return switch (_filter) {
      _ShiftActivityFilter.sessions => list
          .where((a) => a['kind'] == 'session' || a['kind'] == 'order_deleted')
          .toList(),
      _ShiftActivityFilter.movements =>
        list.where((a) => a['kind'] == 'cash_movement').toList(),
      _ShiftActivityFilter.deleted =>
        list.where((a) => a['kind'] == 'order_deleted').toList(),
      _ => list,
    };
  }

  /// 0 = açılış, 1..n = jurnal, son = bağlanış (bağlı növbədə).
  List<({int index, Map<String, dynamic> row})> _buildTimeline(
    Map<String, dynamic> shift,
    List<Map<String, dynamic>> middle,
  ) {
    final opening = jsonToDouble(shift['opening_cash']);
    final isClosed = shift['status'] == 'closed';
    final out = <({int index, Map<String, dynamic> row})>[
      (
        index: 0,
        row: {
          'kind': 'shift_open',
          'at': shift['opened_at']?.toString() ?? '',
          'title': 'Növbə açıldı',
          'subtitle': '${opening.toStringAsFixed(2)} AZN ilə açıldı',
          'amount': opening,
        },
      ),
    ];
    var seq = 1;
    for (final row in middle) {
      out.add((index: seq, row: row));
      seq++;
    }
    if (isClosed) {
      final closing = jsonToDouble(shift['closing_cash']);
      out.add((
        index: seq,
        row: {
          'kind': 'shift_close',
          'at': shift['closed_at']?.toString() ?? '',
          'title': 'Növbə bağlandı',
          'subtitle': '${closing.toStringAsFixed(2)} AZN ilə növbə bağlandı',
          'amount': closing,
        },
      ));
    }
    return out;
  }

  Future<void> _openSession(int sessionId) async {
    await showAdminOrderDetailDialog(context, ref, sessionId, onChanged: _load);
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final dialogWidth = (screen.width * 0.82).clamp(680.0, 960.0);
    final dialogHeight = (screen.height * 0.88).clamp(520.0, 920.0);
    final bg = CashierTheme.surfaceRaised(context);

    return Dialog(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
    final isOpen = shift['status'] == 'open';
    final totals = shift['totals'] as Map<String, dynamic>? ?? {};
    final middle = _filteredActivity();
    final timeline = _buildTimeline(shift, middle);
    final timeFmt = DateFormat('dd.MM.yyyy HH:mm');
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Növbə #${shift['id']}',
                      style: CashierTheme.stationTitle(context, size: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${shift['opened_by_name'] ?? '—'} · ${shift['opened_at']}${isOpen ? '' : ' — ${shift['closed_at'] ?? ''}'}',
                      style: CashierTheme.caption(context).copyWith(fontSize: 13),
                    ),
                    if ((shift['notes']?.toString().trim().isNotEmpty ?? false) && !isOpen) ...[
                      const SizedBox(height: 6),
                      Text('Qeyd: ${shift['notes']}', style: CashierTheme.caption(context)),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isOpen
                            ? AdminTheme.success(context).withValues(alpha: 0.12)
                            : CashierTheme.surfaceSecondary(context),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        border: Border.all(
                          color: isOpen
                              ? AdminTheme.success(context).withValues(alpha: 0.35)
                              : CashierTheme.border(context),
                        ),
                      ),
                      child: Text(
                        isOpen ? 'Açıq növbə' : 'Bağlı növbə',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isOpen ? AdminTheme.success(context) : CashierTheme.textSecondary(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: CashierTheme.textTertiary(context)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: _SummaryGrid(
            shift: shift,
            totals: totals,
            isOpen: isOpen,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Wrap(
            spacing: AppSpacing.sm,
            children: [
              FilterChip(
                label: const Text('Hamısı'),
                selected: _filter == _ShiftActivityFilter.all,
                onSelected: (_) => setState(() => _filter = _ShiftActivityFilter.all),
              ),
              FilterChip(
                label: const Text('Satışlar'),
                selected: _filter == _ShiftActivityFilter.sessions,
                onSelected: (_) => setState(() => _filter = _ShiftActivityFilter.sessions),
              ),
              FilterChip(
                label: const Text('Kassa hərəkətləri'),
                selected: _filter == _ShiftActivityFilter.movements,
                onSelected: (_) => setState(() => _filter = _ShiftActivityFilter.movements),
              ),
              FilterChip(
                label: const Text('Silinmələr'),
                selected: _filter == _ShiftActivityFilter.deleted,
                selectedColor: AdminTheme.danger(context).withValues(alpha: 0.18),
                checkmarkColor: AdminTheme.danger(context),
                labelStyle: TextStyle(
                  color: _filter == _ShiftActivityFilter.deleted
                      ? AdminTheme.danger(context)
                      : CashierTheme.textPrimary(context),
                  fontWeight: _filter == _ShiftActivityFilter.deleted ? FontWeight.w700 : FontWeight.w500,
                ),
                side: BorderSide(
                  color: _filter == _ShiftActivityFilter.deleted
                      ? AdminTheme.danger(context)
                      : CashierTheme.border(context),
                ),
                onSelected: (_) => setState(() => _filter = _ShiftActivityFilter.deleted),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.sm),
          child: Text('Jurnal', style: CashierTheme.sectionTitle(context)),
        ),
        Divider(height: 1, color: CashierTheme.border(context)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  itemCount: timeline.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final entry = timeline[i];
                    final row = entry.row;
                    final kind = row['kind'] as String? ?? '';
                    final isDeleted = kind == 'order_deleted';
                    final isMovement = kind == 'cash_movement';
                    final movementId = jsonToInt(row['movement_id']);
                    return _ActivityTile(
                      sequenceIndex: entry.index,
                      row: row,
                      timeFmt: timeFmt,
                      expanded: isMovement
                          ? _expandedMovements.contains(movementId)
                          : (kind == 'session' || isDeleted) &&
                              _expandedSessions.contains(jsonToInt(row['session_id'])),
                      onTap: () {
                        if (isMovement) {
                          final lines = row['lines'] as List<dynamic>? ?? [];
                          if (lines.isEmpty) return;
                          setState(() {
                            if (_expandedMovements.contains(movementId)) {
                              _expandedMovements.remove(movementId);
                            } else {
                              _expandedMovements.add(movementId);
                            }
                          });
                          return;
                        }
                        if (kind == 'session' || isDeleted) {
                          final sid = jsonToInt(row['session_id']);
                          final lines = row['lines'] as List<dynamic>? ?? [];
                          if (lines.isNotEmpty) {
                            setState(() {
                              if (_expandedSessions.contains(sid)) {
                                _expandedSessions.remove(sid);
                              } else {
                                _expandedSessions.add(sid);
                              }
                            });
                          } else {
                            _openSession(sid);
                          }
                        }
                      },
                      onOpenSession: kind == 'session' || kind == 'order_deleted'
                          ? () => _openSession(jsonToInt(row['session_id']))
                          : null,
                    );
                  },
                ),
              ),
              if (middle.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.md),
                  child: Text(
                    isOpen
                        ? 'Bu filtrdə əlavə əməliyyat yoxdur.'
                        : 'Bu filtrdə satış/xərc qeydi yoxdur (yalnız açılış və bağlanış).',
                    style: CashierTheme.caption(context),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: CashierTheme.border(context)),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
              child: const Text('Bağla'),
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({
    required this.shift,
    required this.totals,
    required this.isOpen,
  });

  final Map<String, dynamic> shift;
  final Map<String, dynamic> totals;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final opening = jsonToDouble(shift['opening_cash']);
    final expected = jsonToDouble(totals['expected_cash']);
    final cashSales = jsonToDouble(totals['cash_sales']);
    final cardSales = jsonToDouble(totals['card_sales']);
    final expenses = jsonToDouble(totals['expenses']);
    final payIns = jsonToDouble(totals['pay_ins']);
    final refunds = jsonToDouble(totals['refunds']);
    final diff = jsonToDouble(shift['cash_difference']);
    final closing = jsonToDouble(shift['closing_cash']);

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      children: [
        _SummaryChip(label: 'Başlanğıc kassa', value: opening),
        _SummaryChip(label: 'Nağd satış', value: cashSales),
        _SummaryChip(label: 'Kart satış', value: cardSales),
        if (expenses > 0) _SummaryChip(label: 'Xərclər', value: expenses, negative: true),
        if (payIns > 0) _SummaryChip(label: 'Kassaya əlavə', value: payIns),
        if (refunds > 0) _SummaryChip(label: 'Qaytarmalar', value: refunds, negative: true),
        _SummaryChip(label: isOpen ? 'Gözlənilən kassa' : 'Gözlənilən', value: expected, bold: true),
        if (!isOpen) ...[
          _SummaryChip(label: 'Sayılan', value: closing),
          if (diff != 0)
            _SummaryChip(
              label: 'Fərq',
              value: diff,
              highlight: true,
            ),
        ],
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    this.negative = false,
    this.bold = false,
    this.highlight = false,
  });

  final String label;
  final double value;
  final bool negative;
  final bool bold;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final warning = AdminTheme.warning(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? warning.withValues(alpha: 0.12) : CashierTheme.surfaceSecondary(context),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: highlight ? warning.withValues(alpha: 0.4) : CashierTheme.border(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: CashierTheme.caption(context)),
          const SizedBox(height: 2),
          Text(
            '${negative ? '−' : ''}${value.toStringAsFixed(2)} AZN',
            style: CashierTheme.metricValue(context).copyWith(
              fontSize: bold ? 18 : 15,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: highlight ? warning : CashierTheme.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.sequenceIndex,
    required this.row,
    required this.timeFmt,
    required this.expanded,
    required this.onTap,
    this.onOpenSession,
  });

  final int sequenceIndex;
  final Map<String, dynamic> row;
  final DateFormat timeFmt;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback? onOpenSession;

  @override
  Widget build(BuildContext context) {
    final kind = row['kind'] as String? ?? '';
    final isBoundary = kind == 'shift_open' || kind == 'shift_close';
    final sign = row['sign'] as String? ?? '+';
    final showAmount = !isBoundary;
    final amount = jsonToDouble(row['amount']);
    final at = row['at']?.toString() ?? '';
    final title = row['title']?.toString() ?? '—';
    final subtitle = row['subtitle']?.toString();
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
        onTap: isBoundary ? null : onTap,
        onLongPress: onOpenSession,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: visual.border,
              width: isDeleted ? 2 : (isBoundary ? 1.5 : 1),
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      '$sequenceIndex.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: visual.index,
                        height: 1.3,
                      ),
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: visual.iconBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(visual.icon, size: 20, color: visual.accent),
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
                            fontWeight: isDeleted ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: CashierTheme.caption(context).copyWith(
                              fontWeight: FontWeight.w600,
                              color: isDeleted ? danger.withValues(alpha: 0.85) : CashierTheme.textPrimary(context),
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          timeLabel,
                          style: CashierTheme.caption(context).copyWith(
                            color: isDeleted ? danger.withValues(alpha: 0.7) : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showAmount)
                    Text(
                      '$sign${amount.toStringAsFixed(2)} AZN',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: showAmount ? visual.amount : visual.accent,
                      ),
                    ),
                  if ((kind == 'session' || isDeleted || kind == 'cash_movement') && lines.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: isDeleted ? danger : CashierTheme.textTertiary(context),
                    ),
                  ],
                ],
              ),
              if (expanded && lines.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Divider(height: 1, color: CashierTheme.border(context)),
                const SizedBox(height: AppSpacing.sm),
                ...lines.map((raw) {
                  final line = raw as Map<String, dynamic>;
                  final label = line['label']?.toString() ?? '';
                  final lineAmt = line['amount'];
                  final amt = lineAmt == null ? null : jsonToDouble(lineAmt);
                  return Padding(
                    padding: const EdgeInsets.only(left: 56, bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: CashierTheme.caption(context).copyWith(
                              fontSize: 13,
                              color: isDeleted ? danger.withValues(alpha: 0.9) : null,
                            ),
                          ),
                        ),
                        if (amt != null)
                          Text(
                            '${amt.toStringAsFixed(2)} AZN',
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
                if (onOpenSession != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onOpenSession,
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Sifariş detalları'),
                    ),
                  ),
                ],
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
          Text(
            message,
            textAlign: TextAlign.center,
            style: CashierTheme.caption(context).copyWith(fontSize: 14),
          ),
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
