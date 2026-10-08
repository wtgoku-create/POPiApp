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
import 'package:popi_ai_app/shared/widgets/popi_navigation_drawer.dart';

import 'support/project_fixtures.dart';

void main() {
  Future<GoRouter> pumpPage(
    WidgetTester tester, {
    Widget page = const IpAccountsPage.sample(),
    bool signedIn = true,
    Size size = const Size(440, 956),
    bool dark = false,
    Locale locale = const Locale('zh'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
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
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('Figma examples filter by recent usage and pause status', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.text('IP账号管理'), findsOneWidget);
    expect(find.text('Normal'), findsNWidgets(4));
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('后来才懂'), findsOneWidget);
    expect(find.text('水獭兜兜儿'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ip-accounts-filter-recent')));
    await tester.pumpAndSettle();
    expect(find.text('后来才懂'), findsOneWidget);
    expect(find.text('拜托了爱丽丝'), findsOneWidget);
    expect(find.text('叮叮睡醒了'), findsNothing);
    expect(find.text('Pause'), findsNothing);

    await tester.tap(find.byKey(const Key('ip-accounts-filter-paused')));
    await tester.pumpAndSettle();
    expect(find.text('益达'), findsOneWidget);
    expect(find.text('Normal'), findsNothing);

    await tester.tap(find.byKey(const Key('ip-accounts-filter-all')));
    await tester.pumpAndSettle();
    expect(find.text('Normal'), findsNWidgets(4));
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
        await tester.tap(find.byKey(const Key('ip-accounts-open-navigation')));
        await tester.pumpAndSettle();
        final material = tester.widget<Material>(
          find.descendant(
            of: find.byKey(const Key('drawer-nav-ip-accounts')),
            matching: find.byType(Material),
          ),
        );
        expect(material.color, AppColors.brand.withValues(alpha: .05));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      }
      expect(
        find.byKey(const Key('drawer-nav-ip-accounts')).hitTestable(),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('account page reopens drawer with selected entry', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('ip-accounts-open-navigation')));
    await tester.pumpAndSettle();
    final entry = find.byKey(const Key('drawer-nav-ip-accounts'));
    expect(entry.hitTestable(), findsOneWidget);
    final material = tester.widget<Material>(
      find.descendant(of: entry, matching: find.byType(Material)),
    );
    expect(material.color, AppColors.brand.withValues(alpha: .05));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty filters and account opening use supplied data', (
    tester,
  ) async {
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
    await tester.tap(find.byKey(const Key('ip-accounts-filter-recent')));
    await tester.pumpAndSettle();
    expect(find.text('暂无最近常用账号'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ip-accounts-filter-paused')));
    await tester.pumpAndSettle();
    expect(find.text('暂无停滞账号'), findsOneWidget);
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
