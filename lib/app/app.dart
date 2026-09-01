import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';

import '../l10n/generated/app_localizations.dart';
import '../shared/providers/settings_provider.dart';
import '../shared/providers/storage_provider.dart';
import '../shared/providers/user_provider.dart';
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
      child: accessToken.when(
        loading: () => _StartupApp(
          themeMode: themeMode,
          locale: locale,
        ),
        error: (_, __) => _RouterApp(
          themeMode: themeMode,
          locale: locale,
          router: ref.watch(routerProvider(false)),
        ),
        data: (token) {
          final hasAccessToken = token?.isNotEmpty ?? false;
          if (!hasAccessToken) {
            return _RouterApp(
              themeMode: themeMode,
              locale: locale,
              router: ref.watch(routerProvider(false)),
            );
          }

          final bootstrap = ref.watch(userBootstrapProvider);
          return bootstrap.when(
            loading: () => _StartupApp(themeMode: themeMode, locale: locale),
            error: (_, __) => _RouterApp(
              themeMode: themeMode,
              locale: locale,
              router: ref.watch(routerProvider(false)),
            ),
            data: (_) => _RouterApp(
              themeMode: themeMode,
              locale: locale,
              router: ref.watch(routerProvider(true)),
            ),
          );
        },
      ),
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
        AppFlowyEditorLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) => SafeAreaStoreSync(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

class _StartupApp extends StatelessWidget {
  const _StartupApp({required this.themeMode, required this.locale});

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
        AppFlowyEditorLocalizations.delegate,
      ],
      home: const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
