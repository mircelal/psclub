import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_state.dart';
import 'app_settings.dart';

/// Kiosk parametrləri yalnız admin tərəfindən dəyişilə bilər (kassir terminalı).
abstract final class KioskPolicy {
  static bool isAdmin(WidgetRef ref) => ref.read(authProvider).valueOrNull?.isAdmin == true;

  static bool canChangeKioskSettings(WidgetRef ref) => isAdmin(ref);

  static bool canDisableKiosk(AppSettings settings, {required bool asAdmin}) {
    if (!settings.kioskModeEnabled) return true;
    if (asAdmin) return true;
    return !settings.kioskLocked;
  }
}
