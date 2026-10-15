import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/ip_accounts/domain/ip_account.dart';
import 'package:popi_ai_app/features/ip_accounts/presentation/ip_accounts_live_page.dart';
import 'package:popi_ai_app/features/projects/domain/project.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/ip_account_provider.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';
import 'package:popi_ai_app/shared/providers/session_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:toastification/toastification.dart';

import 'support/ip_account_fixtures.dart';
import 'support/project_fixtures.dart';
import 'support/session_fixtures.dart';

class _Accounts extends FixtureIpAccountRepository {
  List<IpAccount> accounts = const [
    IpAccount(id: '1', title: 'Account 1', description: 'First account'),
    IpAccount(id: '2', title: 'Account 2', description: 'Second account'),
  ];
  final archived = <String>[];
  Completer<void>? pending;
  CancelToken? archiveToken;
  bool fail = false;
  final pages = <(int, int)>[];

  @override
  Future<ListPage<IpAccount>> list({
    String status = 'active',
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    statuses.add(status);
    pages.add((page, pageSize));
    return fixturePage(accounts, page: page, pageSize: pageSize);
  }

  @override
  Future<void> archive(String id, {CancelToken? cancelToken}) async {
    archived.add(id);
    archiveToken = cancelToken;
    if (pending != null) await pending!.future;
    if (fail) throw StateError('Offline');
    if (cancelToken?.isCancelled == true) return;
    accounts = accounts.where((item) => item.id != id).toList();
  }
}

class _Projects extends FixtureProjectRepository {
  int loads = 0;

