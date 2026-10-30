import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:toastification/toastification.dart';

import '../features/demo/presentation/demo_home_page.dart';
import '../features/v2_home/presentation/v2_guest_page.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/providers/settings_provider.dart';
import '../shared/providers/user_provider.dart';
import '../shared/providers/workspace_repository_provider.dart';
import '../shared/widgets/app_keyboard_dismiss.dart';
import '../shared/widgets/app_skeleton.dart';
import '../shared/widgets/app_toast.dart';
import '../shared/widgets/safe_area_store_sync.dart';
import 'router.dart';
import 'theme.dart';

/// Web uses the complete conversation workspace with shared account routes.
class BusinessWorkspaceApp extends ConsumerStatefulWidget {
  const BusinessWorkspaceApp({super.key});

  @override
  ConsumerState<BusinessWorkspaceApp> createState() =>
      _BusinessWorkspaceAppState();
}

class _BusinessWorkspaceAppState extends ConsumerState<BusinessWorkspaceApp> {
  late final _router = createAppRouter(
    homeBuilder: (_, _) => const _DemoEntry(),
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
        locale: ref.watch(localeProvider) ?? const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (_, child) =>
            AppKeyboardDismiss(child: SafeAreaStoreSync(child: child!)),
      ),
    );
  }
}

class _DemoEntry extends ConsumerWidget {
  const _DemoEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(userBootstrapProvider);
    final userId = ref.watch(userProvider.select((user) => user?.id));
    if (bootstrap.isLoading && userId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (userId == null) return const V2GuestPage();
    final repository = ref.watch(workspaceRepositoryProvider);
    ref.listen(workspaceRepositoryProvider, (_, next) {
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
    if (repository.asData?.value case final value?) {
      return DemoHomePage(key: ValueKey(userId), repository: value);
    }
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(workspaceRepositoryProvider);
          try {
            await ref.read(workspaceRepositoryProvider.future);
          } catch (_) {
            // The provider listener reports this failure once.
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
}
