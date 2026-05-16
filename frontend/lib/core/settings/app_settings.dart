import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'desktop_window_service.dart';

enum TableViewMode { grid, list, card }

enum AppThemeMode { dark, light, system }

class AppSettings {
  AppSettings({
    required this.themeMode,
    required this.tableViewMode,
    this.kioskModeEnabled = false,
    this.launchAtStartup = false,
  });

  final AppThemeMode themeMode;
  final TableViewMode tableViewMode;
  final bool kioskModeEnabled;
  final bool launchAtStartup;

  static const _keyTheme = 'ui_theme_mode';
  static const _keyTableView = 'ui_table_view_mode';
  static const _keyKiosk = 'ui_kiosk_mode';
  static const _keyLaunchAtStartup = 'ui_launch_at_startup';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      themeMode: AppThemeMode.values.asNameMap()[prefs.getString(_keyTheme)] ?? AppThemeMode.dark,
      tableViewMode: TableViewMode.values.asNameMap()[prefs.getString(_keyTableView)] ?? TableViewMode.grid,
      kioskModeEnabled: prefs.getBool(_keyKiosk) ?? false,
      launchAtStartup: prefs.getBool(_keyLaunchAtStartup) ?? false,
    );
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

  Future<void> saveLaunchAtStartup(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLaunchAtStartup, enabled);
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
    bool? launchAtStartup,
  }) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        tableViewMode: tableViewMode ?? this.tableViewMode,
        kioskModeEnabled: kioskModeEnabled ?? this.kioskModeEnabled,
        launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      );
}

class AppSettingsNotifier extends StateNotifier<AsyncValue<AppSettings>> {
  AppSettingsNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
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

  Future<void> setKioskMode(bool enabled) async {
    final current = state.valueOrNull ?? await AppSettings.load();
    if (current.kioskModeEnabled == enabled) return;
    await current.saveKioskMode(enabled);
    final next = current.copyWith(kioskModeEnabled: enabled);
    _emit(next);
    await DesktopWindowService.apply(next);
  }

  Future<void> setLaunchAtStartup(bool enabled) async {
    final current = state.valueOrNull ?? await AppSettings.load();
    if (current.launchAtStartup == enabled) return;
    await current.saveLaunchAtStartup(enabled);
    final next = current.copyWith(launchAtStartup: enabled);
    _emit(next);
    await DesktopWindowService.apply(next);
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
