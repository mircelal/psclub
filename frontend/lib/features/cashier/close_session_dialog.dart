import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/billing/session_live_bill.dart';
import '../../core/config/business_config_provider.dart';
import '../../core/feedback/app_feedback.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/json_parse.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/money_text.dart';
import '../../services/pos_service.dart';
import 'shift_provider.dart';
import 'widgets/session_discount_dialog.dart';
import 'widgets/table_card.dart';
import 'widgets/payment_method_selector.dart';

class CloseSessionDialog extends ConsumerStatefulWidget {
  const CloseSessionDialog({
    super.key,
    required this.sessionId,
    this.tableName = '',
    this.isCounter = false,
  });

  final int sessionId;
  final String tableName;
  final bool isCounter;

  @override
  ConsumerState<CloseSessionDialog> createState() => _CloseSessionDialogState();
}

class _CloseSessionDialogState extends ConsumerState<CloseSessionDialog> {
  String _method = 'cash';
  final _cashCtrl = TextEditingController();
  final _cardCtrl = TextEditingController();
  bool _loading = false;
  bool _loadingBill = true;
  Map<String, dynamic>? _receipt;
  SessionBillSnapshot? _bill;
  int _customerBonusMinutes = 0;
  double _customerBonusWallet = 0;
  bool _useBonusMinutes = false;
  bool _useBonusWallet = false;
  double _loyaltyCredit = 0;
  bool _hasCustomer = false;
  bool _bonusDefaultsSet = false;

  @override
  void initState() {
    super.initState();
    _cashCtrl.addListener(_syncMixed);
    _loadBill();
  }

