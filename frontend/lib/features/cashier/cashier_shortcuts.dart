import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/brand_colors.dart';
import '../../core/theme/cashier_theme.dart';
import '../../core/widgets/app_dialog.dart';
import 'widgets/cashier_filter_bar.dart';

// ── Intents ─────────────────────────────────────────────────────────────────

class CashierHelpIntent extends Intent {
  const CashierHelpIntent();
}

class CashierCounterSaleIntent extends Intent {
  const CashierCounterSaleIntent();
}

class CashierRefreshIntent extends Intent {
  const CashierRefreshIntent();
}

class CashierSettingsIntent extends Intent {
  const CashierSettingsIntent();
}

class CashierFilterAllIntent extends Intent {
  const CashierFilterAllIntent();
}

class CashierFilterActiveIntent extends Intent {
  const CashierFilterActiveIntent();
}

class CashierFilterEmptyIntent extends Intent {
  const CashierFilterEmptyIntent();
}

class CashierTableSlotIntent extends Intent {
  const CashierTableSlotIntent(this.slot);
  final int slot;
}

class CashierAdminIntent extends Intent {
  const CashierAdminIntent();
}

// ── Shortcuts map ───────────────────────────────────────────────────────────

Map<ShortcutActivator, Intent> cashierShortcutBindings({bool adminEnabled = false}) {
  return {
    const SingleActivator(LogicalKeyboardKey.f1): const CashierHelpIntent(),
    const SingleActivator(LogicalKeyboardKey.f2): const CashierCounterSaleIntent(),
    const SingleActivator(LogicalKeyboardKey.f5): const CashierRefreshIntent(),
    const SingleActivator(LogicalKeyboardKey.f9): const CashierSettingsIntent(),
    const SingleActivator(LogicalKeyboardKey.digit1): const CashierTableSlotIntent(1),
    const SingleActivator(LogicalKeyboardKey.digit2): const CashierTableSlotIntent(2),
    const SingleActivator(LogicalKeyboardKey.digit3): const CashierTableSlotIntent(3),
    const SingleActivator(LogicalKeyboardKey.digit4): const CashierTableSlotIntent(4),
    const SingleActivator(LogicalKeyboardKey.digit5): const CashierTableSlotIntent(5),
    const SingleActivator(LogicalKeyboardKey.digit6): const CashierTableSlotIntent(6),
    const SingleActivator(LogicalKeyboardKey.digit7): const CashierTableSlotIntent(7),
    const SingleActivator(LogicalKeyboardKey.digit8): const CashierTableSlotIntent(8),
    const SingleActivator(LogicalKeyboardKey.digit9): const CashierTableSlotIntent(9),
    const SingleActivator(LogicalKeyboardKey.digit0): const CashierTableSlotIntent(10),
    const SingleActivator(LogicalKeyboardKey.numpad1): const CashierTableSlotIntent(1),
    const SingleActivator(LogicalKeyboardKey.numpad2): const CashierTableSlotIntent(2),
    const SingleActivator(LogicalKeyboardKey.numpad3): const CashierTableSlotIntent(3),
    const SingleActivator(LogicalKeyboardKey.numpad4): const CashierTableSlotIntent(4),
    const SingleActivator(LogicalKeyboardKey.numpad5): const CashierTableSlotIntent(5),
    const SingleActivator(LogicalKeyboardKey.numpad6): const CashierTableSlotIntent(6),
    const SingleActivator(LogicalKeyboardKey.numpad7): const CashierTableSlotIntent(7),
    const SingleActivator(LogicalKeyboardKey.numpad8): const CashierTableSlotIntent(8),
    const SingleActivator(LogicalKeyboardKey.numpad9): const CashierTableSlotIntent(9),
    const SingleActivator(LogicalKeyboardKey.numpad0): const CashierTableSlotIntent(10),
    const SingleActivator(LogicalKeyboardKey.digit1, control: true): const CashierFilterAllIntent(),
    const SingleActivator(LogicalKeyboardKey.digit2, control: true): const CashierFilterActiveIntent(),
    const SingleActivator(LogicalKeyboardKey.digit3, control: true): const CashierFilterEmptyIntent(),
    if (adminEnabled)
      const SingleActivator(LogicalKeyboardKey.keyA, control: true): const CashierAdminIntent(),
  };
}

// ── Help dialog ─────────────────────────────────────────────────────────────

