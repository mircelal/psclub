import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TableViewMode { grid, list, card }

enum AppThemeMode { dark, light, system }

class AppSettings {
  AppSettings({
    required this.themeMode,
    required this.tableViewMode,
  });

  final AppThemeMode themeMode;
  final TableViewMode tableViewMode;

  static const _keyTheme = 'ui_theme_mode';
  static const _keyTableView = 'ui_table_view_mode';

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      themeMode: AppThemeMode.values.asNameMap()[prefs.getString(_keyTheme)] ?? AppThemeMode.dark,
      tableViewMode: TableViewMode.values.asNameMap()[prefs.getString(_keyTableView)] ?? TableViewMode.grid,
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

  ThemeMode get materialThemeMode => switch (themeMode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.system => ThemeMode.system,
        _ => ThemeMode.dark,
      };
}

class AppSettingsNotifier extends StateNotifier<AsyncValue<AppSettings>> {
  AppSettingsNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    state = AsyncValue.data(await AppSettings.load());
  }

  Future<void> setTheme(AppThemeMode mode) async {
    final current = state.valueOrNull ?? await AppSettings.load();
    if (current.themeMode == mode) return;
    await current.saveTheme(mode);
    final next = AppSettings(themeMode: mode, tableViewMode: current.tableViewMode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      state = AsyncValue.data(next);
    });
  }

  Future<void> setTableView(TableViewMode mode) async {
    final current = state.valueOrNull ?? await AppSettings.load();
    if (current.tableViewMode == mode) return;
    await current.saveTableView(mode);
    final next = AppSettings(themeMode: current.themeMode, tableViewMode: mode);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      state = AsyncValue.data(next);
    });
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
