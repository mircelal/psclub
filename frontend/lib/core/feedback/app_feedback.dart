import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'tone_synth.dart';

/// POS səs bildirişləri — təmiz ton, üst-üstə düşmür (cızıltı yoxdur).
class AppFeedback {
  AppFeedback._();

  static bool enabled = true;

  static final AudioPlayer _player = AudioPlayer(playerId: 'pos_feedback');
  static Future<void>? _queue = Future.value();
  static final Map<String, String> _cachedPaths = {};
  static bool _playerReady = false;

  static Future<void> _ensurePlayer() async {
    if (_playerReady) return;
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setVolume(0.9);
    _playerReady = true;
  }

  static void cartAdd() => _enqueue('cart_add', 1175, 48);
  static void cartRemove() => _enqueue('cart_remove', 740, 58);
  static void success() => _enqueue('success', 988, 42);
  static void error() => _enqueue('error', 330, 95);
  static void pause() => _enqueue('pause', 523, 52);

  /// Geri sayım bitəndə — 3 tonlu xəbərdarlıq.
  static Future<void> timeExpired() async {
    if (!enabled) return;
    _enqueue('exp1', 988, 120);
    _queue = _queue!.then((_) => Future<void>.delayed(const Duration(milliseconds: 90)));
    _enqueue('exp2', 784, 120);
    _queue = _queue!.then((_) => Future<void>.delayed(const Duration(milliseconds: 90)));
    _enqueue('exp3', 523, 180);
    await _queue;
  }

  static void _enqueue(String cacheKey, int frequency, int durationMs) {
    if (!enabled) return;
    _queue = _queue!.then((_) => _playTone(cacheKey, frequency, durationMs));
  }

  static Future<void> _playTone(String cacheKey, int frequency, int durationMs) async {
    try {
      if (kIsWeb) {
        await SystemSound.play(SystemSoundType.click);
        return;
      }

      if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
        await SystemSound.play(SystemSoundType.click);
        return;
      }

      await _ensurePlayer();
      final path = await _toneFilePath(cacheKey, frequency, durationMs);

      await _player.stop();
      await _player.play(DeviceFileSource(path));

      await _player.onPlayerComplete.first.timeout(
        Duration(milliseconds: durationMs + 150),
        onTimeout: () {},
      );
    } catch (_) {
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  static Future<String> _toneFilePath(String key, int frequency, int durationMs) async {
    final cacheKey = '${key}_${frequency}_$durationMs';
    final existing = _cachedPaths[cacheKey];
    if (existing != null) return existing;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/psclub_$cacheKey.wav');
    if (!await file.exists()) {
      await file.writeAsBytes(synthesizeToneWav(frequency, durationMs), flush: true);
    }
    _cachedPaths[cacheKey] = file.path;
    return file.path;
  }
}
