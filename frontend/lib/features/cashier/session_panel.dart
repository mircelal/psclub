import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/billing/session_live_bill.dart';
import '../../core/config/business_config_provider.dart';
import '../../core/feedback/app_feedback.dart';
import '../../core/utils/json_parse.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/status_badge.dart';
import '../../services/pos_service.dart';
import 'close_session_dialog.dart';
import 'widgets/product_catalog_grid.dart';
import 'widgets/session_cart_list.dart';
import 'widgets/table_card.dart';

class SessionPanel extends ConsumerStatefulWidget {
  const SessionPanel({
    super.key,
    required this.sessionId,
    required this.onChanged,
    this.scrollController,
    this.isWideLayout = false,
  });

  final int sessionId;
  final VoidCallback onChanged;
  final ScrollController? scrollController;
  final bool isWideLayout;

  @override
  ConsumerState<SessionPanel> createState() => _SessionPanelState();
}

class _SessionPanelState extends ConsumerState<SessionPanel> {
  Map<String, dynamic>? _session;
  String? _sessionError;
  bool _sessionLoading = true;
  bool _actionLoading = false;
  bool _itemBusy = false;
  Timer? _liveTimer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _loadSession();
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  bool get _isCounter => (_session?['session_type'] ?? 'table') == 'counter';

  SessionBillSnapshot? _liveBill() {
    if (_session == null) return null;
    final config = ref.read(businessConfigProvider).valueOrNull ?? BusinessConfig.fallback;
    return computeSessionLiveBill(
      _session!,
      billingMode: config.billingMode,
      timeBillingEnabled: !_isCounter && config.timeBillingEnabled,
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
      if (mounted) {
        setState(() {
          _session = session;
          _sessionLoading = false;
        });
      }
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

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    if (_sessionLoading) {
      return _shell(p, child: const SizedBox(height: 280, child: Center(child: CircularProgressIndicator(strokeWidth: 2))));
    }

    if (_sessionError != null || _session == null) {
      return _shell(
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
    }

    if (widget.isWideLayout) {
      return _shell(p, child: _buildWideBody(p));
    }

    return _shell(
      p,
      child: _buildNarrowBody(p, widget.scrollController ?? ScrollController()),
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
              _billAndActions(p),
              const SectionDivider(),
              const SectionHeader(title: 'Məhsul əlavə et', subtitle: 'Kartı seç — səbətə düşür'),
              _productsSection(p, gridColumns: 3),
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
    final subtitle = _isCounter
        ? (customerName != null && customerName.isNotEmpty ? customerName : 'Masa olmadan məhsul satışı')
        : 'Sessiya #${widget.sessionId}';

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
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
        ],
      ),
    );
  }

  Widget _sidebar(AppPalette p, {required bool scrollable}) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
    final payColor = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF2D8A5E)
        : AppColors.accent;
    // _tick drives rebuild every second for live timer amounts
    final _ = _tick;

    if (live == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BillSummaryCard(
          timeCharge: live.timeCharge,
          productsTotal: live.productsTotal,
          total: live.totalAmount,
          activeMinutes: live.activeMinutes,
          timeLabel: !_isCounter && config.timeBillingEnabled && live.timeCharge > 0
              ? '${config.labels.rateLabel} (${live.activeMinutes} dəq)'
              : null,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            if (!_isCounter) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _actionLoading ? null : _togglePause,
                  icon: Icon(status == 'active' ? Icons.pause : Icons.play_arrow),
                  label: Text(status == 'active' ? 'Pause' : 'Davam'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              flex: _isCounter ? 1 : 2,
              child: FilledButton.icon(
                onPressed: () => _closeSession(),
                icon: const Icon(Icons.payment),
                label: Text(_isCounter ? 'Ödənişi al' : 'Hesabı bağla'),
                style: FilledButton.styleFrom(
                  backgroundColor: payColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 52),
                ),
              ),
            ),
          ],
        ),
      ],
    );
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
