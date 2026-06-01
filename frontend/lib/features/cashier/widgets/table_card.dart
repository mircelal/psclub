import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/business_config_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/cashier_theme.dart';
import '../../../core/theme/table_status_theme.dart';
import '../../../core/utils/json_parse.dart';
import '../../../core/utils/package_session.dart';
import '../../../core/utils/table_tariff_utils.dart';
import '../../../core/widgets/money_text.dart';
import '../../../services/pos_service.dart';
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
    this.mobile = false,
  });

  final Map<String, dynamic> table;
  final int tick;
  final VoidCallback onTap;
  final void Function(TapDownDetails details)? onSecondaryTap;
  final bool compact;
  final bool mobile;

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
    if (oldWidget.table['session_id'] != widget.table['session_id'] ||
        oldWidget.table['status'] != widget.table['status'] ||
        oldWidget.table['session_status'] != widget.table['session_status']) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncBlinkAnimation());
    } else {
      _syncBlinkAnimation();
    }
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
          billingMode: config.chargeBillingMode,
          timeBillingEnabled: config.timeBillingEnabled,
          minBillingMinutes: config.minBillingMinutes,
          billingIncrementMinutes: config.billingIncrementMinutes,
          billingGraceMinutes: config.billingGraceMinutes,
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
            billingMode: config.chargeBillingMode,
            timeBillingEnabled: config.timeBillingEnabled,
            minBillingMinutes: config.minBillingMinutes,
            billingIncrementMinutes: config.billingIncrementMinutes,
            billingGraceMinutes: config.billingGraceMinutes,
          )
        : null;
    final name = widget.table['name'] as String;
    final rate = jsonToDouble(widget.table['session_hourly_rate'] ?? widget.table['hourly_rate']);
    final tariffLabel = widget.table['session_set_name'] as String? ?? activeSessionTariffLabel(widget.table);
    final promos = ref.watch(activePromotionsProvider).valueOrNull ?? [];
    final rateSummary = formatEffectiveTariffSummary(widget.table, promos);

    final sessionId = widget.table['session_id'] as int?;
    final isExpired = live?.isExpired ?? false;
    TimeExpiredAlert.check(sessionId, isExpired);

    var cardStyle = context.tableStatusStyle(status, hasSession: hasSession);
    if (isExpired) {
      cardStyle = TableStatusTheme.expiredOverlay(context, cardStyle, _blink.value);
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
                    padding: EdgeInsets.all(widget.mobile ? 10 : (widget.compact ? 12 : 14)),
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
                            mobile: widget.mobile,
                            cardStyle: cardStyle,
                            timeBillingEnabled: config.timeBillingEnabled,
                            tariffLabel: tariffLabel,
                            isPackage: live.isPackage,
                            packagePrice: live.isPackage ? tablePackagePrice(widget.table) : null,
                          )
                        : _EmptyBody(
                            name: name,
                            rate: rate,
                            rateSummary: rateSummary,
                            status: status,
                            cardStyle: cardStyle,
                            compact: widget.compact,
                            mobile: widget.mobile,
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
    this.mobile = false,
    this.tariffLabel,
    this.isPackage = false,
    this.packagePrice,
  });

  final String name;
  final double rate;
  final String status;
  final bool hasSession;
  final TableLiveSnapshot live;
  final bool isPaused;
  final int tick;
  final bool compact;
  final bool mobile;
  final TableStatusStyle cardStyle;
  final bool timeBillingEnabled;
  final String? tariffLabel;
  final bool isPackage;
  final double? packagePrice;

  @override
  Widget build(BuildContext context) {
    final bill = live.bill;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: CashierTheme.stationTitle(context, size: mobile ? 14 : (compact ? 15 : 16)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
              compact: compact || mobile,
              large: !compact && !mobile,
              isExpired: live.isExpired,
              isUrgent: live.isUrgent,
              color: cardStyle.accent,
            ),
          ),
        ),
        if (!compact && !mobile && ((isPackage && bill.timeCharge > 0) || (timeBillingEnabled && bill.timeCharge > 0) || bill.productsTotal > 0 || live.discount > 0)) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              if (isPackage && bill.timeCharge > 0)
                Expanded(child: _BreakdownChip(label: 'Paket', amount: bill.timeCharge, color: cardStyle.accent))
              else if (timeBillingEnabled && bill.timeCharge > 0)
                Expanded(child: _BreakdownChip(label: 'Vaxt', amount: bill.timeCharge, color: cardStyle.accent)),
              if (bill.timeCharge > 0 && bill.productsTotal > 0) const SizedBox(width: 6),
              if (bill.productsTotal > 0)
                Expanded(child: _BreakdownChip(label: 'Məhsul', amount: bill.productsTotal, color: const Color(0xFF5856D6))),
              if (live.discount > 0) ...[
                if (bill.timeCharge > 0 || bill.productsTotal > 0) const SizedBox(width: 6),
                Expanded(
                  child: _BreakdownChip(
                    label: live.promotionName != null ? 'Endirim' : 'Endirim',
                    amount: live.discount,
                    color: const Color(0xFF34C759),
                  ),
                ),
              ],
            ],
          ),
        ],
        if (!compact && !mobile && live.items.isNotEmpty) ...[
          const SizedBox(height: 4),
          TableSessionItems(items: live.items, compact: true, maxVisible: 2),
        ],
        const Spacer(flex: 1),
        Container(
          padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 12, vertical: mobile ? 8 : 10),
          decoration: BoxDecoration(
            color: cardStyle.timerZoneFill,
            borderRadius: BorderRadius.circular(CashierTheme.radiusControl),
            border: Border.all(color: cardStyle.cardBorder.withValues(alpha: 0.85)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cəmi', style: CashierTheme.caption(context)),
                  if (live.discount > 0)
                    Text(
                      live.promotionName ?? 'Endirim tətbiq olunub',
                      style: TextStyle(
                        fontSize: 10,
                        color: const Color(0xFF34C759).withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
              const Spacer(),
              MoneyText(
                amount: bill.totalAmount,
                size: (compact || mobile) ? MoneySize.medium : MoneySize.large,
                color: cardStyle.moneyColor ?? CashierTheme.textPrimary(context),
                suffix: ' ₼',
              ),
            ],
          ),
        ),
        if (mobile && ((isPackage && bill.timeCharge > 0) || (timeBillingEnabled && bill.timeCharge > 0) || bill.productsTotal > 0 || live.discount > 0)) ...[
          const SizedBox(height: 4),
          Text(
            [
              if (isPackage && bill.timeCharge > 0) 'Paket ${bill.timeCharge.toStringAsFixed(2)}',
              if (!isPackage && timeBillingEnabled && bill.timeCharge > 0) 'Vaxt ${bill.timeCharge.toStringAsFixed(2)}',
              if (bill.productsTotal > 0) 'Məhsul ${bill.productsTotal.toStringAsFixed(2)}',
              if (live.discount > 0) 'Endirim -${live.discount.toStringAsFixed(2)}',
            ].join(' · '),
            style: CashierTheme.caption(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
        if (isPackage && packagePrice != null && !compact && !mobile) ...[
          const SizedBox(height: 4),
          Text(
            '${tariffLabel ?? 'Paket'} · ${packagePrice!.toStringAsFixed(2)} ₼',
            style: CashierTheme.caption(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ] else if (tariffLabel != null && !compact && !mobile) ...[
          const SizedBox(height: 4),
          Text(tariffLabel!, style: CashierTheme.caption(context), maxLines: 1, overflow: TextOverflow.ellipsis),
        ] else if (!isPackage && !compact && !mobile) ...[
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
    this.mobile = false,
  });

  final String name;
  final double rate;
  final String rateSummary;
  final String status;
  final TableStatusStyle cardStyle;
  final bool compact;
  final bool mobile;

  String get _initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: mobile ? 32 : (compact ? 36 : 40),
              height: mobile ? 32 : (compact ? 36 : 40),
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
                  Text(
                    name,
                    style: CashierTheme.stationTitle(context, size: mobile ? 13 : (compact ? 14 : 15)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text('Hazır', style: CashierTheme.caption(context)),
                ],
              ),
            ),
            StatusBadge(label: 'Boş', status: status, hasSession: false),
          ],
        ),
        const Spacer(flex: 1),
        if (!mobile) _MetaRow(icon: Icons.payments_outlined, label: 'Tariflər', value: rateSummary),
        if (!compact && !mobile) ...[
          const SizedBox(height: 6),
          _MetaRow(icon: Icons.event_available_outlined, label: 'Status', value: 'Sessiya gözləyir'),
        ],
        if (mobile) ...[
          Text(rateSummary, style: CashierTheme.caption(context), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          const SizedBox(height: 6),
        ],
        const Spacer(flex: 1),
        SizedBox(
          width: double.infinity,
          height: mobile ? 40 : (compact ? 34 : 36),
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
    this.discount = 0,
    this.promotionName,
    this.timeLabel,
    this.timeChargeLabel,
  });

  final double timeCharge;
  final double productsTotal;
  final double discount;
  final String? promotionName;
  final double total;
  final int activeMinutes;
  final String? timeLabel;
  final String? timeChargeLabel;

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
          if (timeCharge > 0) ...[
            _row(
              context,
              timeChargeLabel != null
                  ? (timeLabel != null ? '$timeChargeLabel ($timeLabel)' : timeChargeLabel!)
                  : (timeLabel ?? 'Vaxt ($activeMinutes dəq)'),
              timeCharge,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          _row(context, 'Məhsullar', productsTotal),
          if (discount > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            _row(
              context,
              promotionName != null ? 'Endirim ($promotionName)' : 'Endirim',
              discount,
              negative: true,
              prefixMinus: true,
            ),
          ],
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

  Widget _row(BuildContext context, String label, double amount, {bool negative = false, bool prefixMinus = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          '${prefixMinus ? '−' : ''}${amount.toStringAsFixed(2)} ₼',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: negative ? AppColors.danger : null,
              ),
        ),
      ],
    );
  }
}
