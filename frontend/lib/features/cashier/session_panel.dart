import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/billing/session_live_bill.dart';
import '../../core/config/business_config_provider.dart';
import '../../core/feedback/app_feedback.dart';
import '../../core/utils/json_parse.dart';
import '../../core/utils/package_session.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/status_badge.dart';
import '../../services/pos_service.dart';
import '../../core/widgets/customer_picker.dart';
import 'close_session_dialog.dart';
import 'session_sync_provider.dart';
import 'widgets/session_discount_dialog.dart';
import 'widgets/product_catalog_grid.dart';
import 'widgets/session_cart_list.dart';
import 'widgets/counter_unpaid_dialog.dart';
import 'widgets/table_card.dart';

class SessionPanel extends ConsumerStatefulWidget {
  const SessionPanel({
    super.key,
    required this.sessionId,
    required this.onChanged,
    this.scrollController,
    this.isWideLayout = false,
    this.lockUntilSettled = false,
  });

  final int sessionId;
  final VoidCallback onChanged;
  final ScrollController? scrollController;
  final bool isWideLayout;
  final bool lockUntilSettled;

  @override
  ConsumerState<SessionPanel> createState() => _SessionPanelState();
}

class _SessionPanelState extends ConsumerState<SessionPanel> {
  static const _actionButtonHeight = 48.0;

