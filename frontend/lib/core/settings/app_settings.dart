import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../feedback/app_feedback.dart';
import 'desktop_window_service.dart';

enum TableViewMode { grid, list, card }

enum AppThemeMode { dark, light, system }

class AppSettings {
  AppSettings({
    required this.themeMode,
    required this.tableViewMode,
    this.kioskModeEnabled = false,
    this.kioskLocked = false,
    this.launchAtStartup = false,
    this.soundEnabled = true,
    this.hapticEnabled = true,
  });

  final AppThemeMode themeMode;
  final TableViewMode tableViewMode;
  final bool kioskModeEnabled;
  /// Kassir kiosk rejimini söndürə bilməz; yalnız admin.
  final bool kioskLocked;
  final bool launchAtStartup;
  final bool soundEnabled;
  final bool hapticEnabled;

  static const _keyTheme = 'ui_theme_mode';
  static const _keyTableView = 'ui_table_view_mode';
  static const _keyKiosk = 'ui_kiosk_mode';
  static const _keyKioskLocked = 'ui_kiosk_locked';
  static const _keyLaunchAtStartup = 'ui_launch_at_startup';
  static const _keyInstallSeeded = 'ui_install_defaults_seeded';
  static const _keySound = 'ui_sound_enabled';
  static const _keyHaptic = 'ui_haptic_enabled';

  /// Quraşdırıcı build — dart-define (sabit sətir mütləqdir).
  static const bool installKioskDefaults = bool.fromEnvironment(
    'KIOSK_DEFAULT_ENABLED',
    defaultValue: false,
  );

  static const bool installKioskLocked = bool.fromEnvironment(
    'KIOSK_LOCKED',
    defaultValue: false,
  );

  static const bool installLaunchAtStartup = bool.fromEnvironment(
    'LAUNCH_AT_STARTUP_DEFAULT',
    defaultValue: false,
  );

  /// Quraşdırıcı versiyasında ilk açılışda kiosk parametrlərini yazır.
  static Future<void> seedInstallDefaultsIfNeeded(SharedPreferences prefs) async {
    if (!installKioskDefaults) return;
    if (prefs.getBool(_keyInstallSeeded) == true) return;

    await prefs.setBool(_keyKiosk, true);
    await prefs.setBool(_keyKioskLocked, installKioskLocked);
    await prefs.setBool(_keyLaunchAtStartup, installLaunchAtStartup);
    await prefs.setBool(_keyInstallSeeded, true);
  }

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    await seedInstallDefaultsIfNeeded(prefs);

    final settings = AppSettings(
      themeMode: AppThemeMode.values.asNameMap()[prefs.getString(_keyTheme)] ?? AppThemeMode.dark,
      tableViewMode: TableViewMode.values.asNameMap()[prefs.getString(_keyTableView)] ?? TableViewMode.grid,
      kioskModeEnabled: prefs.getBool(_keyKiosk) ?? installKioskDefaults,
      kioskLocked: prefs.getBool(_keyKioskLocked) ?? installKioskLocked,
      launchAtStartup: prefs.getBool(_keyLaunchAtStartup) ?? installLaunchAtStartup,
      soundEnabled: prefs.getBool(_keySound) ?? true,
      hapticEnabled: prefs.getBool(_keyHaptic) ?? true,
    );
    AppFeedback.configure(
      sound: kIsWeb ? false : settings.soundEnabled,
      haptic: kIsWeb ? false : settings.hapticEnabled,
    );
    return settings;
  }

  Future<void> saveTheme(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTheme, mode.name);
  }

  Future<void> saveTableView(TableViewMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTableView, mode.name);
  }

  Future<void> saveKioskMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyKiosk, enabled);
  }

  Future<void> saveKioskLocked(bool locked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyKioskLocked, locked);
  }

  Future<void> saveLaunchAtStartup(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLaunchAtStartup, enabled);
  }

  Future<void> saveSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySound, enabled);
  }

  Future<void> saveHapticEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHaptic, enabled);
  }

  ThemeMode get materialThemeMode => switch (themeMode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.system => ThemeMode.system,
        _ => ThemeMode.dark,
      };

  AppSettings copyWith({
    AppThemeMode? themeMode,
    TableViewMode? tableViewMode,
    bool? kioskModeEnabled,
    bool? kioskLocked,
    bool? launchAtStartup,
    bool? soundEnabled,
    bool? hapticEnabled,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        tableViewMode: tableViewMode ?? this.tableViewMode,
        kioskModeEnabled: kioskModeEnabled ?? this.kioskModeEnabled,
        kioskLocked: kioskLocked ?? this.kioskLocked,
        launchAtStartup: launchAtStartup ?? this.launchAtStartup,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      );
}

