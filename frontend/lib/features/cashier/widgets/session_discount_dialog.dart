import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_dialog.dart';

class SessionDiscountResult {
  const SessionDiscountResult({
    this.clear = false,
    this.discountType,
    this.discountValue,
    this.finalTotal,
  });

  final bool clear;
  final String? discountType;
  final double? discountValue;
  final double? finalTotal;
}

Future<SessionDiscountResult?> showSessionDiscountDialog(
  BuildContext context, {
  required double timeCharge,
  required double productsTotal,
  required double currentDiscount,
  String? discountType,
  double? discountValue,
  bool checkoutMode = false,
  double? currentTotal,
}) {
  return showDialog<SessionDiscountResult>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) {
      final size = MediaQuery.sizeOf(ctx);
      final compact = size.height < 720 || size.width < 420;

      return Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 24,
          vertical: compact ? 12 : 28,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: compact ? size.width * 0.96 : 520,
            minWidth: 320,
            minHeight: compact ? 380 : 440,
            maxHeight: size.height * 0.88,
          ),
          child: _SessionDiscountForm(
            timeCharge: timeCharge,
            productsTotal: productsTotal,
            currentDiscount: currentDiscount,
            discountType: discountType,
            discountValue: discountValue,
            checkoutMode: checkoutMode,
            currentTotal: currentTotal,
            compact: compact,
          ),
        ),
      );
    },
  );
}

class _SessionDiscountForm extends StatefulWidget {
  const _SessionDiscountForm({
    required this.timeCharge,
    required this.productsTotal,
    required this.currentDiscount,
    this.discountType,
    this.discountValue,
    this.checkoutMode = false,
    this.currentTotal,
    this.compact = false,
  });

  final double timeCharge;
  final double productsTotal;
  final double currentDiscount;
  final String? discountType;
  final double? discountValue;
  final bool checkoutMode;
  final double? currentTotal;
  final bool compact;

  @override
  State<_SessionDiscountForm> createState() => _SessionDiscountFormState();
}

class _SessionDiscountFormState extends State<_SessionDiscountForm> {
  late String _mode;
  final _valueCtrl = TextEditingController();
  final _finalCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mode = widget.checkoutMode ? 'final' : (widget.discountType == 'percent' ? 'percent' : 'fixed');
    if (widget.discountValue != null && widget.discountValue! > 0) {
      _valueCtrl.text = widget.discountValue!.toStringAsFixed(widget.discountType == 'percent' ? 0 : 2);
    }
    final total = widget.currentTotal ?? (widget.timeCharge + widget.productsTotal - widget.currentDiscount);
    _finalCtrl.text = total.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    _finalCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => widget.timeCharge + widget.productsTotal;

  void _submit() {
    if (_mode == 'clear') {
      Navigator.pop(context, const SessionDiscountResult(clear: true));
      return;
    }
    if (_mode == 'final') {
      final target = double.tryParse(_finalCtrl.text.replaceAll(',', '.')) ?? -1;
      if (target < 0 || target > _subtotal) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Yanlış məbləğ')),
        );
        return;
      }
      final discountNeeded = (_subtotal - target).clamp(0, widget.timeCharge);
      Navigator.pop(
        context,
        SessionDiscountResult(
          discountType: 'fixed',
          discountValue: double.parse(discountNeeded.toStringAsFixed(2)),
        ),
      );
      return;
    }

    final value = double.tryParse(_valueCtrl.text.replaceAll(',', '.')) ?? -1;
    if (value < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dəyəri daxil edin')),
      );
      return;
    }
    Navigator.pop(
      context,
      SessionDiscountResult(
        discountType: _mode,
        discountValue: value,
      ),
    );
  }

  List<(String, String)> get _modeOptions {
    if (widget.checkoutMode) {
      return const [
        ('final', 'Final məbləğ'),
        ('fixed', 'Endirim ₼'),
        ('percent', 'Faiz %'),
      ];
    }
    return const [
      ('percent', 'Faiz %'),
      ('fixed', 'Məbləğ ₼'),
    ];
  }

  Widget _modeSelector() {
    final options = _modeOptions;
    if (widget.compact || options.length > 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: options.map((opt) {
          final selected = _mode == opt.$1;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Material(
              color: selected ? AppColors.accentSoft : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: InkWell(
                onTap: () => setState(() => _mode = opt.$1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(
                      color: selected ? AppColors.accent : AppColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 20,
                        color: selected ? AppColors.accent : AppColors.textMuted,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          opt.$2,
                          style: TextStyle(
                            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    return SegmentedButton<String>(
      segments: options
          .map((opt) => ButtonSegment(value: opt.$1, label: Text(opt.$2)))
          .toList(),
      selected: {_mode},
      onSelectionChanged: (s) => setState(() => _mode = s.first),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xxl, AppSpacing.lg, AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Icon(Icons.local_offer_outlined, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.checkoutMode ? 'Əl ilə endirim' : 'Endirim tətbiq et',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.checkoutMode
                          ? 'Yalnız PlayStation vaxtına endirim (məhsullar dəyişməz)'
                          : 'Endirim yalnız vaxt haqqına tətbiq olunur',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.lg, AppSpacing.xxl, AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.timeCharge > 0)
                        Text(
                          'Vaxt haqqı: ${widget.timeCharge.toStringAsFixed(2)} ₼',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Məhsullar: ${widget.productsTotal.toStringAsFixed(2)} ₼ (endirimsiz)',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (widget.currentDiscount > 0) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Cari endirim: −${widget.currentDiscount.toStringAsFixed(2)} ₼',
                          style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text('Endirim növü', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.md),
                _modeSelector(),
                const SizedBox(height: AppSpacing.xl),
                if (_mode == 'final')
                  AppTextField(
                    controller: _finalCtrl,
                    label: 'Ödəniləcək məbləğ (₼)',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  )
                else if (_mode != 'clear')
                  AppTextField(
                    controller: _valueCtrl,
                    label: _mode == 'percent' ? 'Faiz (max 30% kassir)' : 'Endirim məbləği (₼)',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                if (widget.currentDiscount > 0 && !widget.checkoutMode) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => Navigator.pop(context, const SessionDiscountResult(clear: true)),
                    child: const Text('Endirimi ləğv et', style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: _submit,
              child: Text(widget.checkoutMode ? 'Tətbiq et' : 'Saxla'),
            ),
          ),
        ),
      ],
    );
  }
}
