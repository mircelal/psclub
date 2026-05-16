import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/business_config_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/cashier_theme.dart';
import '../../../core/theme/table_status_theme.dart';
import '../../../core/utils/json_parse.dart';
import '../../../core/utils/table_tariff_utils.dart';
import '../../../core/widgets/money_text.dart';
import '../../../core/widgets/status_badge.dart';
import 'table_live_state.dart';
import 'table_session_items.dart';
import 'time_expired_alert.dart';
import 'timer_display.dart';

class TableCard extends ConsumerStatefulWidget {
  const TableCard({
    super.key,
    required this.table,
    required this.tick,
    required this.onTap,
    this.onSecondaryTap,
    this.compact = false,
  });

  final Map<String, dynamic> table;
  final int tick;
  final VoidCallback onTap;
  final void Function(TapDownDetails details)? onSecondaryTap;
  final bool compact;

  @override
  ConsumerState<TableCard> createState() => _TableCardState();
}

class _TableCardState extends ConsumerState<TableCard> with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncBlinkAnimation());
  }

  @override
  void didUpdateWidget(covariant TableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncBlinkAnimation());
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  bool _isExpired() {
    if (widget.table['session_id'] == null) return false;
    final config = ref.read(businessConfigProvider).valueOrNull ?? BusinessConfig.fallback;
    return computeTableLive(
          widget.table,
          billingMode: config.billingMode,
          timeBillingEnabled: config.timeBillingEnabled,
        )?.isExpired ??
        false;
  }

  void _syncBlinkAnimation() {
    if (!mounted) return;
    final isExpired = _isExpired();
    if (isExpired) {
      if (!_blink.isAnimating) _blink.repeat(reverse: true);
    } else if (_blink.isAnimating) {
      _blink.stop();
      _blink.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.table['status'] as String? ?? 'empty';
    final hasSession = widget.table['session_id'] != null;
    final isPaused = status == 'paused' || widget.table['session_status'] == 'paused';
    final config = ref.watch(businessConfigProvider).valueOrNull ?? BusinessConfig.fallback;
    final live = hasSession
        ? computeTableLive(
            widget.table,
            billingMode: config.billingMode,
            timeBillingEnabled: config.timeBillingEnabled,
          )
        : null;
    final name = widget.table['name'] as String;
    final rate = jsonToDouble(widget.table['session_hourly_rate'] ?? widget.table['hourly_rate']);
    final tariffLabel = widget.table['session_set_name'] as String? ?? activeSessionTariffLabel(widget.table);
    final rateSummary = formatTableTariffSummary(widget.table);

    final sessionId = widget.table['session_id'] as int?;
    final isExpired = live?.isExpired ?? false;
    TimeExpiredAlert.check(sessionId, isExpired);

    var cardStyle = context.tableStatusStyle(status, hasSession: hasSession);
    if (isExpired) {
      cardStyle = TableStatusTheme.expiredOverlay(cardStyle, _blink.value);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        onSecondaryTapDown: widget.onSecondaryTap,
        borderRadius: BorderRadius.circular(CashierTheme.radiusCard),
        child: AnimatedBuilder(
          animation: _blink,
          builder: (context, child) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: cardStyle.cardFill,
              borderRadius: BorderRadius.circular(CashierTheme.radiusCard),
              border: Border.all(color: cardStyle.cardBorder, width: cardStyle.borderWidth),
              boxShadow: cardStyle.cardShadow ?? CashierTheme.cardShadow(context),
            ),
            child: child,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(CashierTheme.radiusCard),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(height: cardStyle.accentBarWidth, color: cardStyle.accent),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(widget.compact ? 12 : 14),
                    child: hasSession && live != null
                        ? _ActiveBody(
                            name: name,
                            rate: rate,
                            status: status,
                            hasSession: hasSession,
                            live: live,
                            isPaused: isPaused,
                            tick: widget.tick,
                            compact: widget.compact,
                            cardStyle: cardStyle,
                            timeBillingEnabled: config.timeBillingEnabled,
                            tariffLabel: tariffLabel,
                          )
                        : _EmptyBody(
                            name: name,
                            rate: rate,
                            rateSummary: rateSummary,
                            status: status,
                            cardStyle: cardStyle,
                            compact: widget.compact,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveBody extends StatelessWidget {
  const _ActiveBody({
    required this.name,
    required this.rate,
    required this.status,
    required this.hasSession,
    required this.live,
    required this.isPaused,
    required this.tick,
    required this.compact,
    required this.cardStyle,
    required this.timeBillingEnabled,
    this.tariffLabel,
  });

  final String name;
  final double rate;
  final String status;
  final bool hasSession;
  final TableLiveSnapshot live;
  final bool isPaused;
  final int tick;
  final bool compact;
  final TableStatusStyle cardStyle;
  final bool timeBillingEnabled;
  final String? tariffLabel;

  @override
  Widget build(BuildContext context) {
    final bill = live.bill;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(name, style: CashierTheme.stationTitle(context, size: compact ? 15 : 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
            StatusBadge(label: _statusLabel(status), status: status, hasSession: hasSession),
          ],
        ),
        const Spacer(flex: 1),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: TimerDisplay(
              bill: bill,
              isPaused: isPaused,
              tick: tick,
              compact: compact,
              large: !compact,
              isExpired: live.isExpired,
              isUrgent: live.isUrgent,
              color: cardStyle.accent,
            ),
          ),
        ),
        if (!compact && ((timeBillingEnabled && bill.timeCharge > 0) || bill.productsTotal > 0)) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              if (timeBillingEnabled && bill.timeCharge > 0)
                Expanded(child: _BreakdownChip(label: 'Vaxt', amount: bill.timeCharge, color: cardStyle.accent)),
              if (timeBillingEnabled && bill.timeCharge > 0 && bill.productsTotal > 0) const SizedBox(width: 6),
              if (bill.productsTotal > 0)
                Expanded(child: _BreakdownChip(label: 'Məhsul', amount: bill.productsTotal, color: const Color(0xFF5856D6))),
            ],
          ),
        ],
        if (!compact && live.items.isNotEmpty) ...[
          const SizedBox(height: 4),
          TableSessionItems(items: live.items, compact: true, maxVisible: 2),
        ],
        const Spacer(flex: 1),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cardStyle.timerZoneFill,
            borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
            border: Border.all(color: cardStyle.cardBorder.withValues(alpha: 0.85)),
          ),
          child: Row(
            children: [
              Text('Cəmi', style: CashierTheme.caption(context)),
              const Spacer(),
              MoneyText(
                amount: bill.totalAmount,
                size: compact ? MoneySize.medium : MoneySize.large,
                color: cardStyle.moneyColor ?? CashierTheme.textPrimary(context),
                suffix: ' ₼',
              ),
            ],
          ),
        ),
        if (tariffLabel != null && !compact) ...[
          const SizedBox(height: 4),
          Text(tariffLabel!, style: CashierTheme.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
        ] else if (!compact) ...[
          const SizedBox(height: 4),
          Text('${rate.toStringAsFixed(2)} ₼/saat', style: CashierTheme.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ],
    );
  }

  String _statusLabel(String s) => switch (s) {
        'empty' => 'Boş',
        'active' => 'Aktiv',
        'paused' => 'Pause',
        _ => s,
      };
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({
    required this.name,
    required this.rate,
    required this.status,
    required this.cardStyle,
    required this.rateSummary,
    required this.compact,
  });

  final String name;
  final double rate;
  final String rateSummary;
  final String status;
  final TableStatusStyle cardStyle;
  final bool compact;

  String get _initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: compact ? 36 : 40,
              height: compact ? 36 : 40,
              decoration: BoxDecoration(
                color: cardStyle.badgeFill,
                borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
                border: Border.all(color: cardStyle.badgeBorder),
              ),
              alignment: Alignment.center,
              child: Text(
                _initial,
                style: TextStyle(
                  fontSize: compact ? 16 : 18,
                  fontWeight: FontWeight.w600,
                  color: cardStyle.accent,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: CashierTheme.stationTitle(context, size: compact ? 14 : 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('Hazır', style: CashierTheme.caption(context)),
                ],
              ),
            ),
            StatusBadge(label: 'Boş', status: status, hasSession: false),
          ],
        ),
        const Spacer(flex: 1),
        _MetaRow(icon: Icons.payments_outlined, label: 'Tariflər', value: rateSummary),
        if (!compact) ...[
          const SizedBox(height: 6),
          _MetaRow(icon: Icons.event_available_outlined, label: 'Status', value: 'Sessiya gözləyir'),
        ],
        const Spacer(flex: 1),
        SizedBox(
          width: double.infinity,
          height: compact ? 34 : 36,
          child: FilledButton(
            onPressed: null,
            style: FilledButton.styleFrom(
              backgroundColor: CashierTheme.accent(context),
              disabledBackgroundColor: CashierTheme.accent(context),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CashierTheme.radiusControl + 2)),
              padding: EdgeInsets.zero,
            ),
            child: const Text('Sessiya aç', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
          ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: CashierTheme.surfaceSecondary(context),
        borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
        border: Border.all(color: CashierTheme.border(context).withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: CashierTheme.textSecondary(context)),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: CashierTheme.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CashierTheme.textPrimary(context)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownChip extends StatelessWidget {
  const _BreakdownChip({required this.label, required this.amount, required this.color});

  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color.withValues(alpha: 0.85))),
          Text(
            amount.toStringAsFixed(2),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color, letterSpacing: -0.3),
          ),
        ],
      ),
    );
  }
}

