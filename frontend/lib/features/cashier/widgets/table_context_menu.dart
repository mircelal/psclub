import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/feedback/app_feedback.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/cashier_theme.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../services/pos_service.dart';
import '../close_session_dialog.dart';
import '../shift_guard.dart';
import 'table_session_state.dart';

/// Masa kartında sağ klik — yalnız cari vəziyyətə uyğun əməliyyatlar.
Future<void> showTableContextMenu({
  required BuildContext context,
  required WidgetRef ref,
  required Map<String, dynamic> table,
  required Offset globalPosition,
  required void Function(Map<String, dynamic> table) onOpenTable,
  required void Function(int sessionId) onOpenSession,
  required VoidCallback onChanged,
}) async {
  final name = table['name'] as String? ?? 'Masa';
  final sessionId = TableSessionState.openSessionId(table);
  final isPaused = TableSessionState.isPaused(table);

  final items = <PopupMenuEntry<String>>[
    PopupMenuItem<String>(
      enabled: false,
      height: 40,
      child: Text(
        name,
        style: CashierTheme.stationTitle(context, size: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    const PopupMenuDivider(height: 8),
  ];

  if (TableSessionState.canCloseBill(table) && sessionId != null) {
    items.add(
      PopupMenuItem(
        value: 'panel',
        child: _MenuRow(
          icon: Icons.receipt_long_outlined,
          label: 'Sifariş paneli',
          color: CashierTheme.textPrimary(context),
        ),
      ),
    );
    items.add(
      PopupMenuItem(
        value: 'pause',
        child: _MenuRow(
          icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          label: isPaused ? 'Davam et' : 'Pause',
          color: CashierTheme.textPrimary(context),
        ),
      ),
    );
    items.add(const PopupMenuDivider(height: 8));
    items.add(
      PopupMenuItem(
        value: 'close',
        child: _MenuRow(
          icon: Icons.payment_outlined,
          label: 'Hesabı bağla',
          color: CashierTheme.accent(context),
        ),
      ),
    );
  } else if (TableSessionState.canOpenSession(table)) {
    items.add(
      PopupMenuItem(
        value: 'open',
        child: _MenuRow(
          icon: Icons.play_circle_outline,
          label: 'Sessiya aç',
          color: CashierTheme.accent(context),
        ),
      ),
    );
  } else {
    return;
  }

  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      globalPosition.dx + 1,
      globalPosition.dy + 1,
    ),
    items: items,
  );

  if (selected == null || !context.mounted) return;

  if (!await ensureOpenShiftForCashier(context, ref)) return;

  switch (selected) {
    case 'open':
      onOpenTable(table);
    case 'panel':
      onOpenSession(sessionId!);
    case 'pause':
      try {
        if (isPaused) {
          await ref.read(posServiceProvider).resumeSession(sessionId!);
          AppFeedback.success();
        } else {
          await ref.read(posServiceProvider).pauseSession(sessionId!);
          AppFeedback.pause();
        }
        onChanged();
      } catch (e) {
        if (context.mounted) showAppSnackBar(context, e.toString(), isError: true);
      }
    case 'close':
      final closed = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => CloseSessionDialog(
          sessionId: sessionId!,
          tableName: name,
        ),
      );
      if (closed == true) {
        AppFeedback.success();
        onChanged();
      }
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