  Map<String, dynamic>? _session;
  String? _sessionError;
  bool _sessionLoading = true;
  bool _actionLoading = false;
  bool _itemBusy = false;
  Timer? _liveTimer;
  Timer? _syncTimer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(openSessionIdProvider.notifier).setOpen(widget.sessionId);
    });
    _loadSession();
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _tick++);
    });
    _syncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_itemBusy && !_actionLoading) {
        _loadSession(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _syncTimer?.cancel();
    ref.read(openSessionIdProvider.notifier).setOpen(null);
    super.dispose();
  }

  bool get _isCounter => (_session?['session_type'] ?? 'table') == 'counter';

  bool get _mustSettleBeforeClose => widget.lockUntilSettled || _isCounter;

  SessionBillSnapshot? _liveBill() {
    if (_session == null) return null;
    final config = ref.read(businessConfigProvider).valueOrNull ?? BusinessConfig.fallback;
    return computeSessionLiveBill(
      _session!,
      billingMode: config.chargeBillingMode,
      timeBillingEnabled: !_isCounter && config.timeBillingEnabled,
      minBillingMinutes: config.minBillingMinutes,
      billingIncrementMinutes: config.billingIncrementMinutes,
      billingGraceMinutes: config.billingGraceMinutes,
    );
  }

  Future<void> _loadSession({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _sessionLoading = true;
        _sessionError = null;
      });
    }
    try {
      final session = await ref.read(posServiceProvider).getSession(widget.sessionId);
      if (!mounted) return;
      final prevUpdated = _session?['updated_at']?.toString();
      final nextUpdated = session['updated_at']?.toString();
      if (silent && prevUpdated != null && prevUpdated == nextUpdated) {
        _mergeSessionPromotionFields(session);
        return;
      }
      setState(() {
        _session = session;
        _sessionLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _sessionError = e.toString();
          _sessionLoading = false;
        });
      }
    }
  }

  void _applySession(Map<String, dynamic> session) {
    setState(() => _session = session);
    widget.onChanged();
  }

  void _mergeSessionPromotionFields(Map<String, dynamic> session) {
    if (_session == null) return;
    final prevPreview = _session!['bill_preview'] as Map?;
    final nextPreview = session['bill_preview'] as Map?;
    final changed = _session!['active_promotion'] != session['active_promotion'] ||
        _session!['active_customer_group'] != session['active_customer_group'] ||
        prevPreview?['discount'] != nextPreview?['discount'] ||
        prevPreview?['promotion_name'] != nextPreview?['promotion_name'] ||
        prevPreview?['promotion_discount_type'] != nextPreview?['promotion_discount_type'] ||
        prevPreview?['promotion_discount_value'] != nextPreview?['promotion_discount_value'] ||
        _session!['customer_id'] != session['customer_id'] ||
        _session!['customer_name'] != session['customer_name'];
    if (!changed) return;

    setState(() {
      _session = Map<String, dynamic>.from(_session!)
        ..['active_promotion'] = session['active_promotion']
        ..['active_customer_group'] = session['active_customer_group']
        ..['bill_preview'] = session['bill_preview']
        ..['discount_type'] = session['discount_type']
        ..['discount_value'] = session['discount_value']
        ..['discount_applies_to'] = session['discount_applies_to']
        ..['discount'] = session['discount']
        ..['customer_id'] = session['customer_id']
        ..['customer_name'] = session['customer_name']
        ..['customer_phone'] = session['customer_phone'];
    });
  }

  Future<void> _addProduct(Map<String, dynamic> product) async {
    if (_itemBusy) return;
    setState(() => _itemBusy = true);
    try {
      final session = await ref.read(posServiceProvider).addItem(widget.sessionId, jsonToInt(product['id']), 1);
      _applySession(session);
      AppFeedback.cartAdd();
    } catch (e) {
      AppFeedback.error();
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _itemBusy = false);
    }
  }

  Future<void> _changeQty(Map<String, dynamic> item, int delta) async {
    if (_itemBusy) return;
    final current = jsonToInt(item['quantity'], 1);
    final next = current + delta;
    if (next < 0) return;

    setState(() => _itemBusy = true);
    try {
      final Map<String, dynamic> session;
      if (next == 0) {
        session = await ref.read(posServiceProvider).removeItem(widget.sessionId, jsonToInt(item['id']));
        AppFeedback.cartRemove();
      } else {
        session = await ref.read(posServiceProvider).updateItemQuantity(widget.sessionId, jsonToInt(item['id']), next);
        AppFeedback.cartAdd();
      }
      _applySession(session);
    } catch (e) {
      AppFeedback.error();
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _itemBusy = false);
    }
  }

  Future<void> _removeItem(Map<String, dynamic> item) async {
    if (_itemBusy) return;
    setState(() => _itemBusy = true);
    try {
      final session = await ref.read(posServiceProvider).removeItem(widget.sessionId, jsonToInt(item['id']));
      _applySession(session);
      AppFeedback.cartRemove();
    } catch (e) {
      AppFeedback.error();
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _itemBusy = false);
    }
  }

  Future<void> _togglePause() async {
    setState(() => _actionLoading = true);
    try {
      final status = _session!['status'] as String;
      if (status == 'active') {
        await ref.read(posServiceProvider).pauseSession(widget.sessionId);
        AppFeedback.pause();
      } else {
        await ref.read(posServiceProvider).resumeSession(widget.sessionId);
        AppFeedback.success();
      }
      await _loadSession(silent: true);
      widget.onChanged();
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  bool _canExtendTime(SessionBillSnapshot live, BusinessConfig config) {
    if (_session != null && sessionHasPackage(_session!)) return false;
    if (_isCounter || !live.isCountdown) return false;
    final minSec = config.minOpenMinutes * 60;
    final firstHourDone = live.activeSeconds >= minSec;
    final expired = (live.remainingSeconds ?? 1) <= 0;
    return firstHourDone || expired;
  }

  Future<void> _extendTime() async {
    final config = ref.read(businessConfigProvider).valueOrNull ?? BusinessConfig.fallback;
    setState(() => _actionLoading = true);
    try {
      final session = await ref.read(posServiceProvider).extendSession(
            widget.sessionId,
            addMinutes: config.extendStepMinutes,
          );
      if (mounted) setState(() => _session = session);
      widget.onChanged();
      AppFeedback.success();
      if (mounted) {
        showAppSnackBar(context, 'Müddət ${config.extendStepMinutes} dəq uzadıldı');
      }
    } catch (e) {
      AppFeedback.error();
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    ref.listen<Map<int, String>>(sessionRevisionProvider, (prev, next) {
      final rev = next[widget.sessionId];
      if (rev == null) return;
      if (prev?[widget.sessionId] == rev) return;
      if (!_itemBusy && !_actionLoading) {
        _loadSession(silent: true);
      }
    });

    final Widget body;
    if (_sessionLoading) {
      body = _shell(p, child: const SizedBox(height: 280, child: Center(child: CircularProgressIndicator(strokeWidth: 2))));
    } else if (_sessionError != null || _session == null) {
      body = _shell(
        p,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Sessiya yüklənmədi', style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
              const SizedBox(height: AppSpacing.sm),
              Text(_sessionError ?? '', style: TextStyle(color: p.textMuted, fontSize: 12)),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: _loadSession, child: const Text('Yenidən')),
            ],
          ),
        ),
      );
    } else if (widget.isWideLayout) {
      body = _shell(p, child: _buildWideBody(p));
    } else {
      body = _shell(
        p,
        child: _buildNarrowBody(p, widget.scrollController ?? ScrollController()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _closePanel();
      },
      child: body,
    );
  }

  Widget _buildWideBody(AppPalette p) {
    return Column(
      children: [
        _header(p),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  decoration: BoxDecoration(border: Border(right: BorderSide(color: p.border))),
                  child: _productsSection(p, gridColumns: 5),
                ),
              ),
              Expanded(
                flex: 2,
                child: _sidebar(p, scrollable: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowBody(AppPalette p, ScrollController scrollCtrl) {
    return Column(
      children: [
        if (!widget.isWideLayout) ...[
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: p.borderLight, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ],
        _header(p),
        Expanded(
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            children: [
              if (_mustSettleBeforeClose && _items.isNotEmpty) _unpaidBanner(p),
              _billAndActions(p),
              const SectionDivider(),
              const SectionHeader(title: 'Məhsul əlavə et', subtitle: 'Kartı seç — səbətə düşür'),
              _productsSection(
                p,
                gridColumns: MediaQuery.sizeOf(context).width < 380 ? 2 : 3,
              ),
              const SizedBox(height: AppSpacing.xl),
              _cartHeader(),
              SessionCartList(
                items: _items,
                productsTotal: _productsTotal,
                onIncrease: (i) => _changeQty(i, 1),
                onDecrease: (i) => _changeQty(i, -1),
                onRemove: _removeItem,
              ),
              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        ),
      ],
    );
  }

  Widget _shell(AppPalette p, {required Widget child}) {
    return Container(
      width: widget.isWideLayout ? double.infinity : null,
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: widget.isWideLayout
            ? BorderRadius.circular(AppSpacing.radiusXl)
            : const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
        border: Border.all(color: p.borderLight.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.light ? 0.12 : 0.4),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _header(AppPalette p) {
    final status = _session!['status'] as String;
    final customerName = _session!['customer_name'] as String?;
    final title = _isCounter
        ? (_session!['table_name'] as String? ?? 'Birbaşa satış')
        : (_session!['table_name'] as String? ?? 'Masa');
    final String subtitle;
    if (_isCounter) {
      subtitle = customerName != null && customerName.isNotEmpty
          ? '$customerName · ödənişdən sonra bağlanır'
          : 'Tez satış · ödənişdən sonra bağlanır';
    } else {
      subtitle = customerName != null && customerName.isNotEmpty
          ? '$customerName · Sessiya #${widget.sessionId}'
          : 'Sessiya #${widget.sessionId}';
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        widget.isWideLayout ? AppSpacing.xl : AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (_itemBusy)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.md),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          StatusBadge(label: status == 'paused' ? 'PAUSE' : 'AKTİV', status: status),
          IconButton(onPressed: _closePanel, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }

  Widget _sidebar(AppPalette p, {required bool scrollable}) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_mustSettleBeforeClose && _items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.sm),
            child: _unpaidBanner(p),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md),
          child: _billAndActions(p),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: _cartHeader(),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xl),
            child: SessionCartList(
              items: _items,
              productsTotal: _productsTotal,
              compact: true,
              onIncrease: (i) => _changeQty(i, 1),
              onDecrease: (i) => _changeQty(i, -1),
              onRemove: _removeItem,
            ),
          ),
        ),
      ],
    );

    return content;
  }

  Widget _cartHeader() {
    return SectionHeader(
      title: 'Səbət',
      subtitle: '${_items.length} sətir',
      trailing: _items.isNotEmpty
          ? Text(
              '${_productsTotal.toStringAsFixed(2)} ₼',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          : null,
    );
  }

  Widget _billAndActions(AppPalette p) {
    final live = _liveBill();
    final status = _session!['status'] as String;
    final config = ref.watch(businessConfigProvider).valueOrNull ?? BusinessConfig.fallback;
    final payColor = Theme.of(context).colorScheme.primary;
    // _tick drives rebuild every second for live timer amounts
    final _ = _tick;

    if (live == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BillSummaryCard(
          timeCharge: live.timeCharge,
          productsTotal: live.productsTotal,
          discount: live.discount,
          promotionName: live.promotionName,
          total: live.totalAmount,
          activeMinutes: live.activeMinutes,
          timeLabel: sessionHasPackage(_session!)
              ? (sessionPackageName(_session!) ?? 'Paket')
              : (!_isCounter && config.timeBillingEnabled && live.timeCharge > 0
                  ? '${config.labels.rateLabel} (${live.activeMinutes} dəq)'
                  : null),
          timeChargeLabel: sessionHasPackage(_session!) ? 'Paket' : null,
        ),
        const SizedBox(height: AppSpacing.md),
        _customerSection(),
        if (!_isCounter) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _actionLoading || _itemBusy ? null : _showDiscountDialog,
            icon: const Icon(Icons.local_offer_outlined),
            label: Text(live.discount > 0 ? 'Endirimi dəyiş' : 'Endirim'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, _actionButtonHeight),
            ),
          ),
        ],
        if (_canExtendTime(live, config)) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _actionLoading ? null : _extendTime,
            icon: const Icon(Icons.more_time),
            label: Text('+${config.extendStepMinutes} dəq uzat'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, _actionButtonHeight),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            if (!_isCounter) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _actionLoading ? null : _togglePause,
                  icon: Icon(status == 'active' ? Icons.pause : Icons.play_arrow),
                  label: Text(status == 'active' ? 'Pause' : 'Davam'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, _actionButtonHeight),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: FilledButton.icon(
                onPressed: _actionLoading ? null : _closeSession,
                icon: const Icon(Icons.payment),
                label: Text(_isCounter ? 'Ödənişi al' : 'Hesabı bağla'),
                style: FilledButton.styleFrom(
                  backgroundColor: payColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, _actionButtonHeight),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _voidEmptyCounterIfNeeded() async {
    if (!_isCounter || _items.isNotEmpty) return;
    try {
      await ref.read(posServiceProvider).closeSession(
            widget.sessionId,
            method: 'cash',
            cashAmount: 0,
            cardAmount: 0,
          );
      widget.onChanged();
    } catch (_) {}
  }

  Future<void> _clearAllItems() async {
    final items = List<Map<String, dynamic>>.from(
      _items.map((e) => Map<String, dynamic>.from(e as Map)),
    );
    for (final item in items) {
      final session = await ref.read(posServiceProvider).removeItem(
            widget.sessionId,
            jsonToInt(item['id']),
          );
      if (mounted) setState(() => _session = session);
    }
    widget.onChanged();
  }

  Future<void> _closePanel() async {
    if (_mustSettleBeforeClose && _items.isNotEmpty) {
      final live = _liveBill();
      final choice = await showCounterUnpaidDialog(
        context,
        itemCount: _items.length,
        total: live?.totalAmount ?? _productsTotal,
      );
      switch (choice) {
        case CounterUnpaidChoice.pay:
          await _closeSession();
          return;
        case CounterUnpaidChoice.clearCart:
          final confirm = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Səbəti boşalt?'),
              content: const Text(
                'Bütün məhsullar səbətdən silinəcək və satış ləğv olunacaq. '
                'Bu əməliyyatı təsdiqləyin.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Xeyr')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Bəli, boşalt')),
              ],
            ),
          );
          if (confirm != true || !mounted) return;
          setState(() => _itemBusy = true);
          try {
            await _clearAllItems();
            await _voidEmptyCounterIfNeeded();
          } finally {
            if (mounted) setState(() => _itemBusy = false);
          }
          if (mounted) Navigator.pop(context);
          return;
        case CounterUnpaidChoice.cancel:
        case null:
          return;
      }
    }

    if (_isCounter && _items.isEmpty) {
      await _voidEmptyCounterIfNeeded();
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _unpaidBanner(AppPalette p) {
    final live = _liveBill();
    final total = live?.totalAmount ?? _productsTotal;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Theme.of(context).colorScheme.error, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Ödəniş mütləqdir (${total.toStringAsFixed(2)} ₼). '
              'Bağlamaq üçün «Ödənişi al» düyməsini basın.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _customerSection() {
    final customerId = jsonToInt(_session!['customer_id'], 0);
    return CustomerPicker(
      pos: ref.read(posServiceProvider),
      selectedId: customerId > 0 ? customerId : null,
      onChanged: _actionLoading || _itemBusy
          ? null
          : (id) {
              _assignCustomer(id);
            },
    );
  }

  Future<void> _assignCustomer(int? customerId) async {
    if (_actionLoading || _itemBusy) return;
    setState(() => _actionLoading = true);
    try {
      final session = await ref.read(posServiceProvider).assignSessionCustomer(
            widget.sessionId,
            customerId: customerId,
          );
      _applySession(session);
      AppFeedback.success();
    } catch (e) {
      AppFeedback.error();
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _showDiscountDialog() async {
    final live = _liveBill();
    if (live == null) return;
    final result = await showSessionDiscountDialog(
      context,
      timeCharge: live.timeCharge,
      productsTotal: live.productsTotal,
      currentDiscount: live.discount,
      discountType: live.discountType,
      discountValue: live.discountValue,
    );
    if (result == null || !mounted) return;

    setState(() => _actionLoading = true);
    try {
      if (result.clear) {
        final session = await ref.read(posServiceProvider).clearSessionDiscount(widget.sessionId);
        _applySession(session);
      } else {
        final session = await ref.read(posServiceProvider).setSessionDiscount(
              widget.sessionId,
              discountType: result.discountType!,
              discountValue: result.discountValue ?? 0,
              discountAppliesTo: 'time_only',
            );
        _applySession(session);
      }
      AppFeedback.success();
    } catch (e) {
      AppFeedback.error();
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _closeSession() async {
    final closed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => CloseSessionDialog(
        sessionId: widget.sessionId,
        tableName: _session!['table_name'] as String? ?? '',
        isCounter: _isCounter,
      ),
    );
    if (closed == true && context.mounted) {
      AppFeedback.success();
      if (_isCounter) {
        showAppSnackBar(context, 'Satış tamamlandı');
      }
      Navigator.pop(context);
      widget.onChanged();
    }
  }

  Widget _productsSection(AppPalette p, {required int gridColumns}) {
    final productsAsync = ref.watch(productsProvider);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.isWideLayout ? AppSpacing.xl : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.isWideLayout)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.md),
              child: SectionHeader(title: 'Məhsullar', subtitle: 'Seçin — səbətə əlavə olunur'),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: widget.isWideLayout ? AppSpacing.xl : 0),
              child: ProductCatalogGrid(
                products: productsAsync.valueOrNull ?? [],
                isLoading: productsAsync.isLoading,
                error: productsAsync.hasError ? productsAsync.error.toString() : null,
                onRetry: () => ref.invalidate(productsProvider),
                onSelect: _addProduct,
                crossAxisCount: gridColumns,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> get _items => _session!['items'] as List<dynamic>? ?? [];

  double get _productsTotal {
    final bill = _session!['bill_preview'] as Map<String, dynamic>? ?? {};
    return jsonToDouble(bill['products_total']);
  }
}
