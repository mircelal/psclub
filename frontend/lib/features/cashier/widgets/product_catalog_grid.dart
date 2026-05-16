import 'package:flutter/material.dart';
import '../../../core/utils/json_parse.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/product_image.dart';

class ProductCatalogGrid extends StatefulWidget {
  const ProductCatalogGrid({
    super.key,
    required this.products,
    required this.onSelect,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.crossAxisCount = 3,
  });

  final List<dynamic> products;
  final void Function(Map<String, dynamic> product) onSelect;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final int crossAxisCount;

  @override
  State<ProductCatalogGrid> createState() => _ProductCatalogGridState();
}

class _ProductCatalogGridState extends State<ProductCatalogGrid> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final list = widget.products.map((e) => e as Map<String, dynamic>).toList();
    if (_query.isEmpty) return list;
    final q = _query.toLowerCase();
    return list.where((p) => (p['name'] as String).toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isLight = Theme.of(context).brightness == Brightness.light;

    if (widget.isLoading) {
      return SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary)),
      );
    }

    if (widget.error != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft.withValues(alpha: isLight ? 0.5 : 1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text('Məhsullar yüklənmədi', style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
            const SizedBox(height: AppSpacing.xs),
            Text(widget.error!, style: TextStyle(fontSize: 12, color: p.textMuted), textAlign: TextAlign.center),
            if (widget.onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton(onPressed: widget.onRetry, child: const Text('Yenidən cəhd et')),
            ],
          ],
        ),
      );
    }

    final items = _filtered;
    if (widget.products.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: p.border),
        ),
        child: Center(
          child: Text('Kataloqda məhsul yoxdur', style: TextStyle(color: p.textMuted)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v.trim()),
          decoration: InputDecoration(
            hintText: 'Məhsul axtar...',
            prefixIcon: Icon(Icons.search, color: p.textMuted, size: 20),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 18, color: p.textMuted),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: Text('“$_query” üçün nəticə yoxdur', style: TextStyle(color: p.textMuted))),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.crossAxisCount,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: widget.crossAxisCount >= 5 ? 0.82 : 0.78,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final product = items[i];
              final price = jsonToDouble(product['price']);
              final stock = jsonToIntOrNull(product['stock_quantity']);
              final outOfStock = stock != null && stock <= 0;

              return Material(
                color: p.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: InkWell(
                  onTap: outOfStock ? null : () => widget.onSelect(product),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: p.border),
                      boxShadow: isLight
                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))]
                          : null,
                    ),
                    child: Opacity(
                      opacity: outOfStock ? 0.45 : 1,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Column(
                          children: [
                            Expanded(
                              child: Center(
                                child: ProductImage(
                                  imageUrl: product['image_url'] as String?,
                                  categoryName: product['category_name'] as String?,
                                  size: 52,
                                ),
                              ),
                            ),
                            Text(
                              product['name'] as String,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.textPrimary, height: 1.2),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${price.toStringAsFixed(2)} ₼',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
