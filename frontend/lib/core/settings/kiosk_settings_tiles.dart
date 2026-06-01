import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';
import 'desktop_window_service.dart';
/// Kiosk və Windows avtomatik başlatma — admin parametrlərində.
class KioskSettingsTiles extends ConsumerWidget {
  const KioskSettingsTiles({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!DesktopWindowService.isDesktop) {
      return const _KioskDesktopOnlyNotice();
    }

    final settingsAsync = ref.watch(appSettingsProvider);
    return settingsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => Text('Parametrlər yüklənmədi: $e'),
      data: (settings) => _KioskControls(settings: settings, dense: dense),
    );
  }
}

class _KioskControls extends ConsumerWidget {
  const _KioskControls({required this.settings, required this.dense});

  final AppSettings settings;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!dense) ...[
          Text('Kiosk və Windows', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Kassir terminalı: tam ekran, Alt+Tab və taskbar bloklanır. '
            'Bu parametrləri yalnız admin dəyişə bilər.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
        ],
        SwitchListTile(
          contentPadding: dense ? EdgeInsets.zero : null,
          secondary: Icon(Icons.fullscreen, color: theme.colorScheme.primary),
          title: const Text('Kiosk rejimi'),
          subtitle: dense
              ? null
              : const Text('Tam ekran · üstə · bağlama bloklanır · Alt+Tab işləmir'),
          value: settings.kioskModeEnabled,
          onChanged: (v) => notifier.setKioskMode(v, asAdmin: true),
        ),
        SwitchListTile(
          contentPadding: dense ? EdgeInsets.zero : null,
          secondary: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
          title: const Text('Kiosk kilidi'),
          subtitle: dense
              ? null
              : const Text('Aktiv olanda kassir kiosk rejimini söndürə bilməz'),
          value: settings.kioskLocked,
          onChanged: settings.kioskModeEnabled
              ? (v) => notifier.setKioskLocked(v, asAdmin: true)
              : null,
        ),
        if (DesktopWindowService.isWindows) ...[
          if (!dense) const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: dense ? EdgeInsets.zero : null,
            secondary: Icon(Icons.login, color: theme.colorScheme.primary),
            title: const Text('Windows ilə başlat'),
            subtitle: dense
                ? null
                : const Text('Kompüter açılanda PS Club avtomatik işə düşür'),
            value: settings.launchAtStartup,
            onChanged: (v) => notifier.setLaunchAtStartup(v, asAdmin: true),
          ),
        ],
        if (settings.kioskModeEnabled && settings.kioskLocked) ...[
          const SizedBox(height: 8),
          Text(
            'Kiosk kilidi aktivdir — kassir parametrlərindən çıxa bilməz.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _KioskDesktopOnlyNotice extends StatelessWidget {
  const _KioskDesktopOnlyNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.desktop_windows_outlined, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yalnız Windows proqramı', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Kiosk və avtomatik başlatma brauzerdə (veb) işləmir. '
                  'Kassir kompüterində PS Club POS quraşdırın (psclub_pos.exe), '
                  'sonra həmin proqramda admin kimi Parametrlərə daxil olun.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

