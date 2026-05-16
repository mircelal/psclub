import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/business_config_provider.dart';

class BusinessLogo extends ConsumerWidget {
  const BusinessLogo({super.key, this.size = 28, this.fallbackIcon});

  final double size;
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(businessConfigProvider).valueOrNull ?? BusinessConfig.fallback;
    final url = config.logoUrl;

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

    return Image.asset(
      'assets/icons/app_icon.png',
      width: size,
      height: size,
      errorBuilder: (_, __, ___) => _fallback(context, config.name),
    );
  }

  Widget _fallback(BuildContext context, String name) {
    if (fallbackIcon != null) {
      return Icon(fallbackIcon, size: size * 0.85);
    }
    final letter = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Text(letter, style: TextStyle(fontWeight: FontWeight.w800, fontSize: size * 0.45)),
    );
  }
}
