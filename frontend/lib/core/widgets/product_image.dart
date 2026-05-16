import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    this.imageUrl,
    this.categoryName,
    this.size = 56,
    this.radius = AppSpacing.radiusMd,
  });

  final String? imageUrl;
  final String? categoryName;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final url = imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(p),
        ),
      );
    }
    return _placeholder(p);
  }

  Widget _placeholder(AppPalette p) {
    final (icon, colors) = _categoryStyle(categoryName);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Icon(icon, color: Colors.white.withValues(alpha: 0.95), size: size * 0.42),
    );
  }

  (IconData, List<Color>) _categoryStyle(String? category) {
    final c = (category ?? '').toLowerCase();
    if (c.contains('içki') || c.contains('drink')) {
      return (Icons.local_drink_rounded, [const Color(0xFF5AC8FA), const Color(0xFF007AFF)]);
    }
    if (c.contains('snack') || c.contains('qida')) {
      return (Icons.fastfood_rounded, [const Color(0xFFFF9500), const Color(0xFFFF3B30)]);
    }
    return (Icons.inventory_2_rounded, [AppColors.primary, const Color(0xFF5E3FD4)]);
  }
}
