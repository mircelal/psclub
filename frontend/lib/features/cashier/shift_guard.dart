import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/auth/auth_state.dart';
import '../../core/widgets/app_snackbar.dart';
import 'shift_dialogs.dart';
import 'shift_provider.dart';

/// Kassir üçün açıq növbə tələb olunur; admin kassir panelində istisna olmaya bilər.
bool cashierBypassesShift(WidgetRef ref) {
  return ref.read(authProvider).valueOrNull?.isAdmin == true;
}

Future<bool> hasOpenShift(WidgetRef ref) async {
  final cached = ref.read(currentShiftProvider).valueOrNull;
  if (cached != null) return true;
  try {
    return await ref.read(currentShiftProvider.future) != null;
  } catch (_) {
    return false;
  }
}

/// Satış və sessiya əməliyyatlarından əvvəl çağırın. false = bloklanıb.
Future<bool> ensureOpenShiftForCashier(BuildContext context, WidgetRef ref) async {
  if (cashierBypassesShift(ref)) return true;
  if (await hasOpenShift(ref)) return true;
  if (!context.mounted) return false;

  showAppSnackBar(
    context,
    'Satışa başlamaq üçün əvvəlcə növbəni açın və kassadakı nağdı daxil edin',
    isError: true,
  );

  final opened = await showOpenShiftDialog(context, ref);
  if (!opened || !context.mounted) return false;

  return hasOpenShift(ref);
}