class AppSettingsNotifier extends StateNotifier<AsyncValue<AppSettings>> {
  AppSettingsNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  static AppSettings? _cached;

  /// main() artıq yükləyibsə, provider boş qalmasın.
  static void warmCache(AppSettings settings) {
    _cached = settings;
  }

  Future<void> _init() async {
    if (_cached != null) {
      state = AsyncValue.data(_cached!);
      _cached = null;
      return;
    }
    state = AsyncValue.data(await AppSettings.load());
  }

  void _emit(AppSettings next) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      state = AsyncValue.data(next);
    });
  }

  Future<void> setTheme(AppThemeMode mode) async {
    final current = state.valueOrNull ?? await AppSettings.load();
    if (current.themeMode == mode) return;
    await current.saveTheme(mode);
    _emit(current.copyWith(themeMode: mode));
  }

  Future<void> setTableView(TableViewMode mode) async {
    final current = state.valueOrNull ?? await AppSettings.load();
    if (current.tableViewMode == mode) return;
    await current.saveTableView(mode);
    _emit(current.copyWith(tableViewMode: mode));
  }

  Future<void> setKioskMode(bool enabled, {bool asAdmin = false}) async {
    final current = state.valueOrNull ?? await AppSettings.load();
    if (current.kioskModeEnabled == enabled) return;
    if (!enabled && current.kioskLocked && !asAdmin) return;
    await current.saveKioskMode(enabled);
    final next = current.copyWith(kioskModeEnabled: enabled);
    _emit(next);
    await DesktopWindowService.apply(next);
  }

  Future<void> setKioskLocked(bool locked, {bool asAdmin = false}) async {
    if (!asAdmin) return;
    final current = state.valueOrNull ?? await AppSettings.load();
    if (current.kioskLocked == locked) return;
    await current.saveKioskLocked(locked);
    _emit(current.copyWith(kioskLocked: locked));
  }

  Future<void> setLaunchAtStartup(bool enabled, {bool asAdmin = false}) async {
    final current = state.valueOrNull ?? await AppSettings.load();
    if (current.launchAtStartup == enabled) return;
    if (!asAdmin && current.kioskLocked) return;
    await current.saveLaunchAtStartup(enabled);
    final next = current.copyWith(launchAtStartup: enabled);
    _emit(next);
    await DesktopWindowService.apply(next);
  }

  Future<void> setSoundEnabled(bool enabled) async {
    final current = state.valueOrNull ?? await AppSettings.load();
    if (current.soundEnabled == enabled) return;
    await current.saveSoundEnabled(enabled);
    final next = current.copyWith(soundEnabled: enabled);
    AppFeedback.configure(sound: enabled);
    _emit(next);
    if (enabled) await AppFeedback.unlock();
  }

  Future<void> setHapticEnabled(bool enabled) async {
    final current = state.valueOrNull ?? await AppSettings.load();
    if (current.hapticEnabled == enabled) return;
    await current.saveHapticEnabled(enabled);
    final next = current.copyWith(hapticEnabled: enabled);
    AppFeedback.configure(haptic: enabled);
    _emit(next);
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AsyncValue<AppSettings>>((ref) {
  return AppSettingsNotifier();
});

String formatDurationHms(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
