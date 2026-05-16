import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class MoneyText extends StatelessWidget {
  const MoneyText({
    super.key,
    required this.amount,
    this.size = MoneySize.medium,
    this.color,
    this.suffix = ' AZN',
  });

  final num amount;
  final MoneySize size;
  final Color? color;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final (fontSize, weight) = switch (size) {
      MoneySize.small => (14.0, FontWeight.w600),
      MoneySize.medium => (18.0, FontWeight.w700),
      MoneySize.large => (28.0, FontWeight.w800),
      MoneySize.hero => (36.0, FontWeight.w800),
    };

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: amount.toStringAsFixed(2),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: weight,
              color: color ?? Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
          TextSpan(
            text: suffix,
            style: TextStyle(
              fontSize: fontSize * 0.55,
              fontWeight: FontWeight.w500,
              color: color?.withValues(alpha: 0.7) ?? Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }
}

enum MoneySize { small, medium, large, hero }
