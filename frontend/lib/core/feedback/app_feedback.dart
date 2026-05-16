import 'dart:io' show Platform, Process;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// POS səs bildirişləri — Windows kassada Console.Beep, digər platformalarda SystemSound.
class AppFeedback {
  AppFeedback._();

  static bool enabled = true;

  static void cartAdd() => _tone(880, 70);
  static void cartRemove() => _tone(520, 90);
  static void success() => _tone(660, 50);
  static void error() => _tone(280, 140);
  static void pause() => _tone(400, 60);

  /// Geri sayım bitəndə — 3 tonlu xəbərdarlıq.
  static Future<void> timeExpired() async {
    if (!enabled) return;
    _tone(988, 140);
    await Future<void>.delayed(const Duration(milliseconds: 160));
    _tone(784, 140);
    await Future<void>.delayed(const Duration(milliseconds: 160));
    _tone(523, 220);
  }

  static void _tone(int frequency, int durationMs) {
    if (!enabled) return;
    if (!kIsWeb && Platform.isWindows) {
      Process.run(
        'powershell',
        ['-NoProfile', '-Command', '[console]::beep($frequency,$durationMs)'],
        runInShell: true,
      );
      return;
    }
    SystemSound.play(SystemSoundType.click);
  }
}
