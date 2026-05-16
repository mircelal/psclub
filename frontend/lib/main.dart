import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/settings/app_settings.dart';
import 'core/settings/desktop_window_service.dart';
import 'core/settings/kiosk_settings_listener.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (DesktopWindowService.isDesktop) {
    await WindowManager.instance.ensureInitialized();
    DesktopWindowService.configureStartup();
    final settings = await AppSettings.load();
    await DesktopWindowService.apply(settings);
  }

  runApp(
    const ProviderScope(
      child: KioskSettingsListener(
        child: PsClubApp(),
      ),
    ),
  );
}
