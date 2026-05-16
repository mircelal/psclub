import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/business_config_provider.dart';
import '../../../core/theme/cashier_theme.dart';
import '../../../core/theme/table_status_theme.dart';
import '../../../core/utils/json_parse.dart';
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
  });

  final Map<String, dynamic> table;
  final int tick;
  final VoidCallback onTap;

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
        borderRadius: BorderRadius.circular(CashierTheme.radiusCard),
        child: AnimatedBuilder(
          animation: _blink,
          builder: (context, child) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CashierTheme.radiusCard),
              color: cardStyle.cardFill,
              border: CashierTheme.cardBorder(context),
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
                  Container(width: 4, color: cardStyle.accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.table['name'] as String,
                                        style: CashierTheme.stationTitle(context, size: 16),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    StatusBadge(label: _statusLabel(status), status: status, hasSession: hasSession),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${jsonToDouble(widget.table['hourly_rate']).toStringAsFixed(2)} ₼/saat',
                                  style: CashierTheme.caption(context),
                                ),
                                if (live != null && live.items.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  TableSessionItems(items: live.items, maxVisible: 5),
                                ],
                              ],
                            ),
                          ),
                          if (live != null) ...[
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TimerDisplay(
                                  bill: live.bill,
                                  isPaused: isPaused,
                                  tick: widget.tick,
                                  compact: false,
                                  color: cardStyle.accent,
                                  isExpired: live.isExpired,
                                  isUrgent: live.isUrgent,
                                ),
                                const SizedBox(height: 4),
                                MoneyText(
                                  amount: live.bill.totalAmount,
                                  size: MoneySize.medium,
                                  color: cardStyle.moneyColor,
                                  suffix: ' ₼',
                                ),
                              ],
                            ),
                          ] else ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: cardStyle.accent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Başlat',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ],
                        ],
                      ),
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
}
