import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class PaymentMethodSelector extends StatelessWidget {
  const PaymentMethodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 340;
        if (narrow) {
          return Column(
            children: [
              _MethodCard(
                value: 'cash',
                selected: selected,
                icon: Icons.payments_outlined,
                label: 'Nağd',
                onTap: () => onChanged('cash'),
                horizontal: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              _MethodCard(
                value: 'card',
                selected: selected,
                icon: Icons.credit_card,
                label: 'Kart',
                onTap: () => onChanged('card'),
                horizontal: true,
              ),
              const SizedBox(height: AppSpacing.sm),
              _MethodCard(
                value: 'mixed',
                selected: selected,
                icon: Icons.account_balance_wallet_outlined,
                label: 'Qarışıq',
                onTap: () => onChanged('mixed'),
                horizontal: true,
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: _MethodCard(
                value: 'cash',
                selected: selected,
                icon: Icons.payments_outlined,
                label: 'Nağd',
                onTap: () => onChanged('cash'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MethodCard(
                value: 'card',
                selected: selected,
                icon: Icons.credit_card,
                label: 'Kart',
                onTap: () => onChanged('card'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MethodCard(
                value: 'mixed',
                selected: selected,
                icon: Icons.account_balance_wallet_outlined,
                label: 'Qarışıq',
                onTap: () => onChanged('mixed'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.value,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    this.horizontal = false,
  });

  final String value;
  final String selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            vertical: horizontal ? AppSpacing.md : AppSpacing.md + 2,
            horizontal: horizontal ? AppSpacing.lg : AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primarySoft : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: horizontal
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: isSelected ? AppColors.primary : AppColors.textMuted, size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: isSelected ? AppColors.primary : AppColors.textMuted, size: 24),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
