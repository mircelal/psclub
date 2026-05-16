import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/json_parse.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
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

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  List<dynamic> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _products = await ref.read(posServiceProvider).getProducts();
    } catch (_) {
      _products = [];
    }
    if (mounted) setState(() => _loading = false);
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

  Future<List<dynamic>> _loadCategories() async {
    try {
      return await ref.read(posServiceProvider).getProductCategories();
    } catch (_) {
      return [];
    }
  }

  Future<void> _add() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '2');
    final stockCtrl = TextEditingController(text: '20');
    final skuCtrl = TextEditingController();
    String? pickedPath;
    int? categoryId;
    final categories = await _loadCategories();

    final ok = await showAppDialog<bool>(
      context: context,
      title: 'Yeni məhsul',
      subtitle: 'Şəkil fayldan yüklənir və avtomatik optimallaşdırılır',
      icon: Icons.inventory_2,
      body: StatefulBuilder(
        builder: (context, setDlg) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ImagePickTile(
              imagePath: pickedPath,
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
            AppTextField(controller: stockCtrl, label: 'İlkin stok miqdarı', keyboardType: TextInputType.number),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(controller: skuCtrl, label: 'SKU (istəyə bağlı)'),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _CategoryDropdown(
                categories: categories,
                value: categoryId,
                onChanged: (v) => setDlg(() => categoryId = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Ləğv')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yarat')),
      ],
    );

    if (ok != true) return;

    try {
      final id = await ref.read(posServiceProvider).createProduct({
        'name': nameCtrl.text.trim(),
        'price': double.tryParse(priceCtrl.text) ?? 0,
        'initial_stock': int.tryParse(stockCtrl.text) ?? 0,
        if (skuCtrl.text.trim().isNotEmpty) 'sku': skuCtrl.text.trim(),
        if (categoryId != null) 'category_id': categoryId,
      });
      if (pickedPath != null) {
        await _uploadImage(id, pickedPath!);
      }
      if (mounted) showAppSnackBar(context, pickedPath != null ? 'Məhsul və şəkil saxlanıldı' : 'Məhsul yaradıldı');
      _load();
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  Future<void> _edit(Map<String, dynamic> product) async {
    final id = jsonToInt(product['id']);
    final nameCtrl = TextEditingController(text: product['name']?.toString() ?? '');
    final priceCtrl = TextEditingController(text: jsonToDouble(product['price']).toStringAsFixed(2));
    final stockCtrl = TextEditingController(text: '${jsonToInt(product['stock_quantity'])}');
    final skuCtrl = TextEditingController(text: product['sku']?.toString() ?? '');
    String? pickedPath;
    int? categoryId = jsonToIntOrNull(product['category_id']);
    final categories = await _loadCategories();
    final existingImage = product['image_url'] as String?;

    final ok = await showAppDialog<bool>(
      context: context,
      title: 'Məhsulu redaktə et',
      subtitle: product['name']?.toString() ?? '',
      icon: Icons.edit_outlined,
      body: StatefulBuilder(
        builder: (context, setDlg) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ImagePickTile(
              imagePath: pickedPath,
              existingImageUrl: pickedPath == null ? existingImage : null,
              onPick: () async {
                final path = await _pickImageFile();
                if (path != null) setDlg(() => pickedPath = path);
              },
              onClear: pickedPath != null
                  ? () => setDlg(() => pickedPath = null)
                  : (existingImage != null && existingImage.isNotEmpty
                      ? () => setDlg(() {
                            pickedPath = null;
                          })
                      : null),
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
            AppTextField(controller: stockCtrl, label: 'Stok miqdarı', keyboardType: TextInputType.number),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(controller: skuCtrl, label: 'SKU'),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _CategoryDropdown(
                categories: categories,
                value: categoryId,
                onChanged: (v) => setDlg(() => categoryId = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () async {
                final confirm = await showAppDialog<bool>(
                  context: context,
                  title: 'Məhsulu sil',
                  subtitle: 'Kataloqdan gizlədiləcək (deaktiv)',
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
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Saxla')),
      ],
    );

    if (ok != true) return;

    try {
      await ref.read(posServiceProvider).updateProduct(id, {
        'name': nameCtrl.text.trim(),
        'price': double.tryParse(priceCtrl.text) ?? 0,
        'stock_quantity': int.tryParse(stockCtrl.text) ?? 0,
        'sku': skuCtrl.text.trim().isEmpty ? null : skuCtrl.text.trim(),
        if (categoryId != null) 'category_id': categoryId,
      });
      if (pickedPath != null) {
        await _uploadImage(id, pickedPath!);
      }
      if (mounted) {
        showAppSnackBar(context, 'Məhsul yeniləndi');
        _load();
      }
    } catch (e) {
      if (mounted) showAppSnackBar(context, e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AdminPageLayout(
      title: 'Məhsullar',
      subtitle: 'Kataloq, qiymət və şəkillər',
      action: FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add, size: 20), label: const Text('Məhsul')),
      child: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _products.isEmpty
              ? const EmptyState(icon: Icons.inventory_2_outlined, title: 'Məhsul yoxdur')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  itemCount: _products.length,
                  itemBuilder: (_, i) {
                    final product = _products[i] as Map<String, dynamic>;
                    final stock = jsonToInt(product['stock_quantity']);

                    return AdminListTile(
                      onTap: () => _edit(product),
                      leading: ProductImage(
                        imageUrl: product['image_url'] as String?,
                        categoryName: product['category_name'] as String?,
                        size: 44,
                        radius: AppSpacing.radiusSm,
                      ),
                      title: product['name'] as String,
                      subtitle: '${jsonToDouble(product['price']).toStringAsFixed(2)} AZN • Stok: $stock',
                      trailing: Icon(Icons.chevron_right, color: p.textMuted, size: 22),
                    );
                  },
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
        const DropdownMenuItem<int?>(value: null, child: Text('— Kateqoriya yox —')),
        ...categories.map((c) {
          final m = c as Map<String, dynamic>;
          final id = jsonToInt(m['id']);
          return DropdownMenuItem<int?>(value: id, child: Text(m['name'] as String));
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
                        Positioned(
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
                              child: Image.network(existingImageUrl!, fit: BoxFit.cover),
                            ),
                            Positioned(
                              bottom: AppSpacing.sm,
                              right: AppSpacing.sm,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Dəyiş', style: TextStyle(color: Colors.white, fontSize: 11)),
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
        Text(
          'Server 400×400 px JPEG-ə çevirir',
          style: TextStyle(fontSize: 11, color: p.textMuted),
          textAlign: TextAlign.center,
        ),
        if (onClear != null && (hasFile || hasExisting)) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: onClear, child: Text(hasFile ? 'Yeni şəkli ləğv et' : 'Mövcud şəkil saxlanır')),
        ],
      ],
    );
  }
}