class BillSummaryCard extends StatelessWidget {
  const BillSummaryCard({
    super.key,
    required this.timeCharge,
    required this.productsTotal,
    required this.total,
    required this.activeMinutes,
    this.timeLabel,
  });

  final double timeCharge;
  final double productsTotal;
  final double total;
  final int activeMinutes;
  final String? timeLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: CashierTheme.surface(context),
        borderRadius: BorderRadius.circular(CashierTheme.radiusCard),
        border: CashierTheme.cardBorder(context),
        boxShadow: CashierTheme.cardShadow(context),
      ),
      child: Column(
        children: [
          if (timeLabel != null) ...[
            _row(context, timeLabel!, timeCharge),
            const SizedBox(height: AppSpacing.sm),
          ] else if (timeCharge > 0) ...[
            _row(context, 'Vaxt ($activeMinutes dəq)', timeCharge),
            const SizedBox(height: AppSpacing.sm),
          ],
          _row(context, 'Məhsullar', productsTotal),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ÜMUMİ', style: Theme.of(context).textTheme.labelLarge),
              MoneyText(
                amount: total,
                size: MoneySize.large,
                color: Theme.of(context).brightness == Brightness.light
                    ? const Color(0xFF34C759)
                    : AppColors.accent,
                suffix: ' ₼',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        MoneyText(amount: amount, size: MoneySize.small, suffix: ' ₼'),
      ],
    );
  }
}
