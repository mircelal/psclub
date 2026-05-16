import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/business_config_provider.dart';
import 'core/router/app_router.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';

class PsClubApp extends ConsumerWidget {
  const PsClubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(appSettingsProvider);
    ref.watch(businessConfigProvider);

    return settings.when(
      loading: () => MaterialApp(
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (_, __) => MaterialApp.router(
        title: 'PS Club POS',
        theme: AppTheme.dark,
        routerConfig: router,
      ),
      data: (s) {
        final biz = ref.watch(businessConfigProvider).valueOrNull;
        return MaterialApp.router(
          key: const ValueKey('psclub_root'),
          title: biz?.name ?? 'POS',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: s.materialThemeMode,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          ),
        );
      },
    );
  }
}
