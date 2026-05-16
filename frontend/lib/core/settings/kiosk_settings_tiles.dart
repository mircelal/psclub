import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';
import 'desktop_window_service.dart';

/// Kiosk və Windows avtomatik başlatma keçidləri.
class KioskSettingsTiles extends ConsumerWidget {
  const KioskSettingsTiles({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!DesktopWindowService.isDesktop) {
      return const SizedBox.shrink();
    }

    final settings = ref.watch(appSettingsProvider).valueOrNull;
    if (settings == null) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!dense) ...[
          Text('Kiosk rejimi', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Tam ekran, pəncərə çərçivəsi gizlənir, proqram bağlanmır. Söndürmək üçün admin parametrlərinə daxil olun.',
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
              : const Text('Tam ekran · üstə · bağlama bloklanır'),
          value: settings.kioskModeEnabled,
          onChanged: (v) => ref.read(appSettingsProvider.notifier).setKioskMode(v),
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
            onChanged: (v) => ref.read(appSettingsProvider.notifier).setLaunchAtStartup(v),
          ),
        ],
      ],
    );
  }
}
