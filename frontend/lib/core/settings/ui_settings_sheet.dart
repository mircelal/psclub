import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../feedback/app_feedback.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../about/app_about.dart';
import 'app_settings.dart';

Future<void> showUiSettingsSheet(BuildContext context) {
  final parentContext = context;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _UiSettingsSheet(parentContext: parentContext),
  );
}

class _UiSettingsSheet extends ConsumerWidget {
  const _UiSettingsSheet({required this.parentContext});

  final BuildContext parentContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final p = context.palette;
    final maxH = MediaQuery.sizeOf(context).height * 0.88;

    return Container(
      decoration: BoxDecoration(
        color: p.surfaceElevated,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      child: settings.when(
        loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Text('Xəta: $e'),
        ),
        data: (s) => SizedBox(
          height: maxH,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xl, AppSpacing.xxl, AppSpacing.xxxl),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: p.borderLight, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Görünüş parametrləri', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.xxl),
              Text('Tema', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<AppThemeMode>(
                segments: const [
                  ButtonSegment(value: AppThemeMode.dark, label: Text('Qaranlıq'), icon: Icon(Icons.dark_mode, size: 18)),
                  ButtonSegment(value: AppThemeMode.light, label: Text('Aydınlıq'), icon: Icon(Icons.light_mode, size: 18)),
                  ButtonSegment(value: AppThemeMode.system, label: Text('Sistem'), icon: Icon(Icons.settings_brightness, size: 18)),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) {
                  final mode = v.first;
                  Navigator.pop(context);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(appSettingsProvider.notifier).setTheme(mode);
                  });
                },
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('Masa görünüşü', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              SegmentedButton<TableViewMode>(
                segments: const [
                  ButtonSegment(value: TableViewMode.grid, label: Text('Grid'), icon: Icon(Icons.grid_view, size: 18)),
                  ButtonSegment(value: TableViewMode.card, label: Text('Kart'), icon: Icon(Icons.view_module, size: 18)),
                  ButtonSegment(value: TableViewMode.list, label: Text('Listə'), icon: Icon(Icons.view_list, size: 18)),
                ],
                selected: {s.tableViewMode},
                onSelectionChanged: (v) {
                  final mode = v.first;
                  if (mode == s.tableViewMode) return;
                  Navigator.pop(context);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(appSettingsProvider.notifier).setTableView(mode);
                  });
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Aktiv masalarda timer və məbləğ real vaxtda yenilənir. Müddətli açılışda geri sayım göstərilir.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('Səs və titrəşim', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Səs effektləri'),
                subtitle: Text(
                  kIsWeb ? 'Brauzerdə ilk toxunuşdan sonra işləyir' : 'Məhsul, ödəniş və xəbərdarlıq tonları',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                value: s.soundEnabled,
                onChanged: (v) {
                  ref.read(appSettingsProvider.notifier).setSoundEnabled(v);
                  if (v) AppFeedback.cartAdd();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Titrəşim'),
                subtitle: Text(
                  kIsWeb ? 'Vebdə məhdud dəstək' : 'Android / iOS — xüsusilə vaxt bitəndə',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                value: s.hapticEnabled,
                onChanged: (v) {
                  ref.read(appSettingsProvider.notifier).setHapticEnabled(v);
                  if (v) AppFeedback.success();
                },
              ),
              const SizedBox(height: AppSpacing.xxl),
              const Divider(),
              const SizedBox(height: AppSpacing.lg),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                title: const Text('Program haqqında'),
                subtitle: Text('$kDeveloperName • mirtech.az', style: Theme.of(context).textTheme.bodySmall),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  showAppAboutDialog(parentContext);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
