import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Windows native kiosk: Alt+Tab, Win, taskbar bloklanması.
abstract final class WindowsKioskShell {
  static const _channel = MethodChannel('psclub/kiosk');

  static bool get isSupported => !kIsWeb && Platform.isWindows;

  static Future<void> setEnabled(bool enabled) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('setEnabled', {'enabled': enabled});
    } catch (e, st) {
      debugPrint('WindowsKioskShell: $e\n$st');
    }
  }
}
