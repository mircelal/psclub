import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';
import 'desktop_window_service.dart';

/// Ayarlar dəyişəndə pəncərə rejimini yeniləyir.
class KioskSettingsListener extends ConsumerStatefulWidget {
  const KioskSettingsListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<KioskSettingsListener> createState() => _KioskSettingsListenerState();
}

class _KioskSettingsListenerState extends ConsumerState<KioskSettingsListener> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(appSettingsProvider, (prev, next) {
      next.whenData(DesktopWindowService.apply);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
