import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';

import 'theme.dart';
import 'router.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/providers/storage_provider.dart';
import '../shared/providers/settings_provider.dart';
import '../shared/providers/user_provider.dart';
import '../shared/widgets/app_keyboard_dismiss.dart';
import '../shared/widgets/safe_area_store_sync.dart';
import '../features/v2_shared/data/v2_repository.dart';
import '../features/v2_home/presentation/v2_account_entry.dart';

/// Mock creation flows share the existing account pages and local preferences.
class V2App extends ConsumerStatefulWidget {
  const V2App({this.locale = const Locale('zh'), super.key});
  final Locale locale;
  @override
  ConsumerState<V2App> createState() => _V2AppState();
}

class _V2AppState extends ConsumerState<V2App> {
  late final _repository = V2Repository(ref.read(preferencesStorageProvider))
    ..restore();
  late final _router = createAppRouter(
    homeBuilder: (_, _) => const SizedBox.shrink(),
    shellBuilder: (_, state, child) => Consumer(
      builder: (context, ref, _) {
        final bootstrap = ref.watch(userBootstrapProvider);
        final userId = ref.watch(userProvider.select((user) => user?.id));
        if (bootstrap.isLoading && userId == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return V2AccountEntry(
          key: ValueKey(userId),
          repository: _repository,
          userId: userId,
          routeActive: state.uri.path != '/',
          routedContent: child,
        );
      },
    ),
  );
  @override
  void dispose() {
    _router.dispose();
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(userBootstrapProvider);
    return ToastificationWrapper(
      child: MaterialApp.router(
        routerConfig: _router,
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
        builder: (_, child) =>
            AppKeyboardDismiss(child: SafeAreaStoreSync(child: child!)),
      ),
    );
  }
}
