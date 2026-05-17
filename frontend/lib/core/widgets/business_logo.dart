import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/business_config_provider.dart';
import '../config/media_url.dart';
import '../theme/brand_colors.dart';
import '../theme/cashier_theme.dart';

class BusinessLogo extends ConsumerWidget {
  const BusinessLogo({super.key, this.size = 28, this.fallbackIcon});

  final double size;
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(businessConfigProvider).valueOrNull ?? BusinessConfig.fallback;
    final url = MediaUrl.resolve(config.logoUrl);

    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(context, config.name),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asset = Image.asset(
      'assets/icons/app_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _fallback(context, config.name),
    );

    if (!isDark) return asset;

    // Tünd fonda tünd ikon görünmür — brend mavi tonla vurğula.
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Color(0xFF8AB4F8), BlendMode.srcIn),
      child: asset,
    );
  }

  Widget _fallback(BuildContext context, String name) {
    if (fallbackIcon != null) {
      return Icon(
        fallbackIcon,
        size: size * 0.85,
        color: CashierTheme.accent(context),
      );
    }
    final letter = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: BrandColors.brightBlue.withValues(alpha: isDark ? 0.28 : 0.15),
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(
          color: BrandColors.brightBlue.withValues(alpha: isDark ? 0.5 : 0.25),
        ),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: size * 0.45,
          color: isDark ? DarkNeutral.textHigh : BrandColors.navy,
        ),
      ),
    );
  }
}