void showCashierShortcutsDialog(BuildContext context, {bool showAdmin = false}) {
  final rows = <(String keys, String desc)>[
    ('F1', 'Qısayollar siyahısı'),
    ('F2', 'Birbaşa satış'),
    ('F5', 'Masaları yenilə'),
    ('F9', 'Görünüş parametrləri'),
    ('1 – 9, 0', 'Stansiya seç (siyahı sırası ilə)'),
    ('Ctrl + 1', 'Bütün stansiyalar'),
    ('Ctrl + 2', 'Yalnız aktiv'),
    ('Ctrl + 3', 'Yalnız boş'),
    ('Esc', 'Pəncərəni bağla'),
    if (showAdmin) ('Ctrl + A', 'Admin panel'),
  ];

  showAppDialog<void>(
    context: context,
    title: 'Klaviatura qısayolları',
    subtitle: 'Klassik POS üslubunda — sürətli kassir işi',
    icon: Icons.keyboard_outlined,
    maxWidth: 480,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ShortcutRow(keys: row.$1, description: row.$2),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Rəqəm düymələri cari filtrə görə stansiya siyahısındakı 1–10-cu stansiyanı açır. '
          'Boş stansiyada sessiya açılır, aktivdə sessiya paneli.',
          style: TextStyle(fontSize: 12, color: CashierTheme.textSecondary(context), height: 1.4),
        ),
      ],
    ),
    actions: [
      FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Bağla')),
    ],
  );
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.keys, required this.description});

  final String keys;
  final String description;

  @override
  Widget build(BuildContext context) {
    final isLight = CashierTheme.isLight(context);
    return Row(
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 88),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isLight
                ? BrandColors.brightBlue.withValues(alpha: 0.10)
                : BrandColors.brightBlue.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isLight
                  ? BrandColors.brightBlue.withValues(alpha: 0.35)
                  : BrandColors.sky.withValues(alpha: 0.55),
            ),
          ),
          child: Text(
            keys,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isLight ? BrandColors.navy : DarkNeutral.textHigh,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Text(description, style: TextStyle(fontSize: 14, color: CashierTheme.textPrimary(context))),
        ),
      ],
    );
  }
}

// ── Wrapper ───────────────────────────────────────────────────────────────────

typedef CashierTableSlotHandler = void Function(int slot);

class CashierShortcutsScope extends StatelessWidget {
  const CashierShortcutsScope({
    super.key,
    required this.child,
    required this.onHelp,
    required this.onCounterSale,
    required this.onRefresh,
    required this.onSettings,
    required this.onFilter,
    required this.onTableSlot,
    this.onAdmin,
    this.adminEnabled = false,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onHelp;
  final VoidCallback onCounterSale;
  final VoidCallback onRefresh;
  final VoidCallback onSettings;
  final ValueChanged<CashierTableFilter> onFilter;
  final CashierTableSlotHandler onTableSlot;
  final VoidCallback? onAdmin;
  final bool adminEnabled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Shortcuts(
      shortcuts: cashierShortcutBindings(adminEnabled: adminEnabled),
      child: Actions(
        actions: {
          CashierHelpIntent: CallbackAction<CashierHelpIntent>(onInvoke: (_) {
            onHelp();
            return null;
          }),
          CashierCounterSaleIntent: CallbackAction<CashierCounterSaleIntent>(onInvoke: (_) {
            onCounterSale();
            return null;
          }),
          CashierRefreshIntent: CallbackAction<CashierRefreshIntent>(onInvoke: (_) {
            onRefresh();
            return null;
          }),
          CashierSettingsIntent: CallbackAction<CashierSettingsIntent>(onInvoke: (_) {
            onSettings();
            return null;
          }),
          CashierFilterAllIntent: CallbackAction<CashierFilterAllIntent>(onInvoke: (_) {
            onFilter(CashierTableFilter.all);
            return null;
          }),
          CashierFilterActiveIntent: CallbackAction<CashierFilterActiveIntent>(onInvoke: (_) {
            onFilter(CashierTableFilter.active);
            return null;
          }),
          CashierFilterEmptyIntent: CallbackAction<CashierFilterEmptyIntent>(onInvoke: (_) {
            onFilter(CashierTableFilter.empty);
            return null;
          }),
          CashierTableSlotIntent: CallbackAction<CashierTableSlotIntent>(onInvoke: (intent) {
            onTableSlot(intent.slot);
            return null;
          }),
          if (onAdmin != null)
            CashierAdminIntent: CallbackAction<CashierAdminIntent>(onInvoke: (_) {
              onAdmin!();
              return null;
            }),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}
