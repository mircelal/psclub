import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/json_parse.dart';
import '../../../core/widgets/product_image.dart';

class SessionCartList extends StatelessWidget {
  const SessionCartList({
    super.key,
    required this.items,
    required this.productsTotal,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
    this.compact = false,
  });

  final List<dynamic> items;
  final double productsTotal;
  final void Function(Map<String, dynamic> item) onIncrease;
  final void Function(Map<String, dynamic> item) onDecrease;
  final void Function(Map<String, dynamic> item) onRemove;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final accent = Theme.of(context).colorScheme.primary;

    if (items.isEmpty) {
      return Container(
        padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xxl),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: p.border),
        ),
        child: Column(
          children: [
            Icon(Icons.shopping_cart_outlined, size: 40, color: p.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text('Səbət boşdur', style: TextStyle(color: p.textMuted, fontWeight: FontWeight.w500)),
            const SizedBox(height: AppSpacing.xs),
            Text('Soldan məhsul seçin', style: TextStyle(color: p.textMuted, fontSize: 12)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...items.map((raw) {
          final item = raw as Map<String, dynamic>;
          final qty = jsonToInt(item['quantity'], 1);
          final unitPrice = jsonToDouble(item['unit_price']);
          final lineTotal = unitPrice * qty;
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: [
                ProductImage(
                  imageUrl: item['image_url'] as String?,
                  categoryName: item['category_name'] as String?,
                  size: compact ? 36 : 44,
                  radius: AppSpacing.radiusSm,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['product_name'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: compact ? 13 : 14, color: p.textPrimary),
                      ),
                      Text(
                        '${unitPrice.toStringAsFixed(2)} ₼',
                        style: TextStyle(fontSize: 11, color: p.textMuted),
                      ),
                    ],
                  ),
                ),
                _QtyControl(
                  qty: qty,
                  onMinus: () => onDecrease(item),
                  onPlus: () => onIncrease(item),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: compact ? 56 : 64,
                  child: Text(
                    '${lineTotal.toStringAsFixed(2)} ₼',
                    textAlign: TextAlign.end,
                    style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary, fontSize: compact ? 12 : 13),
                  ),
                ),
                IconButton(
                  onPressed: () => onRemove(item),
                  icon: Icon(Icons.delete_outline, size: 20, color: AppColors.danger.withValues(alpha: 0.85)),
                  tooltip: 'Sil',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            children: [
              Text('Məhsullar cəmi', style: TextStyle(color: p.textSecondary, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(
                '${productsTotal.toStringAsFixed(2)} ₼',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: accent),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QtyControl extends StatelessWidget {
  const _QtyControl({required this.qty, required this.onMinus, required this.onPlus});

  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QtyBtn(icon: Icons.remove, onTap: onMinus),
          Container(
            constraints: const BoxConstraints(minWidth: 28),
            alignment: Alignment.center,
            child: Text('$qty', style: TextStyle(fontWeight: FontWeight.w700, color: p.textPrimary)),
          ),
          _QtyBtn(icon: Icons.add, onTap: onPlus),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}
