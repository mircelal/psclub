import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import 'tone_synth.dart';

/// POS səs + titrəşim — web, Android, iOS, desktop.
class AppFeedback {
  AppFeedback._();

  static bool soundEnabled = true;
  static bool hapticEnabled = true;

  static final AudioPlayer _player = AudioPlayer(playerId: 'pos_feedback');
  static Future<void>? _queue = Future.value();
  static final Map<String, Uint8List> _bytesCache = {};
  static bool _playerReady = false;
  static bool _audioUnlocked = false;

  static void configure({bool? sound, bool? haptic}) {
    if (sound != null) soundEnabled = sound;
    if (haptic != null) hapticEnabled = haptic;
  }

  /// Brauzer autoplay siyasəti — ilk toxunuşdan sonra çağırın.
  static Future<void> unlock() async {
    if (kIsWeb || _audioUnlocked || !soundEnabled) return;
    try {
      await _ensurePlayer();
      await _playTone('_unlock', 880, 25, haptic: _HapticKind.light, soundOnly: true);
      _audioUnlocked = true;
    } catch (_) {}
  }

  static void cartAdd() => _enqueue('cart_add', 1175, 48, _HapticKind.light);
  static void cartRemove() => _enqueue('cart_remove', 740, 58, _HapticKind.light);
  static void success() => _enqueue('success', 988, 42, _HapticKind.medium);
  static void error() => _enqueue('error', 330, 95, _HapticKind.heavy);
  static void pause() => _enqueue('pause', 523, 52, _HapticKind.medium);

  static Future<void> timeExpired() async {
    if (!soundEnabled && !hapticEnabled) return;
    _enqueue('exp1', 988, 120, _HapticKind.alert);
    _queue = _queue!.then((_) => Future<void>.delayed(const Duration(milliseconds: 90)));
    _enqueue('exp2', 784, 120, _HapticKind.alert);
    _queue = _queue!.then((_) => Future<void>.delayed(const Duration(milliseconds: 90)));
    _enqueue('exp3', 523, 180, _HapticKind.alert);
    await _queue;
    await _alertVibration();
  }

  static void _enqueue(String cacheKey, int frequency, int durationMs, _HapticKind haptic) {
    if (!soundEnabled && !hapticEnabled) return;
    _queue = _queue!.then((_) => _playTone(cacheKey, frequency, durationMs, haptic: haptic));
  }

  static Future<void> _playTone(
    String cacheKey,
    int frequency,
    int durationMs, {
    required _HapticKind haptic,
    bool soundOnly = false,
  }) async {
    if (soundEnabled) {
      try {
        await _ensurePlayer();
        if (kIsWeb && !_audioUnlocked) {
          await unlock();
        }

        final bytes = await _toneBytes(cacheKey, frequency, durationMs);
        await _player.stop();
        await _player.play(BytesSource(bytes));

        await _player.onPlayerComplete.first.timeout(
          Duration(milliseconds: durationMs + 200),
          onTimeout: () {},
        );
      } catch (_) {
        try {
          await SystemSound.play(SystemSoundType.click);
        } catch (_) {}
      }
    }

    if (!soundOnly && hapticEnabled) {
      await _triggerHaptic(haptic);
    }
  }

  static Future<void> _ensurePlayer() async {
    if (kIsWeb || _playerReady) return;
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setVolume(0.92);
    _playerReady = true;
  }

  static Future<Uint8List> _toneBytes(String key, int frequency, int durationMs) async {
    final cacheKey = '${key}_${frequency}_$durationMs';
    return _bytesCache.putIfAbsent(cacheKey, () => synthesizeToneWav(frequency, durationMs));
  }

  static Future<void> _triggerHaptic(_HapticKind kind) async {
    switch (kind) {
      case _HapticKind.light:
        await HapticFeedback.selectionClick();
      case _HapticKind.medium:
        await HapticFeedback.mediumImpact();
      case _HapticKind.heavy:
        await HapticFeedback.heavyImpact();
      case _HapticKind.alert:
        await HapticFeedback.heavyImpact();
    }
  }

  /// Android/iOS — vaxt bitəndə uzun titrəşim nümunəsi.
  static Future<void> _alertVibration() async {
    if (!hapticEnabled || kIsWeb) return;

    try {
      final has = await Vibration.hasVibrator();
      if (has == true) {
        final hasCustom = await Vibration.hasCustomVibrationsSupport();
        if (hasCustom == true) {
          await Vibration.vibrate(pattern: [0, 120, 60, 120, 60, 220]);
          return;
        }
        await Vibration.vibrate(duration: 400);
        return;
      }
    } catch (_) {}

    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }
}

enum _HapticKind { light, medium, heavy, alert }
