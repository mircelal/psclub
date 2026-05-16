import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/media_url.dart';
import '../../core/utils/json_parse.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/cashier_theme.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/product_image.dart';
import '../../services/pos_service.dart';
import 'widgets/admin_page_layout.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<dynamic> _products = [];
  List<dynamic> _categories = [];
  bool _loading = true;
  int? _filterCategoryId;
  bool _filterUncategorized = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final pos = ref.read(posServiceProvider);
    try {
      final results = await Future.wait([pos.getProducts(), pos.getProductCategories()]);
      _products = results[0];
      _categories = results[1];
    } catch (_) {
      _products = [];
      _categories = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _products.cast<Map<String, dynamic>>().where((p) {
      if (_filterUncategorized) {
        if (p['category_id'] != null) return false;
      } else if (_filterCategoryId != null) {
        if (jsonToIntOrNull(p['category_id']) != _filterCategoryId) return false;
      }
      if (q.isEmpty) return true;
      final name = (p['name'] as String? ?? '').toLowerCase();
      final sku = (p['sku'] as String? ?? '').toLowerCase();
      final cat = (p['category_name'] as String? ?? '').toLowerCase();
      return name.contains(q) || sku.contains(q) || cat.contains(q);
    }).toList();
  }

  Future<String?> _pickImageFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: false,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.single.path;
  }

  Future<void> _uploadImage(int productId, String path) async {
    await ref.read(posServiceProvider).uploadProductImage(productId, path);
  }

  Future<int?> _showCategoryForm({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? '');
    final sortCtrl = TextEditingController(text: '${jsonToIntOrNull(existing?['sort_order']) ?? 0}');
    final isEdit = existing != null;

    final ok = await showAppDialog<bool>(
      context: context,
      title: isEdit ? 'Kateqoriyanı redaktə et' : 'Yeni kateqoriya',
      subtitle: isEdit ? existing['name']?.toString() : 'Məs: İçkilər, Snacks, Əlavələr',
      icon: Icons.category_outlined,
      body: Column(
        children: [
          AppTextField(controller: nameCtrl, label: 'Kateqoriya adı', autofocus: true),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: sortCtrl,
            label: 'Sıra nömrəsi (kiçik = yuxarıda)',
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(isEdit ? 'Saxla' : 'Yarat')),
      ],
    );

    if (ok != true) return null;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      if (mounted) showAppSnackBar(context, 'Ad daxil edin', isError: true);
      return null;
    }
    final sortOrder = int.tryParse(sortCtrl.text) ?? 0;

    try {
      if (isEdit) {
        final updated = await ref.read(posServiceProvider).updateProductCategory(
              jsonToInt(existing['id']),
              {'name': name, 'sort_order': sortOrder},
            );
        if (mounted) showAppSnackBar(context, 'Kateqoriya yeniləndi');
        await _load();
        return jsonToInt(updated['id']);
      }
      final created = await ref.read(posServiceProvider).createProductCategory(name, sortOrder: sortOrder);
      if (mounted) showAppSnackBar(context, 'Kateqoriya yaradıldı');
      await _load();
      return jsonToInt(created['id']);
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
      return null;
    }
  }

  Future<void> _deleteCategory(Map<String, dynamic> cat) async {
    final count = jsonToInt(cat['product_count']);
    final ok = await showAppDialog<bool>(
      context: context,
      title: 'Kateqoriyanı sil',
      subtitle: count > 0 ? 'Bu kateqoriyada $count məhsul var — silmək olmaz' : '“${cat['name']}” silinsin?',
      icon: Icons.delete_outline,
      body: count > 0
          ? Text(
              'Əvvəlcə məhsulları başqa kateqoriyaya köçürün və ya kateqoriyasız edin.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : const SizedBox.shrink(),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Bağla')),
        if (count == 0)
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Sil'),
          ),
      ],
    );
    if (ok != true) return;

    try {
      await ref.read(posServiceProvider).deleteProductCategory(jsonToInt(cat['id']));
      if (_filterCategoryId == jsonToInt(cat['id'])) {
        _filterCategoryId = null;
        _filterUncategorized = false;
      }
      if (mounted) {
        showAppSnackBar(context, 'Kateqoriya silindi');
        _load();
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  Future<void> _addProduct() async {
    await _productForm();
  }

  Future<void> _editProduct(Map<String, dynamic> product) async {
    await _productForm(product: product);
  }

  Future<void> _productForm({Map<String, dynamic>? product}) async {
    final isEdit = product != null;
    final id = isEdit ? jsonToInt(product['id']) : 0;
    final nameCtrl = TextEditingController(text: product?['name']?.toString() ?? '');
    final priceCtrl = TextEditingController(text: isEdit ? jsonToDouble(product['price']).toStringAsFixed(2) : '2');
    final stockCtrl = TextEditingController(text: isEdit ? '${jsonToInt(product['stock_quantity'])}' : '20');
    final skuCtrl = TextEditingController(text: product?['sku']?.toString() ?? '');
    String? pickedPath;
    int? categoryId = jsonToIntOrNull(product?['category_id']);
    final existingImage = product?['image_url'] as String?;

    final ok = await showAppDialog<bool>(
      context: context,
      title: isEdit ? 'Məhsulu redaktə et' : 'Yeni məhsul',
      subtitle: isEdit ? product['name']?.toString() : 'Şəkil fayldan yüklənir və optimallaşdırılır',
      icon: Icons.inventory_2,
      maxWidth: 480,
      body: StatefulBuilder(
        builder: (context, setDlg) {
          var cats = _categories;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ImagePickTile(
                imagePath: pickedPath,
                existingImageUrl: pickedPath == null ? existingImage : null,
                onPick: () async {
                  final path = await _pickImageFile();
                  if (path != null) setDlg(() => pickedPath = path);
                },
                onClear: pickedPath != null ? () => setDlg(() => pickedPath = null) : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(controller: nameCtrl, label: 'Məhsul adı'),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: priceCtrl,
                label: 'Satış qiyməti (AZN)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: stockCtrl,
                label: isEdit ? 'Stok miqdarı' : 'İlkin stok miqdarı',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(controller: skuCtrl, label: 'SKU (istəyə bağlı)'),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _CategoryDropdown(
                      categories: cats,
                      value: categoryId,
                      onChanged: (v) => setDlg(() => categoryId = v),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: IconButton.filledTonal(
                      tooltip: 'Yeni kateqoriya',
                      onPressed: () async {
                        final newId = await _showCategoryForm();
                        if (newId != null) {
                          setDlg(() {
                            categoryId = newId;
                            cats = _categories;
                          });
                        }
                      },
                      icon: const Icon(Icons.add, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      actions: [
        if (isEdit)
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () async {
                  final confirm = await showAppDialog<bool>(
                    context: context,
                    title: 'Məhsulu sil',
                    subtitle: 'Kataloqdan gizlədiləcək',
                    icon: Icons.delete_outline,
                    body: Text('“${product['name']}” silinsin?', style: Theme.of(context).textTheme.bodyMedium),
                    actions: [
                      OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Xeyr')),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                        child: const Text('Sil'),
                      ),
                    ],
                  );
                  if (confirm == true && context.mounted) {
                    Navigator.pop(context, false);
                    await ref.read(posServiceProvider).deleteProduct(id);
                    if (mounted) {
                      showAppSnackBar(context, 'Məhsul silindi');
                      _load();
                    }
                  }
                },
                child: Text('Sil', style: TextStyle(color: AppColors.danger)),
              ),
            ),
          ),
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(isEdit ? 'Saxla' : 'Yarat')),
      ],
    );

    if (ok != true) return;

    try {
      if (isEdit) {
        await ref.read(posServiceProvider).updateProduct(id, {
          'name': nameCtrl.text.trim(),
          'price': double.tryParse(priceCtrl.text) ?? 0,
          'stock_quantity': int.tryParse(stockCtrl.text) ?? 0,
          'sku': skuCtrl.text.trim().isEmpty ? null : skuCtrl.text.trim(),
          'category_id': categoryId,
        });
        if (pickedPath != null) await _uploadImage(id, pickedPath!);
        if (mounted) showAppSnackBar(context, 'Məhsul yeniləndi');
      } else {
        final newId = await ref.read(posServiceProvider).createProduct({
          'name': nameCtrl.text.trim(),
          'price': double.tryParse(priceCtrl.text) ?? 0,
          'initial_stock': int.tryParse(stockCtrl.text) ?? 0,
          if (skuCtrl.text.trim().isNotEmpty) 'sku': skuCtrl.text.trim(),
          if (categoryId != null) 'category_id': categoryId,
        });
        if (pickedPath != null) await _uploadImage(newId, pickedPath!);
        if (mounted) showAppSnackBar(context, pickedPath != null ? 'Məhsul və şəkil saxlanıldı' : 'Məhsul yaradıldı');
      }
      _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final filtered = _filteredProducts;

    return AdminPageLayout(
      title: 'Məhsullar',
      subtitle: 'Kataloq, kateqoriyalar, qiymət və şəkillər',
      action: FilledButton.icon(
        onPressed: () {
          if (_tabs.index == 0) {
            _addProduct();
          } else {
            _showCategoryForm();
          }
        },
        icon: Icon(_tabs.index == 0 ? Icons.add : Icons.category_outlined, size: 20),
        label: Text(_tabs.index == 0 ? 'Məhsul' : 'Kateqoriya'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            controller: _tabs,
            tabs: [
              Tab(text: 'Məhsullar (${_products.length})'),
              Tab(text: 'Kateqoriyalar (${_categories.length})'),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _ProductsTab(
                        searchCtrl: _searchCtrl,
                        filtered: filtered,
                        categories: _categories,
                        filterCategoryId: _filterCategoryId,
                        filterUncategorized: _filterUncategorized,
                        onFilter: (catId, uncategorized) {
                          setState(() {
                            _filterCategoryId = catId;
                            _filterUncategorized = uncategorized;
                          });
                        },
                        onEdit: _editProduct,
                        onRefresh: _load,
                        palette: p,
                      ),
                      _CategoriesTab(
                        categories: _categories,
                        onAdd: () => _showCategoryForm(),
                        onEdit: (c) => _showCategoryForm(existing: c),
                        onDelete: _deleteCategory,
                        onRefresh: _load,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductsTab extends StatelessWidget {
  const _ProductsTab({
    required this.searchCtrl,
    required this.filtered,
    required this.categories,
    required this.filterCategoryId,
    required this.filterUncategorized,
    required this.onFilter,
    required this.onEdit,
    required this.onRefresh,
    required this.palette,
  });

  final TextEditingController searchCtrl;
  final List<Map<String, dynamic>> filtered;
  final List<dynamic> categories;
  final int? filterCategoryId;
  final bool filterUncategorized;
  final void Function(int? categoryId, bool uncategorized) onFilter;
  final void Function(Map<String, dynamic>) onEdit;
  final VoidCallback onRefresh;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.sm),
          child: TextField(
            controller: searchCtrl,
            decoration: InputDecoration(
              hintText: 'Məhsul, SKU və ya kateqoriya axtar…',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => searchCtrl.clear(),
                    )
                  : null,
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            children: [
              _FilterChip(
                label: 'Hamısı',
                selected: filterCategoryId == null && !filterUncategorized,
                onTap: () => onFilter(null, false),
              ),
              _FilterChip(
                label: 'Kateqoriyasız',
                selected: filterUncategorized,
                onTap: () => onFilter(null, true),
              ),
              ...categories.map((c) {
                final m = c as Map<String, dynamic>;
                final id = jsonToInt(m['id']);
                return _FilterChip(
                  label: m['name'] as String,
                  selected: filterCategoryId == id,
                  onTap: () => onFilter(id, false),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: searchCtrl.text.isNotEmpty ? 'Nəticə tapılmadı' : 'Məhsul yoxdur',
                  action: searchCtrl.text.isEmpty
                      ? null
                      : TextButton(onPressed: onRefresh, child: const Text('Yenilə')),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, 0, AppSpacing.xxl, AppSpacing.xxl),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final product = filtered[i];
                    final stock = jsonToInt(product['stock_quantity']);
                    final catName = product['category_name'] as String?;

                    return AdminListTile(
                      onTap: () => onEdit(product),
                      leading: ProductImage(
                        imageUrl: product['image_url'] as String?,
                        categoryName: catName,
                        size: 44,
                        radius: AppSpacing.radiusSm,
                      ),
                      title: product['name'] as String,
                      subtitle: [
                        '${jsonToDouble(product['price']).toStringAsFixed(2)} AZN',
                        'Stok: $stock',
                        if (catName != null && catName.isNotEmpty) catName,
                      ].join(' • '),
                      trailing: Icon(Icons.chevron_right, color: palette.textMuted, size: 22),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab({
    required this.categories,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onRefresh,
  });

  final List<dynamic> categories;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return EmptyState(
        icon: Icons.category_outlined,
        title: 'Kateqoriya yoxdur',
        subtitle: 'İçkilər, snacks və s. üçün kateqoriya yaradın',
        action: FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('İlk kateqoriya')),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      itemCount: categories.length,
      itemBuilder: (_, i) {
        final cat = categories[i] as Map<String, dynamic>;
        final count = jsonToInt(cat['product_count']);

        return AdminListTile(
          onTap: () => onEdit(cat),
          leading: CircleAvatar(
            backgroundColor: CashierTheme.accentSubtle(context),
            child: Icon(Icons.folder_outlined, color: CashierTheme.accent(context), size: 22),
          ),
          title: cat['name'] as String,
          subtitle: '$count məhsul • sıra: ${jsonToInt(cat['sort_order'])}',
          onDelete: () => onDelete(cat),
          trailing: Icon(Icons.chevron_right, color: CashierTheme.textTertiary(context), size: 22),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  final List<dynamic> categories;
  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int?>(
      value: value,
      decoration: const InputDecoration(labelText: 'Kateqoriya'),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('— Kateqoriya seçilməyib —')),
        ...categories.map((c) {
          final m = c as Map<String, dynamic>;
          return DropdownMenuItem<int?>(value: jsonToInt(m['id']), child: Text(m['name'] as String));
        }),
      ],
      onChanged: onChanged,
    );
  }
}

class _ImagePickTile extends StatelessWidget {
  const _ImagePickTile({
    required this.imagePath,
    required this.onPick,
    this.existingImageUrl,
    this.onClear,
  });

  final String? imagePath;
  final String? existingImageUrl;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasFile = imagePath != null;
    final hasExisting = !hasFile && existingImageUrl != null && existingImageUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Ink(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: p.border, width: hasFile || hasExisting ? 2 : 1),
            ),
            child: SizedBox(
              height: 140,
              child: hasFile
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 1),
                          child: Image.file(File(imagePath!), fit: BoxFit.cover),
                        ),
                        const Positioned(
                          top: AppSpacing.sm,
                          right: AppSpacing.sm,
                          child: Icon(Icons.check_circle, color: AppColors.success, size: 22),
                        ),
                      ],
                    )
                  : hasExisting
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 1),
                              child: Image.network(MediaUrl.resolve(existingImageUrl)!, fit: BoxFit.cover),
                            ),
                            const Positioned(
                              bottom: AppSpacing.sm,
                              right: AppSpacing.sm,
                              child: DecoratedBox(
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.all(Radius.circular(4))),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Text('Dəyiş', style: TextStyle(color: Colors.white, fontSize: 11)),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload_outlined, size: 36, color: p.textMuted),
                            const SizedBox(height: AppSpacing.sm),
                            Text('Şəkil seç', style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
                            const SizedBox(height: AppSpacing.xs),
                            Text('JPG, PNG, WEBP • max 8 MB', style: TextStyle(fontSize: 11, color: p.textMuted)),
                          ],
                        ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text('Server 400×400 px JPEG-ə çevirir', style: TextStyle(fontSize: 11, color: p.textMuted), textAlign: TextAlign.center),
        if (onClear != null && hasFile) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: onClear, child: const Text('Yeni şəkli ləğv et')),
        ],
      ],
    );
  }
}
