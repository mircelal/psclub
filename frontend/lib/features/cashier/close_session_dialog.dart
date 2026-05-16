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
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/money_text.dart';
import '../../services/pos_service.dart';
import 'widgets/table_card.dart';
import 'widgets/payment_method_selector.dart';

class CloseSessionDialog extends ConsumerStatefulWidget {
  const CloseSessionDialog({
    super.key,
    required this.sessionId,
    this.tableName = '',
  });

  final int sessionId;
  final String tableName;

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
      final config = await ref.read(businessConfigProvider.future);
      final live = computeSessionLiveBill(
        session,
        billingMode: config.billingMode,
        timeBillingEnabled: config.timeBillingEnabled,
      );
      if (mounted) {
        setState(() {
          _bill = live;
          _loadingBill = false;
          _cashCtrl.text = live.totalAmount.toStringAsFixed(2);
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

  void _syncMixed() {
    if (_method != 'mixed' || _bill == null) return;
    final cash = double.tryParse(_cashCtrl.text) ?? 0;
    final remaining = (_bill!.totalAmount - cash).clamp(0, _bill!.totalAmount);
    if (_cardCtrl.text != remaining.toStringAsFixed(2)) {
      _cardCtrl.text = remaining.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    _cardCtrl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_bill == null) return;
    setState(() => _loading = true);
    try {
      final cash = double.tryParse(_cashCtrl.text) ?? 0;
      final card = double.tryParse(_cardCtrl.text) ?? 0;
      final result = await ref.read(posServiceProvider).closeSession(
            widget.sessionId,
            method: _method,
            cashAmount: cash,
            cardAmount: card,
          );
      setState(() {
        _receipt = result['receipt'] as Map<String, dynamic>?;
        _loading = false;
      });
      AppFeedback.success();
    } catch (e) {
      setState(() => _loading = false);
      AppFeedback.error();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
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

    return Dialog(
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
                        Text('Hesabı bağla', style: Theme.of(context).textTheme.titleLarge),
                        Text(
                          widget.tableName.isNotEmpty ? widget.tableName : config.labels.unitSingular,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
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
                              total: bill.totalAmount,
                              activeMinutes: bill.activeMinutes,
                              timeLabel: config.timeBillingEnabled
                                  ? '${config.labels.rateLabel} (${bill.activeMinutes} dəq)'
                                  : null,
                            ),
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
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => Navigator.pop(context, false),
                      child: const Text('Ləğv et'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _loading || _loadingBill || bill == null ? null : _close,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.bg),
                      child: _loading
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Ödənişi təsdiqlə'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
