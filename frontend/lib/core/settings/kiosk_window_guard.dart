import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app_settings.dart';
import 'desktop_window_service.dart';

/// Kiosk aktiv olanda pəncərə bağlanmasın (X, Alt+F4 və s.).
class KioskWindowGuard extends ConsumerStatefulWidget {
  const KioskWindowGuard({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KioskWindowGuard> createState() => _KioskWindowGuardState();
}

class _KioskWindowGuardState extends ConsumerState<KioskWindowGuard> with WindowListener {
  @override
  void initState() {
    super.initState();
    if (DesktopWindowService.isDesktop) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (DesktopWindowService.isDesktop) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  @override
  void onWindowClose() async {
    final kiosk = ref.read(appSettingsProvider).valueOrNull?.kioskModeEnabled ?? false;
    if (kiosk) {
      return;
    }
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
