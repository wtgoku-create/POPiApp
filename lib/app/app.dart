import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';

import '../l10n/generated/app_localizations.dart';
import '../shared/providers/settings_provider.dart';
import '../shared/providers/storage_provider.dart';
import '../shared/providers/purchase_provider.dart';
import '../shared/providers/user_provider.dart';
import '../shared/widgets/app_splash.dart';
import '../shared/widgets/safe_area_store_sync.dart';
import 'router.dart';
import 'theme.dart';

class StarterApp extends ConsumerWidget {
  const StarterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final accessToken = ref.watch(accessTokenProvider);

    return ToastificationWrapper(
      config: const ToastificationConfig(itemWidth: 320),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 360),
        reverseDuration: const Duration(milliseconds: 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: .985, end: 1).animate(animation),
              child: child,
            ),
          );
        },
        child: accessToken.when(
          loading: () => _StartupApp(
            key: const ValueKey('startup-app'),
            themeMode: themeMode,
            locale: locale,
          ),
          error: (_, __) => _RouterApp(
            key: const ValueKey('router-app'),
            themeMode: themeMode,
            locale: locale,
            router: ref.watch(routerProvider(false)),
          ),
          data: (token) {
            final hasAccessToken = token?.isNotEmpty ?? false;
            if (!hasAccessToken) {
              return _RouterApp(
                key: const ValueKey('router-app'),
                themeMode: themeMode,
                locale: locale,
                router: ref.watch(routerProvider(false)),
              );
            }

            // Start listening before any purchase screen opens so interrupted
            // StoreKit transactions can be verified after an app restart.
            ref.watch(applePurchaseServiceProvider);

            final bootstrap = ref.watch(userBootstrapProvider);
            return bootstrap.when(
              loading: () => _StartupApp(
                key: const ValueKey('startup-app'),
                themeMode: themeMode,
                locale: locale,
              ),
              error: (_, __) => _RouterApp(
                key: const ValueKey('router-app'),
                themeMode: themeMode,
                locale: locale,
                router: ref.watch(routerProvider(false)),
              ),
              data: (_) => _RouterApp(
                key: const ValueKey('router-app'),
                themeMode: themeMode,
                locale: locale,
                router: ref.watch(routerProvider(true)),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RouterApp extends StatelessWidget {
  const _RouterApp({
    required this.themeMode,
    required this.locale,
    required this.router,
    super.key,
  });

  final ThemeMode themeMode;
  final Locale? locale;
  final RouterConfig<Object> router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'POPi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
      ],
      routerConfig: router,
      builder: (context, child) => SafeAreaStoreSync(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

class _StartupApp extends StatelessWidget {
  const _StartupApp({
    required this.themeMode,
    required this.locale,
    super.key,
  });

  final ThemeMode themeMode;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POPi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
      ],
      home: const AppSplashScreen(),
    );
  }
}
