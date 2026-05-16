import 'package:flutter/material.dart';
import '../../../core/utils/json_parse.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class ProductQuickPick extends StatelessWidget {
  const ProductQuickPick({
    super.key,
    required this.products,
    required this.onSelect,
  });

  final List<dynamic> products;
  final void Function(Map<String, dynamic> product) onSelect;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, i) {
          final p = products[i] as Map<String, dynamic>;
          final stock = jsonToInt(p['stock_quantity']);
          final outOfStock = stock <= 0;
          final price = jsonToDouble(p['price']);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: outOfStock ? null : () => onSelect(p),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Ink(
                width: 120,
                decoration: BoxDecoration(
                  color: outOfStock ? AppColors.surface.withValues(alpha: 0.5) : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: outOfStock ? AppColors.border : AppColors.borderLight),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        p['name'] as String? ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: outOfStock ? AppColors.textMuted : AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${price.toStringAsFixed(2)} ₼',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: outOfStock ? AppColors.textMuted : AppColors.accent,
                            ),
                          ),
                          Text(
                            outOfStock ? '—' : '$stock',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