  @override
  Future<ListPage<Project>> listProjects({
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    loads++;
    return super.listProjects(
      page: page,
      pageSize: pageSize,
      cancelToken: cancelToken,
    );
  }
}

void main() {
  late _Accounts accounts;
  late _Projects projects;
  late ProviderContainer container;
  late GoRouter router;

  setUp(() {
    accounts = _Accounts();
    projects = _Projects();
    toastification.dismissAll(delayForAnimation: false);
  });
  tearDown(() => toastification.dismissAll(delayForAnimation: false));

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    bool dark = false,
    Locale locale = const Locale('zh'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container = ProviderContainer(
      overrides: [
        ipAccountRepositoryProvider.overrideWithValue(accounts),
        projectRepositoryProvider.overrideWithValue(projects),
        sessionRepositoryProvider.overrideWithValue(FixtureSessionRepository()),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: 'user', name: 'User', email: ''));
    router = GoRouter(
      initialLocation: '/ip-accounts',
      routes: [
        GoRoute(
          path: '/ip-accounts',
          builder: (_, _) => const IpAccountsLivePage(),
        ),
        GoRoute(
          path: '/ip-accounts/:id',
          builder: (_, _) => const Scaffold(body: Text('Account details')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: dark ? AppTheme.dark : AppTheme.light,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder action(String id) =>
      find.byKey(Key('ip-account-delete-$id')).hitTestable();
  Future<void> reveal(WidgetTester tester, String id) async {
    await tester.drag(
      find.byKey(Key('ip-account-slide-$id')),
      const Offset(-180, 0),
    );
    await tester.pumpAndSettle();
  }

  Future<void> askToDelete(WidgetTester tester, String id) async {
    await reveal(tester, id);
    await tester.tap(action(id));
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('confirm-delete-ip-account')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'account history requests twenty rows and loads subsequent pages on scroll',
    (tester) async {
      accounts.accounts = [
        for (var index = 0; index < 45; index++)
          IpAccount(
            id: '$index',
            title: 'Account $index',
            description: 'Account',
          ),
      ];
      await pump(tester);
      expect(accounts.pages, [(1, 20)]);
      expect(find.byKey(const ValueKey('ip-account-44')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('ip-account-44')),
        600,
        scrollable: find.descendant(
          of: find.byKey(const Key('ip-accounts-list')),
          matching: find.byType(Scrollable),
        ),
        maxScrolls: 50,
      );
      await tester.pumpAndSettle();
      expect(accounts.pages, [(1, 20), (2, 20), (3, 20)]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancel preserves the row; confirmation archives and refreshes sidebar',
    (tester) async {
      await pump(tester);
      final subscription = container.listen(projectsProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(projectsProvider.future);
      expect(projects.loads, 1);
      expect(action('1'), findsNothing);
      await askToDelete(tester, '1');
      expect(find.text('确认删除该IP账号？'), findsOneWidget);
      expect(find.text('删除后，账号将被归档，不再显示在账号列表中。作品、会话和资料会保留。'), findsOneWidget);
      expect(accounts.archived, isEmpty);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('Account 1'), findsOneWidget);
      expect(accounts.archived, isEmpty);
      await askToDelete(tester, '1');
      await confirm(tester);
      expect(accounts.archived, ['1']);
      expect(find.text('Account 1'), findsNothing);
      expect(find.text('Account 2'), findsOneWidget);
      expect(projects.loads, 2);
      expect(router.routeInformationProvider.value.uri.path, '/ip-accounts');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed deletion keeps data and allows the same delete action again',
    (tester) async {
      accounts.fail = true;
      await pump(tester);
      await askToDelete(tester, '1');
      await confirm(tester);
      expect(accounts.archived, ['1']);
      expect(find.text('Account 1'), findsOneWidget);
      expect(find.text('Account 2'), findsOneWidget);
      expect(find.text('网络请求失败，请稍后重试'), findsOneWidget);
      toastification.dismissAll(delayForAnimation: false);
      accounts.fail = false;
      await askToDelete(tester, '1');
      await confirm(tester);
      expect(accounts.archived, ['1', '1']);
      expect(find.text('Account 1'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending deletion keeps stable dimensions and blocks duplicate actions',
    (tester) async {
      accounts.pending = Completer<void>();
      await pump(tester);
      final row = find.byKey(const Key('ip-account-1'));
      final before = tester.getSize(row);
      await askToDelete(tester, '1');
      await tester.tap(find.byKey(const Key('confirm-delete-ip-account')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.descendant(
          of: row,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(row), before);
      expect(
        tester
            .widget<Slidable>(find.byKey(const Key('ip-account-slide-2')))
            .enabled,
        isFalse,
      );
      await tester.tap(find.text('Account 2'));
      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      await refresh.onRefresh();
      expect(accounts.statuses, ['active']);
      expect(accounts.archived, ['1']);
      expect(router.routeInformationProvider.value.uri.path, '/ip-accounts');
      accounts.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Account 1'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('switching users during confirmation cancels deletion', (
    tester,
  ) async {
    await pump(tester);
    await askToDelete(tester, '1');
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: 'new-user', name: 'New', email: ''));
    await tester.pumpAndSettle();
    await confirm(tester);
    expect(accounts.archived, isEmpty);
    expect(find.text('Account 1'), findsOneWidget);
    expect(find.text('网络请求失败，请稍后重试'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'switching users cancels an in-flight request and suppresses stale failures',
    (tester) async {
      accounts.pending = Completer<void>();
      await pump(tester);
      await askToDelete(tester, '1');
      await tester.tap(find.byKey(const Key('confirm-delete-ip-account')));
      await tester.pump(const Duration(milliseconds: 300));
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: 'new-user', name: 'New', email: ''));
      await tester.pumpAndSettle();
      expect(accounts.archiveToken!.isCancelled, isTrue);
      accounts.pending!.completeError(StateError('Obsolete failure'));
      await tester.pumpAndSettle();
      expect(find.text('Account 1'), findsOneWidget);
      expect(find.text('网络请求失败，请稍后重试'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('deleting the last account shows the empty state', (
    tester,
  ) async {
    accounts.accounts = [accounts.accounts.first];
    await pump(tester);
    await askToDelete(tester, '1');
    await confirm(tester);
    expect(find.text('暂无IP账号'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(1280, 900)]) {
    for (final dark in [false, true]) {
      testWidgets(
        'swipe actions close the previous row and fit $size dark=$dark',
        (tester) async {
          await pump(
            tester,
            size: size,
            dark: dark,
            locale: const Locale('en'),
          );
          await reveal(tester, '1');
          expect(action('1'), findsOneWidget);
          await reveal(tester, '2');
          expect(action('1'), findsNothing);
          expect(action('2'), findsOneWidget);
          await tester.tap(action('2'));
          await tester.pumpAndSettle();
          expect(find.text('Delete this IP account?'), findsOneWidget);
          await confirm(tester);
          expect(find.text('Account 2'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
