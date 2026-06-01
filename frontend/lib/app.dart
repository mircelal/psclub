import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/auth_session_bridge.dart';
import 'core/feedback/feedback_unlock_scope.dart';
import 'core/layout/mobile_ui.dart';
import 'core/router/app_router.dart';
import 'core/settings/app_settings.dart';
import 'core/theme/app_theme.dart';

class PsClubApp extends ConsumerWidget {
  const PsClubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(appSettingsProvider);
    ref.watch(authSessionBridgeProvider);

    return settings.when(
      loading: () => MaterialApp(
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, stackTrace) => MaterialApp.router(
        title: 'PS Club POS',
        theme: AppTheme.dark,
        routerConfig: router,
      ),
      data: (s) {
        // businessConfig burada watch edilmir — hər yenilənmədə MaterialApp yenidən yaranır (veb donması).
        return FeedbackUnlockScope(
          child: MaterialApp.router(
            key: const ValueKey('psclub_root'),
            title: 'PS Club',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: s.materialThemeMode,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            ),
            builder: (context, child) {
              final scale = clampMobileTextScale(context);
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
          ),
        );
      },
    );
  }
}
