import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:popi_ai_app/app/router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/teaching/domain/teaching.dart';
import 'package:popi_ai_app/features/teaching/presentation/teaching_document_page.dart';
import 'package:popi_ai_app/features/teaching/presentation/teaching_page.dart';
import 'package:popi_ai_app/features/notifications/presentation/notifications_page.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/home/presentation/home_page.dart';
import 'package:popi_ai_app/features/assets/presentation/assets_page.dart';
import 'package:popi_ai_app/features/profile/presentation/profile_page.dart';
import 'package:popi_ai_app/features/profile/presentation/edit_profile_page.dart';
import 'package:popi_ai_app/features/session/presentation/session_page.dart';
import 'package:popi_ai_app/features/session/domain/conversation_session.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';
import 'package:popi_ai_app/shared/providers/ip_account_provider.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';
import 'package:popi_ai_app/shared/providers/session_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/widgets/app_svg_icon.dart';
import 'support/session_fixtures.dart';
import 'support/ip_account_fixtures.dart';
import 'support/role_library_fixtures.dart';

void main() {
  Future<ProviderContainer> pumpDrawer(
    WidgetTester tester, {
    Size size = const Size(440, 956),
    ThemeData? theme,
    Locale locale = const Locale('zh'),
    bool signedIn = true,
    FixtureSessionRepository? repository,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        sessionRepositoryProvider.overrideWithValue(
          repository ?? FixtureSessionRepository(),
        ),
        ipAccountRepositoryProvider.overrideWithValue(
          FixtureIpAccountRepository(),
        ),
        dioProvider.overrideWithValue(roleLibraryDio()),
        projectRepositoryProvider.overrideWith(
          (ref) => throw StateError('Sidebar must not use project APIs'),
        ),
      ],
    );
    addTearDown(container.dispose);
    if (signedIn) {
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: '1', name: '当前用户', email: ''));
    }
    final router = container.read(routerProvider(false));
    addTearDown(router.dispose);
    router.go('/session?prompt=旧草稿');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('popi-open-navigation')));
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> openMenu(WidgetTester tester, String id) async {
    await tester.longPress(find.byKey(Key('drawer-session-$id')));
    await tester.pumpAndSettle();
  }

  for (final count in [0, 1, 40]) {
    testWidgets('pull refreshes drawer history with $count sessions', (
      tester,
    ) async {
      final repository = _RefreshingDrawerRepository(count);
      final container = await pumpDrawer(tester, repository: repository);
      final requestsBefore = repository.requests;
      repository.pending = Completer<List<ConversationSession>>();
      await tester.drag(
        find.byKey(const Key('drawer-session-list')),
        const Offset(0, 240),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.requests, requestsBefore + 1);
      if (count > 0) {
        expect(find.text('History 0'), findsOneWidget);
      }
      expect(find.byKey(const Key('drawer-sessions-skeleton')), findsNothing);
      final updated = ConversationSession(
        id: 'refreshed',
        title: 'Refreshed history',
        updatedAt: DateTime(2026),
      );
      repository.pending!.complete([updated]);
      await tester.pumpAndSettle();
      expect(find.text('Refreshed history'), findsOneWidget);
      expect(container.read(sessionsProvider).requireValue.single, updated);
      expect(tester.takeException(), isNull);
    });
  }

  for (final size in [
    const Size(320, 400),
    const Size(390, 844),
    const Size(1280, 900),
  ]) {
    testWidgets('drawer menu and history share scrolling at $size', (
      tester,
    ) async {
      final repository = _RefreshingDrawerRepository(80);
      await pumpDrawer(tester, size: size, repository: repository);
      expect(repository.requestedPages, [(1, 20)]);
      final drawer = find.byKey(const Key('popi-navigation-drawer'));
      final scrollable = find.descendant(
        of: drawer,
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsOneWidget);
      final menu = find.byKey(const Key('drawer-nav-home'));
      final first = find.byKey(const Key('drawer-session-history-0'));
      final menuTop = tester.getTopLeft(menu).dy;
      final position = tester.state<ScrollableState>(scrollable).position;
      final initialOffset = position.pixels;
      final newProject = find.byKey(const Key('drawer-new-session'));
      final newProjectBounds = tester.getRect(newProject);
      final footer = tester.getRect(
        find.byKey(const Key('drawer-profile-button')),
      );
      await tester.drag(menu, const Offset(0, -180));
      await tester.pumpAndSettle();
      final menuShift = tester.getTopLeft(menu).dy - menuTop;
      expect(menuShift, lessThan(-100));
      expect(menuShift, closeTo(initialOffset - position.pixels, 1));
      expect(first.hitTestable(), findsOneWidget);
      expect(tester.getRect(newProject), newProjectBounds);
      expect(newProject.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const Key('drawer-profile-button'))),
        footer,
      );
      final last = find.byKey(const Key('drawer-session-history-79'));
      await tester.scrollUntilVisible(last, 400, scrollable: scrollable);
      await tester.pumpAndSettle();
      expect(last.hitTestable(), findsOneWidget);
      expect(repository.requestedPages, [(1, 20), (2, 20), (3, 20), (4, 20)]);
      expect(first, findsNothing);
      expect(tester.getRect(newProject), newProjectBounds);
      expect(newProject.hitTestable(), findsOneWidget);
      expect(
        find
            .byWidgetPredicate((widget) {
              final key = widget.key;
              return key is ValueKey<String> &&
                  key.value.startsWith('drawer-session-history-');
            })
            .evaluate()
            .length,
        lessThan(40),
      );
      await tester.scrollUntilVisible(menu, -400, scrollable: scrollable);
      await tester.pumpAndSettle();
      expect(menu.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('loading another drawer page preserves visible history', (
    tester,
  ) async {
    final repository = _RefreshingDrawerRepository(40);
    final container = await pumpDrawer(tester, repository: repository);
    repository.pending = Completer<List<ConversationSession>>();
    await tester.drag(
      find.byKey(const Key('drawer-session-list')),
      const Offset(0, -1200),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.requestedPages, [(1, 20), (2, 20)]);
    expect(container.read(sessionsProvider).requireValue, hasLength(20));
    expect(
      find.byKey(const Key('drawer-sessions-more-skeleton')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('drawer-sessions-skeleton')), findsNothing);
    expect(find.byKey(const Key('drawer-session-history-19')), findsOneWidget);
    repository.pending!.complete(repository.items);
    await tester.pumpAndSettle();
    expect(container.read(sessionsProvider).requireValue, hasLength(40));
    expect(
      find.byKey(const Key('drawer-sessions-more-skeleton')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed drawer refresh keeps history and allows another pull', (
    tester,
  ) async {
    final repository = _RefreshingDrawerRepository(1);
    await pumpDrawer(tester, repository: repository);
    repository.failNext = true;
    await tester.drag(
      find.byKey(const Key('drawer-session-list')),
      const Offset(0, 240),
    );
    await tester.pumpAndSettle();
    expect(find.text('History 0'), findsOneWidget);
    expect(
      find.text(
        lookupAppLocalizations(const Locale('zh')).chatHistoryLoadFailed,
      ),
      findsOneWidget,
    );
    final requestsBefore = repository.requests;
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('drawer-session-list')),
      const Offset(0, 240),
    );
    await tester.pumpAndSettle();
    expect(repository.requests, requestsBefore + 1);
    expect(find.text('History 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sidebar destinations retain home beneath the selected page', (
    tester,
  ) async {
    final container = await pumpDrawer(tester);
    final router = container.read(routerProvider(false));
    tester.state<ScaffoldState>(find.byType(Scaffold).first).closeDrawer();
    await tester.pumpAndSettle();
    router.go('/');
    await tester.pumpAndSettle();
    router.push('/session?prompt=draft');
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);

    for (final (entry, location) in [
      ('drawer-nav-ip-accounts', '/ip-accounts'),
      ('drawer-nav-role', '/assets?section=roles'),
      ('drawer-nav-assets', '/assets'),
      ('drawer-profile-button', '/profile'),
      ('drawer-session-mock-2', '/session?sessionId=mock-2'),
      ('drawer-nav-home', '/'),
    ]) {
      await tester.tap(find.byKey(const Key('popi-open-navigation')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key(entry)));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), location);
      expect(router.canPop(), location != '/', reason: entry);
      expect(find.byKey(const Key('popi-open-navigation')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('system back returns through detail and destination to home', (
    tester,
  ) async {
    final container = await pumpDrawer(tester);
    final router = container.read(routerProvider(false));
    await tester.tap(find.byKey(const Key('drawer-profile-button')));
    await tester.pumpAndSettle();
    router.push('/profile/edit');
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(router.state.uri.path, '/profile');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
    expect(router.state.uri.path, '/');
    expect(router.canPop(), isFalse);
    expect(await router.routerDelegate.popRoute(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back dismisses the drawer before leaving the page', (
    tester,
  ) async {
    final container = await pumpDrawer(tester);
    final router = container.read(routerProvider(false));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/session');
    expect(
      find.byKey(const Key('drawer-nav-home')).hitTestable(),
      findsNothing,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/');
    expect(find.byType(HomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'notification button opens the inbox and preserves the current page',
    (tester) async {
      final container = await pumpDrawer(tester);
      final router = container.read(routerProvider(false));
      await tester.tap(find.byKey(const Key('drawer-notification-button')));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsOneWidget);
      expect(router.state.uri.path, '/notifications');
      expect(router.canPop(), isTrue);
      await tester.tap(find.byKey(const Key('notification-back')));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/session');
      expect(router.state.uri.queryParameters['prompt'], '旧草稿');
      expect(find.byKey(const Key('popi-open-navigation')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sidebar sections update a reused asset page and its selection', (
    tester,
  ) async {
    final container = await pumpDrawer(tester);
    await tester.tap(find.byKey(const Key('drawer-nav-role')));
    await tester.pumpAndSettle();
    final assetsState = tester.state(find.byType(AssetsPage));
    expect(find.text('官方角色'), findsOneWidget);
    await tester.tap(find.byKey(const Key('popi-open-navigation')));
    await tester.pumpAndSettle();
    final role = find.byKey(const Key('drawer-nav-role'));
    final works = find.byKey(const Key('drawer-nav-assets'));
    Color? itemColor(Finder item) => tester
        .widget<Material>(
          find.descendant(of: item, matching: find.byType(Material)).first,
        )
        .color;
    expect(itemColor(role), isNot(AppColors.surface));
    expect(itemColor(works), AppColors.surface);
    await tester.tap(works);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(AssetsPage)), same(assetsState));
    expect(find.text('图片'), findsOneWidget);
    expect(find.text('官方角色'), findsNothing);
    expect(container.read(routerProvider(false)).canPop(), isTrue);
    await tester.tap(find.byKey(const Key('popi-open-navigation')));
    await tester.pumpAndSettle();
    expect(itemColor(role), AppColors.surface);
    expect(itemColor(works), isNot(AppColors.surface));
    await tester.tap(role);
    await tester.pumpAndSettle();
    expect(find.text('官方角色'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sidebar conversation selection clears the old pushed stack', (
    tester,
  ) async {
    final container = await pumpDrawer(tester);
    final router = container.read(routerProvider(false));
    tester.state<ScaffoldState>(find.byType(Scaffold).first).closeDrawer();
    await tester.pumpAndSettle();
    router.go('/');
    await tester.pumpAndSettle();
    router.push('/session?prompt=draft');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('popi-open-navigation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drawer-session-mock-2')));
    await tester.pumpAndSettle();
    expect(router.state.uri.queryParameters['sessionId'], 'mock-2');
    expect(find.byType(SessionPage), findsOneWidget);
    expect(router.canPop(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile editing keeps its back button beneath a sidebar root', (
    tester,
  ) async {
    final container = await pumpDrawer(tester);
    final router = container.read(routerProvider(false));
    await tester.tap(find.byKey(const Key('drawer-profile-button')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(router.canPop(), isTrue);
    router.push('/profile/edit');
    await tester.pumpAndSettle();
    expect(find.byType(EditProfilePage), findsOneWidget);
    expect(router.canPop(), isTrue);
    await tester.tap(find.byKey(const Key('profile-back')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(router.canPop(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('flat mock history has no projects or legacy requests', (
    tester,
  ) async {
    final container = await pumpDrawer(tester);
    expect(find.text('会话'), findsOneWidget);
    expect(find.text('校园野餐vlog'), findsOneWidget);
    expect(find.text('项目(5)'), findsNothing);
    expect(find.byKey(const Key('drawer-projects-menu')), findsNothing);
    expect(container.exists(projectRepositoryProvider), isFalse);
    final footer = tester.getRect(
      find.byKey(const Key('drawer-profile-button')),
    );
    await tester.drag(
      find.byKey(const Key('drawer-session-list')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(const Key('drawer-profile-button'))),
      footer,
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(390, 844), const Size(1280, 900)]) {
    testWidgets('long drawer history builds on demand and pins at $size', (
      tester,
    ) async {
      final repository = FixtureSessionRepository();
      for (var index = 0; index < 180; index++) {
        await repository.create('1', 'History $index');
      }
      final container = await pumpDrawer(
        tester,
        size: size,
        repository: repository,
      );
      final first = find.byKey(const Key('drawer-session-mock-1'));
      final last = find.byKey(const Key('drawer-session-mock-8'));
      final rows = find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            RegExp(r'^drawer-session-mock-(new-)?\d+$').hasMatch(key.value);
      });
      expect(container.read(sessionsProvider).requireValue, hasLength(20));
      expect(first, findsOneWidget);
      expect(last, findsNothing);
      expect(rows.evaluate().length, lessThan(30));
      final footer = tester.getRect(
        find.byKey(const Key('drawer-profile-button')),
      );
      final scrollable = find.descendant(
        of: find.byKey(const Key('drawer-session-list')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(last, 400, scrollable: scrollable);
      await tester.pumpAndSettle();
      expect(first, findsNothing);
      expect(last.hitTestable(), findsOneWidget);
      expect(rows.evaluate().length, lessThan(30));
      expect(
        tester.getRect(find.byKey(const Key('drawer-profile-button'))),
        footer,
      );
      await openMenu(tester, 'mock-8');
      await tester.tap(find.text('置顶会话'));
      await tester.pumpAndSettle();
      expect(container.read(sessionsProvider).requireValue.first.id, 'mock-8');
      await tester.scrollUntilVisible(last, -400, scrollable: scrollable);
      await tester.pumpAndSettle();
      expect(last.hitTestable(), findsOneWidget);
      expect(tester.getRect(last).top, lessThan(tester.getRect(first).top));
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(
        container
            .read(routerProvider(false))
            .routeInformationProvider
            .value
            .uri
            .queryParameters['sessionId'],
        'mock-8',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('opens a conversation and creates a clean new one', (
    tester,
  ) async {
    final container = await pumpDrawer(tester);
    await tester.tap(find.byKey(const Key('drawer-session-mock-2')));
    await tester.pumpAndSettle();
    expect(tester.widget<AppBar>(find.byType(AppBar)).title, isNull);
    expect(
      container
          .read(routerProvider(false))
          .routeInformationProvider
          .value
          .uri
          .queryParameters['sessionId'],
      'mock-2',
    );
    await tester.tap(find.byKey(const Key('popi-open-navigation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drawer-new-session')));
    await tester.pumpAndSettle();
    expect(container.read(sessionsProvider).requireValue.length, 9);
    expect(tester.widget<AppBar>(find.byType(AppBar)).title, isNull);
    expect(
      container
          .read(sessionsProvider)
          .requireValue
          .any((session) => session.title == '新项目'),
      isTrue,
    );
    expect(
      tester
          .widget<PopiMessageComposer>(find.byType(PopiMessageComposer))
          .controller
          .markdown,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'folder icons render in conversation rows and long-press previews',
    (tester) async {
      await pumpDrawer(tester);
      final avatar = find.byKey(const Key('drawer-session-avatar-mock-1'));
      expect(tester.getSize(avatar), const Size(30, 30));
      final icon = tester.widget<AppSvgIcon>(avatar);
      expect(icon.assetName, 'home_drawer_project');
      expect(icon.color, AppTheme.light.colorScheme.onSurface);
      expect(
        tester.getSize(find.byKey(const Key('drawer-session-mock-1'))).height,
        40,
      );
      for (final id in ['mock-2', 'mock-3', 'mock-4']) {
        expect(
          tester
              .widget<AppSvgIcon>(find.byKey(Key('drawer-session-avatar-$id')))
              .assetName,
          'home_drawer_project',
        );
      }
      await openMenu(tester, 'mock-1');
      final preview = find.byKey(const Key('app-context-menu-preview'));
      expect(find.descendant(of: preview, matching: avatar), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('drawer-new-session')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('popi-open-navigation')));
      await tester.pumpAndSettle();
      final fallback = find.byKey(
        const Key('drawer-session-avatar-mock-new-1'),
      );
      expect(tester.getSize(fallback), const Size(30, 30));
      expect(
        tester.widget<AppSvgIcon>(fallback).assetName,
        'home_drawer_project',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pin, rename and delete stay updated after reopening', (
    tester,
  ) async {
    final container = await pumpDrawer(tester);
    await openMenu(tester, 'mock-2');
    await tester.tap(find.text('置顶会话'));
    await tester.pumpAndSettle();
    expect(container.read(sessionsProvider).requireValue.first.id, 'mock-2');
    await openMenu(tester, 'mock-2');
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('session-rename-input')),
      '新标题',
    );
    await tester.tap(find.byKey(const Key('session-rename-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('新标题'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    tester.state<ScaffoldState>(find.byType(Scaffold).first).closeDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('popi-open-navigation')));
    await tester.pumpAndSettle();
    expect(find.text('新标题'), findsOneWidget);
    await openMenu(tester, 'mock-2');
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('新标题'), findsOneWidget);
    await openMenu(tester, 'mock-2');
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-delete-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drawer-session-mock-2')), findsNothing);
    expect(container.read(sessionsProvider).requireValue.length, 7);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final signedIn in [false, true]) {
    testWidgets(
      'teaching center opens and returns home, signed in: $signedIn',
      (tester) async {
        final container = await pumpDrawer(tester, signedIn: signedIn);
        await tester.tap(find.byKey(const Key('drawer-nav-teaching')));
        await tester.pumpAndSettle();
        final router = container.read(routerProvider(false));
        expect(router.state.uri.path, '/teaching');
        expect(router.canPop(), isTrue);
        expect(find.byType(TeachingPage), findsOneWidget);
        expect(find.text('教学中心'), findsOneWidget);
        router.push(
          '/teaching/document/17',
          extra: const TeachingCourse(id: 17, name: '课程详情'),
        );
        await tester.pumpAndSettle();
        final detail = tester.widget<TeachingDocumentPage>(
          find.byType(TeachingDocumentPage),
        );
        expect(detail.course?.name, '课程详情');
        expect(detail.courseId, 17);
        await tester.tap(find.byTooltip('返回'));
        await tester.pumpAndSettle();
        expect(find.byType(TeachingPage), findsOneWidget);
        await tester.tap(find.byKey(const Key('popi-open-navigation')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('drawer-nav-home')));
        await tester.pumpAndSettle();
        expect(router.state.uri.path, '/');
        expect(find.byType(HomePage), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('home returns to the root without highlighting: $signedIn', (
      tester,
    ) async {
      final container = await pumpDrawer(tester, signedIn: signedIn);
      final home = find.byKey(const Key('drawer-nav-home'));
      await tester.tap(home);
      await tester.pumpAndSettle();
      final router = container.read(routerProvider(false));
      expect(find.byType(HomePage), findsOneWidget);
      expect(router.canPop(), isFalse);
      await tester.tap(find.byKey(const Key('popi-open-navigation')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Material>(
              find.descendant(of: home, matching: find.byType(Material)).first,
            )
            .color,
        AppColors.surface,
      );
      await tester.tap(home);
      await tester.pumpAndSettle();
      expect(router.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  for (final dark in [false, true]) {
    for (final language in ['zh', 'en']) {
      for (final height in [568.0, 500.0, 400.0]) {
        testWidgets(
          'compact $language drawer at $height supports dark mode: $dark',
          (tester) async {
            await pumpDrawer(
              tester,
              size: Size(320, height),
              theme: dark ? AppTheme.dark : AppTheme.light,
              locale: Locale(language),
            );
            final l10n = lookupAppLocalizations(Locale(language));
            final entries = [
              ('drawer-nav-home', l10n.home),
              ('drawer-nav-teaching', l10n.teachingCenter),
              ('drawer-nav-role', l10n.roles),
              ('drawer-nav-ip-accounts', l10n.ipProjects),
              ('drawer-nav-assets', l10n.assets),
            ];
            var previousBottom = 0.0;
            for (final (key, label) in entries) {
              final item = find.byKey(Key(key));
              final bounds = tester.getRect(item);
              expect(bounds.top, greaterThanOrEqualTo(previousBottom));
              expect(bounds.height, 50);
              expect(
                find.descendant(of: item, matching: find.text(label)),
                findsOneWidget,
              );
              previousBottom = bounds.bottom;
            }
            expect(
              tester
                  .widget<AppSvgIcon>(
                    find.descendant(
                      of: find.byKey(const Key('drawer-nav-teaching')),
                      matching: find.byType(AppSvgIcon),
                    ),
                  )
                  .assetName,
              'home_drawer_nav_teaching',
            );
            final footer = tester.getRect(
              find.byKey(const Key('drawer-profile-button')),
            );
            final bodyScroll = find.byKey(const Key('drawer-body-scroll'));
            final bodyViewport = bodyScroll.evaluate().isEmpty
                ? find.byKey(const Key('drawer-session-list'))
                : bodyScroll;
            expect(tester.getRect(bodyViewport).bottom, lessThan(footer.top));
            expect(footer.bottom, lessThanOrEqualTo(height));
            if (bodyScroll.evaluate().isNotEmpty) {
              await tester.drag(bodyScroll, const Offset(0, -400));
              await tester.pumpAndSettle();
            }
            await tester.drag(
              find.byKey(const Key('drawer-session-list')),
              const Offset(0, -600),
            );
            await tester.pumpAndSettle();
            expect(
              find.byKey(const Key('drawer-session-mock-8')).hitTestable(),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

class _RefreshingDrawerRepository extends FixtureSessionRepository {
  _RefreshingDrawerRepository(int count)
    : items = List.generate(
        count,
        (index) => ConversationSession(
          id: 'history-$index',
          title: 'History $index',
          updatedAt: DateTime(2026).subtract(Duration(seconds: index)),
        ),
      );

  final List<ConversationSession> items;
  Completer<List<ConversationSession>>? pending;
  bool failNext = false;
  int requests = 0;
  final requestedPages = <(int, int)>[];

  @override
  Future<ConversationSessionPage> list(
    String userId, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    requests++;
    requestedPages.add((page, pageSize));
    if (failNext) {
      failNext = false;
      throw StateError('offline');
    }
    final all = await (pending?.future ?? Future.value(items));
    return ConversationSessionPage(
      items: all.skip((page - 1) * pageSize).take(pageSize).toList(),
      page: page,
      pageCount: (all.length / pageSize).ceil().clamp(1, 10000),
    );
  }
}
