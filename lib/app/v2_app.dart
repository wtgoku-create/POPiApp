import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:toastification/toastification.dart';

import 'theme.dart';
import 'router.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/providers/settings_provider.dart';
import '../shared/providers/user_provider.dart';
import '../shared/providers/v2_repository_provider.dart';
import '../shared/widgets/app_toast.dart';
import '../shared/widgets/app_skeleton.dart';
import '../shared/widgets/app_keyboard_dismiss.dart';
import '../shared/widgets/safe_area_store_sync.dart';
import '../features/v2_home/presentation/v2_account_entry.dart';
import '../features/v2_home/presentation/v2_guest_page.dart';

/// The new interface shares account pages and uses the POPiBot service.
class V2App extends ConsumerStatefulWidget {
  const V2App({this.locale = const Locale('zh'), super.key});
  final Locale locale;
  @override
  ConsumerState<V2App> createState() => _V2AppState();
}

class _V2AppState extends ConsumerState<V2App> {
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
        if (userId == null) {
          return const V2GuestPage();
        }
        final repository = ref.watch(v2RepositoryProvider);
        ref.listen(v2RepositoryProvider, (_, next) {
          if (next.hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                AppToast.error(
                  context,
                  AppLocalizations.of(context)!.v2NetworkError,
                );
              }
            });
          }
        });
        if (repository.isLoading ||
            repository.hasError ||
            repository.value == null) {
          if (state.uri.path != '/') return child;
          return Scaffold(
            appBar: AppBar(
              title: const Text('POPi'),
              actions: [
                IconButton(
                  tooltip: AppLocalizations.of(context)!.demoProfile,
                  onPressed: () => context.push('/profile'),
                  icon: const Icon(Icons.person_outline),
                ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(v2RepositoryProvider);
                try {
                  await ref.read(v2RepositoryProvider.future);
                } catch (_) {
                  // The provider listener reports bootstrap failures once.
                }
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    child: repository.isLoading
                        ? AppSkeletonList(
                            label: AppLocalizations.of(
                              context,
                            )!.loadingProjectSessions,
                          )
                        : const SizedBox.expand(),
                  ),
                ],
              ),
            ),
          );
        }
        return V2AccountEntry(
          key: ValueKey(userId),
          repository: repository.value!,
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
