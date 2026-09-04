import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';

import '../l10n/generated/app_localizations.dart';
import '../shared/providers/settings_provider.dart';
import '../shared/providers/storage_provider.dart';
import '../shared/providers/purchase_provider.dart';
import '../shared/providers/user_provider.dart';
import '../shared/widgets/safe_area_store_sync.dart';
import 'router.dart';
import 'theme.dart';

class StarterApp extends ConsumerStatefulWidget {
  const StarterApp({this.onReady, super.key});

  final VoidCallback? onReady;

  @override
  ConsumerState<StarterApp> createState() => _StarterAppState();
}

class _StarterAppState extends ConsumerState<StarterApp> {
  bool _readyNotified = false;

  void _notifyReady() {
    final onReady = widget.onReady;
    if (_readyNotified || onReady == null) return;
    _readyNotified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => onReady());
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final accessToken = ref.watch(accessTokenProvider);

    final content = accessToken.when(
      loading: () => _StartupApp(themeMode: themeMode, locale: locale),
      error: (_, __) {
        _notifyReady();
        return _RouterApp(
          themeMode: themeMode,
          locale: locale,
          router: ref.watch(routerProvider(false)),
        );
      },
      data: (token) {
        final hasAccessToken = token?.isNotEmpty ?? false;
        if (!hasAccessToken) {
          _notifyReady();
          return _RouterApp(
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
          loading: () => _StartupApp(themeMode: themeMode, locale: locale),
          error: (_, __) {
            _notifyReady();
            return _RouterApp(
              themeMode: themeMode,
              locale: locale,
              router: ref.watch(routerProvider(false)),
            );
          },
          data: (_) {
            _notifyReady();
            return _RouterApp(
              themeMode: themeMode,
              locale: locale,
              router: ref.watch(routerProvider(true)),
            );
          },
        );
      },
    );

    return ToastificationWrapper(
      config: const ToastificationConfig(itemWidth: 320),
      child: content,
    );
  }
}

class _RouterApp extends StatelessWidget {
  const _RouterApp({
    required this.themeMode,
    required this.locale,
    required this.router,
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
      home: const ColoredBox(
        key: Key('app-startup-placeholder'),
        color: AppColors.surface,
      ),
    );
  }
}
