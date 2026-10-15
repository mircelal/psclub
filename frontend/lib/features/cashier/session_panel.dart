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
import 'tables_provider.dart';
import 'widgets/session_extend_dialog.dart';
import 'widgets/session_discount_dialog.dart';
import 'widgets/session_transfer_dialog.dart';
import 'widgets/product_catalog_grid.dart';
import 'widgets/session_cart_list.dart';
import 'widgets/counter_unpaid_dialog.dart';
import 'widgets/table_card.dart';
import 'widgets/table_session_state.dart';

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
  static const _actionButtonHeight = 44.0;
  static const _quickActionHeight = 50.0;

  Map<String, dynamic>? _session;
  String? _sessionError;
  bool _sessionLoading = true;
  bool _actionLoading = false;
  bool _itemBusy = false;
  Timer? _liveTimer;
  Timer? _syncTimer;
  int _tick = 0;
  /// Yerli mutasiya sayğacı — köhnə poll cavabının təzə səbəti üstələməsinin qarşısını alır.
  int _mutationSeq = 0;
  /// Ödəniş pəncərəsi açıqdır — poll paneli bağlamamalı və ya sessiyanı üstələməməlidir.
  bool _checkoutOpen = false;
  bool _closedHandled = false;
  late final OpenSessionIdNotifier _openSessionNotifier;

  @override
  void initState() {
    super.initState();
    _openSessionNotifier = ref.read(openSessionIdProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openSessionNotifier.setOpen(widget.sessionId);
    });
    _loadSession();
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _tick++);
    });
    _syncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_itemBusy && !_actionLoading && !_checkoutOpen) {
        _loadSession(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _syncTimer?.cancel();
    // `ref` dispose-da istifadə oluna bilməz; provider-i unmount zamanı dəyişmək də olmaz.
    final notifier = _openSessionNotifier;
    final sessionId = widget.sessionId;
    Future.microtask(() => notifier.clearIfOpen(sessionId));
    super.dispose();
  }

  bool get _isCounter => (_session?['session_type'] ?? 'table') == 'counter';

  bool get _mustSettleBeforeClose => widget.lockUntilSettled || _isCounter;

  bool get _isGiftActive {
    if (_session == null) return false;
    final discountType = _session!['discount_type'] as String?;
    final discountValue = jsonToDouble(_session!['discount_value']);
    return discountType == 'percent' && discountValue >= 100.0;
  }

  Map<String, dynamic>? get _billPreview {
    final raw = _session?['bill_preview'];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  /// Kassa satışında tutulacaq məbləğ server `bill_preview`-dandır.
  /// Canlı hesab `time_only` defaultu ilə məhsul qiymətini saxlayanda
  /// hədiyyə (server cəmi 0) yenə ödəniş pəncərəsini açırdı.
  double get _counterPayableTotal {
    final preview = _billPreview;
    if (_isCounter && preview != null) {
      final gross = jsonToDouble(preview['total_amount']);
      if (gross <= 0.009) return 0;
      return billPayableTotal(preview);
    }
    return _liveBill()?.totalAmount ?? _productsTotal;
  }

  bool get _isGiftSale => _isCounter && _isGiftActive && _counterPayableTotal <= 0.009;

  bool get _counterNeedsPayment => _isCounter && _items.isNotEmpty && _counterPayableTotal > 0.009;

  bool get _showCounterUnpaidBanner => _counterNeedsPayment;

  Future<void> _toggleGift(bool on) async {
    if (_actionLoading || _itemBusy) return;
    setState(() => _actionLoading = true);
    try {
      if (on) {
        final session = await ref.read(posServiceProvider).setSessionDiscount(
              widget.sessionId,
              discountType: 'percent',
              discountValue: 100,
              discountAppliesTo: 'all',
            );
        _applySession(session);
      } else {
        final session = await ref.read(posServiceProvider).clearSessionDiscount(widget.sessionId);
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
    final seqAtStart = _mutationSeq;
    if (!silent) {
      setState(() {
        _sessionLoading = true;
        _sessionError = null;
      });
    }
    try {
      final session = await ref.read(posServiceProvider).getSession(widget.sessionId);
      if (!mounted) return;
      // Yerli mutasiya bu poll-dan sonra baş veribsə — köhnə cavabı yazma.
      if (silent && seqAtStart != _mutationSeq) {
        return;
      }
      final prevUpdated = _session?['updated_at']?.toString();
      final nextUpdated = session['updated_at']?.toString();
      if (silent && prevUpdated != null && nextUpdated != null) {
        if (prevUpdated == nextUpdated) {
          _mergeSessionPromotionFields(session);
          return;
        }
        // Köhnə updated_at — təzə mutasiya nəticəsini üstələmə.
        if (nextUpdated.compareTo(prevUpdated) < 0) {
          return;
        }
      }
      setState(() {
        _session = session;
        _sessionLoading = false;
      });
      if (session['status'] == 'closed') _handleClosedElsewhere();
    } catch (e) {
      if (mounted) {
        setState(() {
          _sessionError = e.toString();
          _sessionLoading = false;
        });
      }
    }
  }

  void _handleClosedElsewhere() {
    if (_closedHandled || _checkoutOpen || !mounted) return;
    // Üstdə başqa dialoq açıqdırsa, onu bağlamamaq üçün növbəti poll-u gözləyirik.
    if (ModalRoute.of(context)?.isCurrent != true) return;
    _closedHandled = true;
    widget.onChanged();
    showAppSnackBar(context, 'Bu sessiya artıq bağlanıb');
    Navigator.pop(context);
  }

  void _applySession(Map<String, dynamic> session) {
    if (!mounted) return;
    _mutationSeq++;
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
        _session!['customer_name'] != session['customer_name'] ||
        _session!['customer_bonus_minutes'] != session['customer_bonus_minutes'] ||
        _session!['customer_bonus_wallet'] != session['customer_bonus_wallet'];
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
        ..['customer_phone'] = session['customer_phone']
        ..['customer_bonus_minutes'] = session['customer_bonus_minutes']
        ..['customer_bonus_wallet'] = session['customer_bonus_wallet'];
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
    if (_actionLoading || _itemBusy || _session == null) return;
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
      if (!mounted) return;
      await _loadSession(silent: true);
      widget.onChanged();
    } catch (e) {
      AppFeedback.error();
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  bool _canExtendTime(BusinessConfig config) {
    if (_session == null) return false;
    return sessionCanExtendTime(_session!, config);
  }

  Future<void> _showExtendTimeDialog() async {
    if (_session == null) return;
    final ok = await showSessionExtendTimeDialog(
      context: context,
      ref: ref,
      sessionId: widget.sessionId,
      session: _session!,
    );
    if (ok) {
      await _loadSession(silent: true);
      widget.onChanged();
      if (mounted) {
        showAppSnackBar(context, 'Müddət əlavə olundu');
      }
    }
  }

  bool _canTransferSession() {
    if (_session == null || _isCounter) return false;
    final allTables = ref.read(tablesProvider).valueOrNull?.cast<Map<String, dynamic>>() ?? [];
    final sourceTableId = jsonToInt(_session!['table_id']);
    if (sourceTableId <= 0) return false;
    return allTables.any(
      (t) => TableSessionState.canOpenSession(t) && jsonToInt(t['id']) != sourceTableId,
    );
  }

  Future<void> _showTransferDialog() async {
    if (_session == null) return;
    final allTables = ref.read(tablesProvider).valueOrNull?.cast<Map<String, dynamic>>() ?? [];
    final ok = await showSessionTransferDialog(
      context: context,
      ref: ref,
      sessionId: widget.sessionId,
      session: _session!,
      allTables: allTables,
    );
    if (ok) {
      final session = await ref.read(posServiceProvider).getSession(widget.sessionId);
      if (!mounted) return;
      _applySession(session);
      widget.onChanged();
      final name = session['table_name'] as String? ?? 'Masa';
      showAppSnackBar(context, 'Sessiya köçürüldü — $name');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    ref.listen<Map<int, String>>(sessionRevisionProvider, (prev, next) {
      final rev = next[widget.sessionId];
      if (rev == null) return;
      if (prev?[widget.sessionId] == rev) return;
      if (!_itemBusy && !_actionLoading && !_checkoutOpen) {
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
              if (_showCounterUnpaidBanner) _unpaidBanner(p),
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
                productsTotal: _isGiftSale ? 0 : _productsTotal,
                complimentary: _isGiftSale,
                itemDiscounts: _itemDiscounts,
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
      if (_isGiftSale) {
        subtitle = 'Hədiyyə · ödəniş yoxdur';
      } else if (customerName != null && customerName.isNotEmpty) {
        subtitle = '$customerName · ödənişdən sonra bağlanır';
      } else {
        subtitle = 'Tez satış · ödənişdən sonra bağlanır';
      }
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_showCounterUnpaidBanner)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.sm),
            child: _unpaidBanner(p),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.sm),
          child: _billAndActions(p),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: _cartHeader(),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xl),
            children: [
              SessionCartList(
                items: _items,
                productsTotal: _isGiftSale ? 0 : _productsTotal,
                complimentary: _isGiftSale,
                itemDiscounts: _itemDiscounts,
                compact: true,
                onIncrease: (i) => _changeQty(i, 1),
                onDecrease: (i) => _changeQty(i, -1),
                onRemove: _removeItem,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cartHeader() {
    return SectionHeader(
      title: 'Səbət',
      subtitle: '${_items.length} sətir',
      trailing: _items.isNotEmpty
          ? Text(
              '${(_isGiftSale ? 0.0 : _productsTotal).toStringAsFixed(2)} ₼',
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

    final billPreview = _billPreview;
    final loyaltyCredit = billPreview != null ? billLoyaltyCredit(billPreview) : null;
    // Kassa: server cəmi (hədiyyə 0). Masa: vaxt canlı artdığı üçün live + loyallıq.
    final displayTotal = _isCounter
        ? _counterPayableTotal
        : (billPreview != null
            ? adjustTotalForLoyalty(billPreview, live.totalAmount)
            : live.totalAmount);
    final previewDiscount = billPreview != null ? jsonToDouble(billPreview['discount']) : 0.0;
    final shownDiscount = _isCounter
        ? (previewDiscount > live.discount ? previewDiscount : live.discount)
        : live.discount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BillSummaryCard(
          timeCharge: live.timeCharge,
          productsTotal: live.productsTotal,
          discount: shownDiscount,
          promotionName: live.promotionName,
          total: displayTotal,
          loyaltyCredit: loyaltyCredit,
          activeMinutes: live.activeMinutes,
          compact: true,
          timeLabel: sessionHasPackage(_session!)
              ? (sessionPackageName(_session!) ?? 'Paket')
              : (!_isCounter && config.timeBillingEnabled && live.timeCharge > 0
                  ? '${config.labels.rateLabel} (${live.activeMinutes} dəq)'
                  : null),
          timeChargeLabel: sessionHasPackage(_session!) ? 'Paket' : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        _customerSection(),
        const SizedBox(height: AppSpacing.sm),
        _sessionQuickActions(p, live: live, config: config),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            if (!_isCounter) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _actionLoading ? null : _togglePause,
                  icon: Icon(status == 'active' ? Icons.pause : Icons.play_arrow, size: 18),
                  label: Text(status == 'active' ? 'Pause' : 'Davam'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, _actionButtonHeight),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              flex: _isCounter ? 1 : 2,
              child: FilledButton.icon(
                onPressed: _actionLoading ? null : _closeSession,
                icon: Icon(
                  _isCounter && !_counterNeedsPayment ? Icons.check_circle_outline : Icons.payment,
                  size: 18,
                ),
                label: Text(
                  _isCounter
                      ? (_isGiftActive
                          ? 'Hədiyyəni tamamla'
                          : (_counterNeedsPayment ? 'Ödənişi al' : 'Satışı tamamla'))
                      : 'Hesabı bağla',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: payColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, _actionButtonHeight),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sessionQuickActions(
    AppPalette p, {
    required SessionBillSnapshot live,
    required BusinessConfig config,
  }) {
    final disabled = _actionLoading || _itemBusy;
    final tiles = <Widget>[
      _SessionQuickActionTile(
        icon: Icons.local_offer_outlined,
        label: live.discount > 0 ? 'Endirim ✓' : 'Endirim',
        active: live.discount > 0,
        enabled: !disabled,
        onTap: _showDiscountDialog,
      ),
      if (_canExtendTime(config))
        _SessionQuickActionTile(
          icon: Icons.more_time,
          label: '+ Vaxt',
          enabled: !_actionLoading,
          onTap: _showExtendTimeDialog,
        ),
      if (_canTransferSession())
        _SessionQuickActionTile(
          icon: Icons.swap_horiz,
          label: 'Köçür',
          enabled: !disabled,
          onTap: _showTransferDialog,
        ),
      if (_isCounter && _items.isNotEmpty)
        _SessionQuickActionTile(
          icon: Icons.card_giftcard,
          label: _isGiftActive ? 'Hədiyyə ✓' : 'Hədiyyə',
          active: _isGiftActive,
          enabled: !disabled,
          onTap: () => _toggleGift(!_isGiftActive),
        ),
      if (_isCounter && _items.isNotEmpty)
        _SessionQuickActionTile(
          icon: Icons.remove_shopping_cart_outlined,
          label: 'Ləğv et',
          enabled: !disabled,
          onTap: _cancelCounterSale,
        ),
    ];

    if (tiles.isEmpty) return const SizedBox.shrink();

    if (tiles.length <= 3) {
      return _quickActionRow(tiles);
    }

    final half = (tiles.length / 2).ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _quickActionRow(tiles.sublist(0, half)),
        const SizedBox(height: AppSpacing.sm),
        _quickActionRow(tiles.sublist(half)),
      ],
    );
  }

  Widget _quickActionRow(List<Widget> tiles) {
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: AppSpacing.sm),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }

  /// Boş birbaşa satışı ləğv edir. Uğursuz olduqda `false` qaytarır (panel bağlanmamalıdır).
  Future<bool> _voidEmptyCounterIfNeeded() async {
    if (!_isCounter || _items.isNotEmpty) return true;
    try {
      await ref.read(posServiceProvider).closeSession(
            widget.sessionId,
            method: 'cash',
            cashAmount: 0,
            cardAmount: 0,
          );
      widget.onChanged();
      return true;
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Boş satış ləğv olunmadı: $e. Yenidən cəhd edin və ya satışlar siyahısından açın.',
          isError: true,
        );
      }
      return false;
    }
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
      _mutationSeq++;
      if (mounted) setState(() => _session = session);
    }
    widget.onChanged();
  }

  /// Müştəri fikrini dəyişdi — səbət boşaldılır, satış ləğv olunur (stok geri qayıdır).
  Future<void> _cancelCounterSale() async {
    if (_itemBusy || _actionLoading) return;
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Satışı ləğv et?'),
        content: Text(
          'Səbətdəki ${_items.length} məhsul silinəcək və satış ləğv olunacaq. '
          'Ödəniş alınmayacaq.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Xeyr')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Bəli, ləğv et'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _itemBusy = true);
    var voided = false;
    try {
      await _clearAllItems();
      voided = await _voidEmptyCounterIfNeeded();
    } catch (e) {
      AppFeedback.error();
      if (mounted) {
        showAppSnackBar(context, 'Satış ləğv olunmadı: $e', isError: true);
        widget.onChanged();
      }
    } finally {
      if (mounted) setState(() => _itemBusy = false);
    }
    if (voided && mounted) {
      AppFeedback.cartRemove();
      showAppSnackBar(context, 'Satış ləğv olundu');
      Navigator.pop(context);
    }
  }

  Future<void> _closePanel() async {
    if (_mustSettleBeforeClose && _items.isNotEmpty) {
      if (!_counterNeedsPayment) {
        await _closeSession();
        return;
      }
      final choice = await showCounterUnpaidDialog(
        context,
        itemCount: _items.length,
        total: _counterPayableTotal,
      );
      switch (choice) {
        case CounterUnpaidChoice.pay:
          await _closeSession();
          return;
        case CounterUnpaidChoice.clearCart:
          await _cancelCounterSale();
          return;
        case CounterUnpaidChoice.cancel:
        case null:
          return;
      }
    }

    if (_isCounter && _items.isEmpty) {
      final voided = await _voidEmptyCounterIfNeeded();
      if (!voided) return;
    }
    if (mounted) Navigator.pop(context);
  }

  Widget _unpaidBanner(AppPalette p) {
    final total = _counterPayableTotal;
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
      compact: true,
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
      isCounter: _isCounter,
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
              discountAppliesTo: _isCounter ? 'all' : 'time_only',
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
    if (_actionLoading) return;
    if (_isCounter && _items.isNotEmpty && !_counterNeedsPayment) {
      setState(() => _actionLoading = true);
      try {
        await ref.read(posServiceProvider).closeSession(
              widget.sessionId,
              method: 'cash',
              cashAmount: 0,
              cardAmount: 0,
            );
        if (!mounted) return;
        AppFeedback.success();
        showAppSnackBar(
          context,
          _isGiftActive ? 'Hədiyyə satışı tamamlandı' : 'Satış tamamlandı',
        );
        Navigator.pop(context);
        widget.onChanged();
      } catch (e) {
        AppFeedback.error();
        if (mounted) showAppSnackBar(context, e.toString(), isError: true);
      } finally {
        if (mounted) setState(() => _actionLoading = false);
      }
      return;
    }

    _checkoutOpen = true;
    final bool? closed;
    try {
      closed = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black54,
        barrierDismissible: false,
        builder: (_) => CloseSessionDialog(
          sessionId: widget.sessionId,
          tableName: _session!['table_name'] as String? ?? '',
          isCounter: _isCounter,
        ),
      );
    } finally {
      _checkoutOpen = false;
    }
    if (!mounted) return;
    if (closed == true) {
      _closedHandled = true;
      AppFeedback.success();
      if (_isCounter) {
        showAppSnackBar(context, 'Satış tamamlandı');
      }
      Navigator.pop(context);
      widget.onChanged();
    } else {
      // Ödəniş pəncərəsində endirim/bonus dəyişə bilər.
      _loadSession(silent: true);
    }
  }

  Widget _productsSection(AppPalette p, {required int gridColumns}) {
    final productsAsync = ref.watch(productsProvider);

    final grid = SingleChildScrollView(
      padding: EdgeInsets.only(bottom: widget.isWideLayout ? AppSpacing.xl : 0),
      child: ProductCatalogGrid(
        products: productsAsync.valueOrNull ?? [],
        isLoading: productsAsync.isLoading,
        error: productsAsync.hasError ? productsAsync.error.toString() : null,
        onRetry: () => ref.invalidate(productsProvider),
        onSelect: _addProduct,
        crossAxisCount: gridColumns,
      ),
    );

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
          widget.isWideLayout
              ? Expanded(child: grid)
              : SizedBox(height: 280, child: grid),
        ],
      ),
    );
  }

  List<dynamic> get _items => _session!['items'] as List<dynamic>? ?? [];

  Map<int, double> get _itemDiscounts => readItemDiscounts(_session!);

  double get _productsTotal {
    final bill = _session!['bill_preview'] as Map<String, dynamic>? ?? {};
    return jsonToDouble(bill['products_total']);
  }
}

class _SessionQuickActionTile extends StatelessWidget {
  const _SessionQuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: active ? primary.withValues(alpha: 0.08) : p.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Ink(
          height: _SessionPanelState._quickActionHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: active ? primary.withValues(alpha: 0.35) : p.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? primary : (enabled ? p.textSecondary : p.textMuted),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 11,
                      color: enabled ? null : p.textMuted,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
