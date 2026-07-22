import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../services/pos_service.dart';

/// Məhsulu soft-delete edir (kataloqdan gizlədilir). Uğurlu olarsa `true`.
Future<bool> confirmAndDeleteProduct(
  WidgetRef ref,
  BuildContext context, {
  required int id,
  required String name,
}) async {
  final confirm = await showAppDialog<bool>(
    context: context,
    title: 'Məhsulu sil',
    subtitle: 'Kataloqdan gizlədiləcək — satış tarixçəsi qalır',
    icon: Icons.delete_outline,
    body: Text('“$name” silinsin?', style: Theme.of(context).textTheme.bodyMedium),
    actions: [
      OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('Xeyr')),
      FilledButton(
        onPressed: () => Navigator.pop(context, true),
        style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
        child: const Text('Sil'),
      ),
    ],
  );
  if (confirm != true) return false;

  try {
    await ref.read(posServiceProvider).deleteProduct(id);
    ref.invalidate(productsProvider);
    if (context.mounted) {
      showAppSnackBar(context, 'Məhsul silindi');
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      showAppSnackBar(context, ApiClient.messageFromError(e), isError: true);
    }
    return false;
  }
}
