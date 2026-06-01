import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/theme/cashier_theme.dart';

/// Növbə jurnalı sətri üçün ikon, fon və məbləğ rəngləri.
class ShiftActivityVisual {
  const ShiftActivityVisual({
    required this.icon,
    required this.accent,
    required this.iconBackground,
    required this.border,
    this.surface,
    required this.amount,
    required this.index,
  });

  final IconData icon;
  final Color accent;
  final Color iconBackground;
  final Color border;
  final Color? surface;
  final Color amount;
  final Color index;

  static ShiftActivityVisual resolve(BuildContext context, Map<String, dynamic> row) {
    final kind = row['kind'] as String? ?? '';
    final sign = row['sign'] as String? ?? '+';
    final isOut = sign == '−' || sign == '-';

    final success = AdminTheme.success(context);
    final danger = AdminTheme.danger(context);
    final warning = AdminTheme.warning(context);
    final info = AdminTheme.info(context);
    final accentBrand = CashierTheme.accent(context);
    final muted = CashierTheme.textSecondary(context);
    const ownerPurple = Color(0xFF7C4DFF);

    switch (kind) {
      case 'shift_open':
        return ShiftActivityVisual(
          icon: Icons.play_circle_filled,
          accent: success,
          iconBackground: success.withValues(alpha: 0.18),
          border: success.withValues(alpha: 0.45),
          surface: success.withValues(alpha: 0.07),
          amount: success,
          index: success,
        );
      case 'shift_close':
        return ShiftActivityVisual(
          icon: Icons.stop_circle,
          accent: info,
          iconBackground: info.withValues(alpha: 0.16),
          border: info.withValues(alpha: 0.4),
          surface: info.withValues(alpha: 0.06),
          amount: info,
          index: info,
        );
      case 'order_deleted':
        return ShiftActivityVisual(
          icon: Icons.delete_forever_rounded,
          accent: danger,
          iconBackground: danger.withValues(alpha: 0.22),
          border: danger.withValues(alpha: 0.65),
          surface: danger.withValues(alpha: 0.12),
          amount: danger,
          index: danger,
        );
      case 'session':
        final sessionType = row['session_type'] as String? ?? 'table';
        final isCounter = sessionType == 'counter';
        return ShiftActivityVisual(
          icon: isCounter ? Icons.point_of_sale_outlined : Icons.table_restaurant_outlined,
          accent: accentBrand,
          iconBackground: accentBrand.withValues(alpha: 0.14),
          border: accentBrand.withValues(alpha: 0.35),
          amount: success,
          index: accentBrand,
        );
      case 'cash_movement':
        return _cashMovement(
          context,
          type: row['movement_type'] as String? ?? '',
          isOut: isOut,
          success: success,
          danger: danger,
          warning: warning,
          ownerPurple: ownerPurple,
          muted: muted,
        );
      default:
        return ShiftActivityVisual(
          icon: Icons.help_outline,
          accent: muted,
          iconBackground: muted.withValues(alpha: 0.12),
          border: CashierTheme.border(context),
          amount: muted,
          index: muted,
        );
    }
  }

  static ShiftActivityVisual _cashMovement(
    BuildContext context, {
    required String type,
    required bool isOut,
    required Color success,
    required Color danger,
    required Color warning,
    required Color ownerPurple,
    required Color muted,
  }) {
    switch (type) {
      case 'pay_in':
        return ShiftActivityVisual(
          icon: Icons.add_circle_outline,
          accent: success,
          iconBackground: success.withValues(alpha: 0.16),
          border: success.withValues(alpha: 0.35),
          amount: success,
          index: success,
        );
      case 'expense':
        return ShiftActivityVisual(
          icon: Icons.payments_outlined,
          accent: warning,
          iconBackground: warning.withValues(alpha: 0.18),
          border: warning.withValues(alpha: 0.4),
          amount: warning,
          index: warning,
        );
      case 'owner_withdrawal':
        return ShiftActivityVisual(
          icon: Icons.account_balance_wallet_outlined,
          accent: ownerPurple,
          iconBackground: ownerPurple.withValues(alpha: 0.16),
          border: ownerPurple.withValues(alpha: 0.38),
          amount: ownerPurple,
          index: ownerPurple,
        );
      case 'refund':
        return ShiftActivityVisual(
          icon: Icons.undo_outlined,
          accent: danger,
          iconBackground: danger.withValues(alpha: 0.16),
          border: danger.withValues(alpha: 0.38),
          amount: danger,
          index: danger,
        );
      default:
        return ShiftActivityVisual(
          icon: isOut ? Icons.remove_circle_outline : Icons.add_circle_outline,
          accent: muted,
          iconBackground: muted.withValues(alpha: 0.12),
          border: CashierTheme.border(context),
          amount: isOut ? muted : success,
          index: muted,
        );
    }
  }
}
