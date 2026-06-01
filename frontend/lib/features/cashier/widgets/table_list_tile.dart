import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/business_config_provider.dart';
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

class TableListTile extends ConsumerStatefulWidget {
  const TableListTile({
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
  ConsumerState<TableListTile> createState() => _TableListTileState();
}

class _TableListTileState extends ConsumerState<TableListTile> with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncBlinkAnimation());
  }

  @override
  void didUpdateWidget(covariant TableListTile oldWidget) {
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
          builder: (context, child) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CashierTheme.radiusCard),
              color: cardStyle.cardFill,
              border: Border.all(color: cardStyle.cardBorder, width: cardStyle.borderWidth),
              boxShadow: cardStyle.cardShadow ?? CashierTheme.cardShadow(context),
            ),
            child: child,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(CashierTheme.radiusCard),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: cardStyle.accentBarWidth, color: cardStyle.accent),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: widget.compact ? 12 : 16,
                        vertical: widget.compact ? 10 : 14,
                      ),
                      child: widget.compact
                          ? _buildCompactRow(context, status, hasSession, live, isPaused, cardStyle)
                          : _buildStandardRow(context, status, hasSession, live, isPaused, cardStyle),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(String s) => switch (s) {
        'empty' => 'Boş',
        'active' => 'Aktiv',
        'paused' => 'Pause',
        _ => s,
      };

  Widget _buildStandardRow(
    BuildContext context,
    String status,
    bool hasSession,
    TableLiveSnapshot? live,
    bool isPaused,
    TableStatusStyle cardStyle,
  ) {
    return Row(
      children: [
        Expanded(child: _nameColumn(context, status, hasSession, live, titleSize: 16)),
        if (live != null) ...[
          const SizedBox(width: 12),
          Flexible(child: _timerColumn(live, isPaused, cardStyle, compact: false)),
        ] else ...[
          const SizedBox(width: 12),
          SizedBox(
            height: 32,
            child: FilledButton(
              onPressed: null,
              style: FilledButton.styleFrom(
                backgroundColor: CashierTheme.accent(context),
                disabledBackgroundColor: CashierTheme.accent(context),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CashierTheme.radiusControl + 2),
                ),
              ),
              child: const Text('Sessiya aç', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactRow(
    BuildContext context,
    String status,
    bool hasSession,
    TableLiveSnapshot? live,
    bool isPaused,
    TableStatusStyle cardStyle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _nameColumn(context, status, hasSession, live, titleSize: 15, maxSubtitleLines: 1)),
            if (live != null) _timerColumn(live, isPaused, cardStyle, compact: true),
          ],
        ),
        if (live == null) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            width: double.infinity,
            child: FilledButton(
              onPressed: null,
              style: FilledButton.styleFrom(
                backgroundColor: CashierTheme.accent(context),
                disabledBackgroundColor: CashierTheme.accent(context),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CashierTheme.radiusControl + 2),
                ),
              ),
              child: const Text('Sessiya aç', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _nameColumn(
    BuildContext context,
    String status,
    bool hasSession,
    TableLiveSnapshot? live, {
    required double titleSize,
    int maxSubtitleLines = 2,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.table['name'] as String,
                style: CashierTheme.stationTitle(context, size: titleSize),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            StatusBadge(label: _statusLabel(status), status: status, hasSession: hasSession),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          activeSessionTariffLabel(widget.table) ?? formatTableTariffSummary(widget.table),
          style: CashierTheme.caption(context),
          maxLines: maxSubtitleLines,
          overflow: TextOverflow.ellipsis,
        ),
        if (live != null && live.items.isNotEmpty && !widget.compact) ...[
          const SizedBox(height: 6),
          TableSessionItems(items: live.items, maxVisible: 2, compact: true),
        ],
      ],
    );
  }

  Widget _timerColumn(
    TableLiveSnapshot live,
    bool isPaused,
    TableStatusStyle cardStyle, {
    required bool compact,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TimerDisplay(
          bill: live.bill,
          isPaused: isPaused,
          tick: widget.tick,
          compact: compact,
          color: cardStyle.accent,
          isExpired: live.isExpired,
          isUrgent: live.isUrgent,
        ),
        const SizedBox(height: 4),
        MoneyText(
          amount: live.bill.totalAmount,
          size: compact ? MoneySize.small : MoneySize.medium,
          color: cardStyle.moneyColor,
          suffix: ' ₼',
        ),
        if (live.discount > 0)
          Text(
            live.promotionName ?? 'Endirim',
            style: TextStyle(fontSize: 10, color: const Color(0xFF34C759).withValues(alpha: 0.9)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}
