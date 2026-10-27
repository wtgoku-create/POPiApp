import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';

import '../../../app/theme.dart';
import '../../../app/router.dart';
import '../../../core/diagnostics/launch_diagnostics.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/storage_provider.dart';
import '../../../shared/providers/settings_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_keyboard_dismiss.dart';
import '../data/demo_repository.dart';
import 'demo_home_page.dart';

/// Mock creation flows share the existing account pages and local preferences.
class DemoApp extends ConsumerStatefulWidget {
  const DemoApp({
    this.locale = const Locale('zh'),
    this.repository,
    this.bootstrapUser = true,
    super.key,
  });
  final Locale locale;
  final DemoRepository? repository;
  final bool bootstrapUser;
  @override
  ConsumerState<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends ConsumerState<DemoApp> {
  late final _ownsRepository = widget.repository == null;
  late final _repository =
      widget.repository ??
      (DemoRepository(ref.read(preferencesStorageProvider))..restore());
  late final _router = createAppRouter(
    homeBuilder: (_, _) {
      LaunchDiagnostics.mark(LaunchStage.routerHomeBuilder);
      return DemoHomePage(repository: _repository);
    },
  );

  @override
  void initState() {
    super.initState();
    LaunchDiagnostics.mark(LaunchStage.demoAppInit);
  }

  @override
  void dispose() {
    _router.dispose();
    if (_ownsRepository) _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    LaunchDiagnostics.mark(LaunchStage.demoAppBuildBegin);
    if (widget.bootstrapUser) ref.watch(userBootstrapProvider);
    final router = _router;
    LaunchDiagnostics.mark(LaunchStage.routerReady);
    final app = MaterialApp.router(
      routerConfig: router,
      title: 'POPi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light.copyWith(
        scaffoldBackgroundColor: AppColors.profileBackground,
        appBarTheme: AppTheme.light.appBarTheme.copyWith(
          backgroundColor: AppColors.profileBackground,
        ),
      ),
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(localeProvider) ?? widget.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (_, child) => AppKeyboardDismiss(child: child!),
    );
    // Toastification shares one global overlay key across all wrappers.
    final toastHost = context
        .findAncestorWidgetOfExactType<ToastificationWrapper>();
    return toastHost == null ? ToastificationWrapper(child: app) : app;
  }
}