  Future<void> _loadBill() async {
    setState(() => _loadingBill = true);
    try {
      final session = await ref.read(posServiceProvider).getSession(widget.sessionId);
      final customerId = session['customer_id'];
      _hasCustomer = jsonToInt(customerId) > 0;
      _customerBonusMinutes = _hasCustomer ? jsonToInt(session['customer_bonus_minutes']) : 0;
      _customerBonusWallet = _hasCustomer ? jsonToDouble(session['customer_bonus_wallet']) : 0;

      if (!_bonusDefaultsSet && _hasCustomer) {
        _useBonusMinutes = _customerBonusMinutes > 0;
        _useBonusWallet = _customerBonusWallet > 0;
        _bonusDefaultsSet = true;
      } else if (_hasCustomer && _customerBonusMinutes <= 0 && _customerBonusWallet <= 0) {
        _useBonusMinutes = false;
        _useBonusWallet = false;
      }

      final redeemMinutes = _useBonusMinutes ? _customerBonusMinutes : 0;
      final redeemWallet = _useBonusWallet ? _customerBonusWallet : 0.0;
      final preview = await ref.read(posServiceProvider).previewBill(
            widget.sessionId,
            redeemBonusMinutes: redeemMinutes,
            redeemBonusWallet: redeemWallet,
          );

      final config = await ref.read(businessConfigProvider.future);
      final isCounter = widget.isCounter || (session['session_type'] ?? 'table') == 'counter';
      if (isCounter) {
        _useBonusMinutes = false;
      }
      final live = computeSessionLiveBill(
        session,
        billingMode: config.chargeBillingMode,
        timeBillingEnabled: !isCounter && config.timeBillingEnabled,
        minBillingMinutes: config.minBillingMinutes,
        billingIncrementMinutes: config.billingIncrementMinutes,
        billingGraceMinutes: config.billingGraceMinutes,
      );

      if (mounted) {
        setState(() {
          _bill = SessionBillSnapshot(
            activeSeconds: live.activeSeconds,
            activeMinutes: live.activeMinutes,
            timeCharge: jsonToDouble(preview['time_charge'], live.timeCharge),
            productsTotal: jsonToDouble(preview['products_total'], live.productsTotal),
            discount: jsonToDouble(preview['discount'], live.discount),
            subtotal: jsonToDouble(preview['subtotal'], live.subtotal),
            totalAmount: jsonToDouble(preview['total_amount'], live.totalAmount),
            plannedMinutes: live.plannedMinutes,
            remainingSeconds: live.remainingSeconds,
            isCountdown: live.isCountdown,
            discountType: live.discountType,
            discountValue: live.discountValue,
            couponCode: live.couponCode,
            promotionName: live.promotionName,
          );
          _loyaltyCredit = jsonToDouble(preview['loyalty_credit']);
          _loadingBill = false;
          _cashCtrl.text = _bill!.totalAmount.toStringAsFixed(2);
          _cardCtrl.text = '0.00';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingBill = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _toggleBonus({bool? minutes, bool? wallet}) async {
    if (minutes != null) _useBonusMinutes = minutes;
    if (wallet != null) _useBonusWallet = wallet;
    await _loadBill();
  }

  void _syncMixed() {
    if (_method != 'mixed' || _bill == null) return;
    final total = _bill!.totalAmount;
    var cash = double.tryParse(_cashCtrl.text.replaceAll(',', '.')) ?? 0;
    if (cash < 0) cash = 0;
    if (cash > total) {
      cash = total;
      final clamped = cash.toStringAsFixed(2);
      if (_cashCtrl.text != clamped) {
        _cashCtrl.value = TextEditingValue(
          text: clamped,
          selection: TextSelection.collapsed(offset: clamped.length),
        );
      }
    }
    final remaining = (total - cash).clamp(0.0, total);
    final remText = remaining.toStringAsFixed(2);
    if (_cardCtrl.text != remText) {
      _cardCtrl.text = remText;
    }
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    _cardCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyManualDiscount() async {
    if (_bill == null) return;
    final isCounter = widget.isCounter;
    final result = await showSessionDiscountDialog(
      context,
      timeCharge: _bill!.timeCharge,
      productsTotal: _bill!.productsTotal,
      currentDiscount: _bill!.discount,
      discountType: _bill!.discountType,
      discountValue: _bill!.discountValue,
      checkoutMode: true,
      currentTotal: _bill!.totalAmount,
      isCounter: isCounter,
    );
    if (result == null || !mounted) return;

    setState(() => _loadingBill = true);
    try {
      if (result.clear) {
        await ref.read(posServiceProvider).clearSessionDiscount(widget.sessionId);
      } else {
        await ref.read(posServiceProvider).setSessionDiscount(
              widget.sessionId,
              discountType: result.discountType!,
              discountValue: result.discountValue ?? 0,
              discountAppliesTo: isCounter ? 'all' : 'time_only',
            );
      }
      await _loadBill();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingBill = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _close() async {
    if (_bill == null || _loading) return;
    if (_method == 'mixed') {
      final cash = double.tryParse(_cashCtrl.text.replaceAll(',', '.')) ?? 0;
      final card = double.tryParse(_cardCtrl.text.replaceAll(',', '.')) ?? 0;
      final total = _bill!.totalAmount;
      if ((cash + card - total).abs() > 0.02 || cash < 0 || card < 0 || cash > total + 0.001) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nağd + kart ümumi məbləğə bərabər olmalıdır')),
        );
        return;
      }
    }
    setState(() => _loading = true);
    try {
      final cash = double.tryParse(_cashCtrl.text.replaceAll(',', '.')) ?? 0;
      final card = double.tryParse(_cardCtrl.text.replaceAll(',', '.')) ?? 0;
      final result = await ref.read(posServiceProvider).closeSession(
            widget.sessionId,
            method: _method,
            cashAmount: cash,
            cardAmount: card,
            redeemBonusMinutes: _useBonusMinutes ? _customerBonusMinutes : 0,
            redeemBonusWallet: _useBonusWallet ? _customerBonusWallet : 0,
          );
      if (!mounted) return;
      refreshCurrentShift(ref);
      setState(() {
        _receipt = result['receipt'] as Map<String, dynamic>?;
        _loading = false;
      });
      AppFeedback.success();
    } catch (e) {
      AppFeedback.error();
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _printReceipt() async {
    if (_receipt == null) return;
    final lines = _receipt!['receipt_lines'] as List<dynamic>? ?? [];
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: lines.map((l) {
            final m = l as Map<String, dynamic>;
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Text(
                m['content'] as String? ?? '',
                style: pw.TextStyle(fontWeight: (m['bold'] == true) ? pw.FontWeight.bold : pw.FontWeight.normal),
              ),
            );
          }).toList(),
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final config = ref.watch(businessConfigProvider).valueOrNull ?? BusinessConfig.fallback;

    if (_receipt != null) {
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: const BoxDecoration(color: AppColors.successSoft, shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle, color: AppColors.success, size: 48),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Ödəniş tamamlandı', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text('Qəbz № ${_receipt!['receipt_number']}', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.xxl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _printReceipt,
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('Çap et'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Bağla'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final bill = _bill;
    final total = bill?.totalAmount ?? 0;

    final screen = MediaQuery.sizeOf(context);
    final dialogWidth = (screen.width * 0.5).clamp(420.0, 560.0);
    final dialogHeight = (screen.height * 0.85).clamp(480.0, 720.0);

    final blockDismiss = widget.isCounter && total > 0;

    return PopScope(
      canPop: !blockDismiss,
      child: Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: const Icon(Icons.payment, color: AppColors.accent),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.isCounter ? 'Satışı bağla' : 'Hesabı bağla', style: Theme.of(context).textTheme.titleLarge),
                        Text(
                          widget.tableName.isNotEmpty ? widget.tableName : config.labels.unitSingular,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (!blockDismiss)
                    IconButton(onPressed: () => Navigator.pop(context, false), icon: const Icon(Icons.close, size: 20)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loadingBill
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (bill != null)
                            BillSummaryCard(
                              timeCharge: bill.timeCharge,
                              productsTotal: bill.productsTotal,
                              discount: bill.discount,
                              promotionName: bill.promotionName,
                              total: bill.totalAmount,
                              loyaltyCredit: _loyaltyCredit > 0 ? _loyaltyCredit : null,
                              activeMinutes: bill.activeMinutes,
                              timeLabel: config.timeBillingEnabled
                                  ? '${config.labels.rateLabel} (${bill.activeMinutes} dəq)'
                                  : null,
                            ),
                          if (bill != null && !widget.isCounter && bill.timeCharge > 0) ...[
                            const SizedBox(height: AppSpacing.md),
                            OutlinedButton.icon(
                              onPressed: _loading || _loadingBill ? null : _applyManualDiscount,
                              icon: const Icon(Icons.local_offer_outlined),
                              label: const Text('Əl ilə endirim'),
                            ),
                          ],
                          if (_hasCustomer && (_customerBonusMinutes > 0 || _customerBonusWallet > 0)) ...[
                            const SizedBox(height: AppSpacing.xl),
                            Text('Loyallıq bonusu', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: AppSpacing.sm),
                            if (_customerBonusMinutes > 0 && !widget.isCounter)
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('Saat balansı (${(_customerBonusMinutes / 60).toStringAsFixed(1)} saat)'),
                                subtitle: const Text('Vaxt haqqından çıxılır'),
                                value: _useBonusMinutes,
                                onChanged: _loading || _loadingBill
                                    ? null
                                    : (v) => _toggleBonus(minutes: v),
                              ),
                            if (_customerBonusWallet > 0)
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('Endirim balansı (${_customerBonusWallet.toStringAsFixed(2)} ₼)'),
                                value: _useBonusWallet,
                                onChanged: _loading || _loadingBill
                                    ? null
                                    : (v) => _toggleBonus(wallet: v),
                              ),
                            if (_loyaltyCredit > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: AppSpacing.sm),
                                child: Text(
                                  'Bonus endirimi: -${_loyaltyCredit.toStringAsFixed(2)} ₼',
                                  style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                                ),
                              ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.12),
                                  AppColors.accent.withValues(alpha: 0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              border: Border.all(color: p.border),
                            ),
                            child: Column(
                              children: [
                                Text('Ödəniləcək məbləğ', style: Theme.of(context).textTheme.bodyMedium),
                                const SizedBox(height: AppSpacing.sm),
                                Center(child: MoneyText(amount: total, size: MoneySize.hero, color: AppColors.accent)),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text('Ödəniş üsulu', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: AppSpacing.md),
                          PaymentMethodSelector(
                            selected: _method,
                            onChanged: (m) {
                              setState(() {
                                _method = m;
                                if (m == 'cash') {
                                  _cashCtrl.text = total.toStringAsFixed(2);
                                  _cardCtrl.text = '0.00';
                                } else if (m == 'card') {
                                  _cashCtrl.text = '0.00';
                                  _cardCtrl.text = total.toStringAsFixed(2);
                                } else if (m == 'mixed') {
                                  _cashCtrl.text = total.toStringAsFixed(2);
                                  _cardCtrl.text = '0.00';
                                }
                              });
                            },
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: _method == 'mixed'
                                ? Padding(
                                    padding: const EdgeInsets.only(top: AppSpacing.lg),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final stacked = constraints.maxWidth < 400;
                                        final cashField = AppTextField(
                                          controller: _cashCtrl,
                                          label: 'Nağd (${config.currency})',
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          prefixIcon: Icons.payments_outlined,
                                        );
                                        final cardField = AppTextField(
                                          controller: _cardCtrl,
                                          label: 'Kart (${config.currency})',
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          prefixIcon: Icons.credit_card,
                                        );
                                        if (stacked) {
                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                            children: [
                                              cashField,
                                              const SizedBox(height: AppSpacing.md),
                                              cardField,
                                            ],
                                          );
                                        }
                                        return Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: cashField),
                                            const SizedBox(width: AppSpacing.md),
                                            Expanded(child: cardField),
                                          ],
                                        );
                                      },
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.xl),
              child: Row(
                children: [
                  if (!blockDismiss) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _loading ? null : () => Navigator.pop(context, false),
                        child: const Text('Ləğv et'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    flex: blockDismiss ? 1 : 2,
                    child: FilledButton(
                      onPressed: _loading || _loadingBill || bill == null ? null : _close,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.bg),
                      child: _loading
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(blockDismiss ? 'Ödənişi al və bağla' : 'Ödənişi təsdiqlə'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
