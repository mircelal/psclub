import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:window_manager/window_manager.dart';

import 'app_settings.dart';
import 'windows_kiosk_shell.dart';

/// Windows (və digər desktop) pəncərə: kiosk rejimi və avtomatik başlatma.
abstract final class DesktopWindowService {
  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static bool get isWindows => !kIsWeb && Platform.isWindows;

  static void configureStartup() {
    if (!isWindows) return;
    LaunchAtStartup.instance.setup(
      appName: 'psclub_pos',
      appPath: Platform.resolvedExecutable,
    );
  }

  static Future<void> apply(AppSettings settings) async {
    if (!isDesktop) return;

    await WindowManager.instance.ensureInitialized();

    if (isWindows) {
      configureStartup();
      if (settings.launchAtStartup) {
        await LaunchAtStartup.instance.enable();
      } else {
        await LaunchAtStartup.instance.disable();
      }
      await WindowsKioskShell.setEnabled(settings.kioskModeEnabled);
    }

    await WindowManager.instance.setPreventClose(settings.kioskModeEnabled);

    if (settings.kioskModeEnabled) {
      await WindowManager.instance.setTitleBarStyle(TitleBarStyle.hidden);
      await WindowManager.instance.setFullScreen(true);
      await WindowManager.instance.setAlwaysOnTop(true);
      await WindowManager.instance.focus();
    } else {
      await WindowManager.instance.setAlwaysOnTop(false);
      await WindowManager.instance.setFullScreen(false);
      await WindowManager.instance.setTitleBarStyle(TitleBarStyle.normal);
      const size = Size(1280, 720);
      await WindowManager.instance.setSize(size);
      await WindowManager.instance.center();
    }
  }
}
