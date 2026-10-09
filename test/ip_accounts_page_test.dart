import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/ip_accounts/domain/ip_account.dart';
import 'package:popi_ai_app/features/ip_accounts/presentation/ip_accounts_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/widgets/app_skeleton.dart';
import 'package:popi_ai_app/shared/widgets/popi_navigation_drawer.dart';

import 'support/project_fixtures.dart';
import 'support/session_fixtures.dart';
import 'package:popi_ai_app/shared/providers/session_provider.dart';

void main() {
  Future<GoRouter> pumpPage(
    WidgetTester tester, {
    Widget page = const IpAccountsPage.sample(),
    bool signedIn = true,
    Size size = const Size(440, 956),
    bool dark = false,
    Locale locale = const Locale('zh'),
    bool settle = true,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(FixtureSessionRepository()),
        projectRepositoryProvider.overrideWithValue(FixtureProjectRepository()),
      ],
    );
    addTearDown(container.dispose);
    if (signedIn) {
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: 'test-user', name: 'Test', email: ''));
    }
    final router = GoRouter(
      initialLocation: '/ip-accounts',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              Scaffold(drawer: const PopiNavigationDrawer(), appBar: AppBar()),
        ),
        GoRoute(path: '/ip-accounts', builder: (_, _) => page),
        GoRoute(
          path: '/login',
          builder: (_, _) => const Scaffold(body: Text('Sign in')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: dark ? AppTheme.dark : AppTheme.light,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          routerConfig: router,
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 250));
    }
    return router;
  }

  testWidgets('account list shows all accounts without category controls', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.text('IP账号管理'), findsOneWidget);
    expect(find.text('Normal'), findsNWidgets(4));
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('后来才懂'), findsOneWidget);
    expect(find.text('水獭兜兜儿'), findsOneWidget);

    expect(find.text('益达'), findsOneWidget);
    expect(find.text('全部'), findsNothing);
    expect(find.text('最近常用'), findsNothing);
    expect(find.text('停滞'), findsNothing);
    expect(find.byKey(const Key('ip-accounts-open-navigation')), findsNothing);
    expect(find.byType(DrawerButton), findsNothing);
    expect(
      tester.getCenter(find.byKey(const Key('ip-accounts-back'))).dx,
      lessThan(tester.getCenter(find.text('IP账号管理')).dx),
    );
    expect(tester.takeException(), isNull);
  });

  for (final signedIn in [true, false]) {
    testWidgets('drawer opens accounts or login: signed in $signedIn', (
      tester,
    ) async {
      final router = await pumpPage(tester, signedIn: signedIn);
      router.go('/');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DrawerButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('drawer-nav-ip-accounts')));
      await tester.pumpAndSettle();
      expect(
        signedIn ? find.byType(IpAccountsPage) : find.text('Sign in'),
        findsOneWidget,
      );
      if (signedIn) {
        await tester.tap(find.byKey(const Key('ip-accounts-back')));
        await tester.pumpAndSettle();
        expect(find.byType(IpAccountsPage), findsNothing);
        expect(router.routeInformationProvider.value.uri.path, '/');
      }
      expect(
        find.byKey(const Key('drawer-nav-ip-accounts')).hitTestable(),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'back falls back to home when opened without navigation history',
    (tester) async {
      final router = await pumpPage(tester);
      expect(router.canPop(), isFalse);
      await tester.tap(find.byKey(const Key('ip-accounts-back')));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(find.byType(IpAccountsPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('account opening uses supplied data', (tester) async {
    const account = IpAccount(
      id: 'custom',
      title: 'Custom account',
      description: 'Custom description',
    );
    IpAccount? opened;
    await pumpPage(
      tester,
      page: IpAccountsPage(
        accounts: const [account],
        onOpenAccount: (account) => opened = account,
      ),
    );
    await tester.tap(find.text('Custom account'));
    expect(opened, same(account));
  });

  testWidgets('empty loaded list shows an empty state', (tester) async {
    await pumpPage(tester, page: const IpAccountsPage());
    expect(find.text('暂无IP账号'), findsOneWidget);
    expect(find.byType(AppSkeleton), findsNothing);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'loading placeholders pulse and give way to accounts: dark $dark',
      (tester) async {
        final loading = ValueNotifier(true);
        addTearDown(loading.dispose);
        await pumpPage(
          tester,
          page: ValueListenableBuilder<bool>(
            valueListenable: loading,
            builder: (_, isLoading, _) => isLoading
                ? const IpAccountsPage(isLoading: true)
                : const IpAccountsPage.sample(),
          ),
          dark: dark,
          settle: false,
        );
        expect(find.byKey(const Key('ip-accounts-skeleton')), findsOneWidget);
        expect(find.text('暂无IP账号'), findsNothing);
        final row = find.byKey(const Key('ip-account-skeleton-0'));
        final bounds = tester.getRect(row);
        expect(bounds.size, const Size(400, 90));
        final fade = find.descendant(
          of: find.byType(AppSkeleton),
          matching: find.byType(FadeTransition),
        );
        final opacity = tester.widget<FadeTransition>(fade).opacity.value;
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          tester.widget<FadeTransition>(fade).opacity.value,
          isNot(opacity),
        );
        expect(tester.getRect(row), bounds);
        loading.value = false;
        await tester.pumpAndSettle();
        expect(find.byType(AppSkeleton), findsNothing);
        expect(
          tester.getRect(find.byKey(const Key('ip-account-example-houlai'))),
          bounds,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'loading placeholders respect reduced motion on compact screens',
    (tester) async {
      await pumpPage(
        tester,
        page: const IpAccountsPage(isLoading: true),
        size: const Size(320, 568),
        reduceMotion: true,
      );
      final fade = find.descendant(
        of: find.byType(AppSkeleton),
        matching: find.byType(FadeTransition),
      );
      expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('refresh retains existing account rows', (tester) async {
    await pumpPage(tester, page: const IpAccountsPage.sample(isLoading: true));
    expect(find.byType(AppSkeleton), findsNothing);
    expect(find.text('后来才懂'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    for (final locale in [const Locale('zh'), const Locale('en')]) {
      testWidgets('compact $locale page supports dark mode: $dark', (
        tester,
      ) async {
        await pumpPage(
          tester,
          size: const Size(320, 568),
          dark: dark,
          locale: locale,
        );
        await tester.scrollUntilVisible(
          find.byKey(const Key('ip-account-example-doudou')),
          150,
          scrollable: find.descendant(
            of: find.byKey(const Key('ip-accounts-list')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('水獭兜兜儿').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
