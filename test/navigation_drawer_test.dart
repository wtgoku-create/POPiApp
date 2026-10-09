import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/home/presentation/home_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';
import 'package:popi_ai_app/shared/providers/session_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/widgets/app_svg_icon.dart';
import 'support/session_fixtures.dart';

void main() {
  Future<ProviderContainer> pumpDrawer(
    WidgetTester tester, {
    Size size = const Size(440, 956),
    ThemeData? theme,
    Locale locale = const Locale('zh'),
    bool signedIn = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        sessionRepositoryProvider.overrideWithValue(FixtureSessionRepository()),
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
          .any((session) => session.title == '新会话'),
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

  testWidgets('conversation avatars render in rows and long-press previews', (
    tester,
  ) async {
    await pumpDrawer(tester);
    final avatar = find.byKey(const Key('drawer-session-avatar-mock-1'));
    expect(tester.getSize(avatar), const Size(30, 30));
    final icon = tester.widget<AppSvgIcon>(avatar);
    expect(icon.assetName, 'home_drawer_session_pink');
    expect(icon.color, isNull);
    expect(
      tester.getSize(find.byKey(const Key('drawer-session-mock-1'))).height,
      40,
    );
    for (final (id, name) in [
      ('mock-2', 'home_drawer_session_blue'),
      ('mock-3', 'home_drawer_session_peach'),
      ('mock-4', 'home_drawer_session_neutral'),
    ]) {
      expect(
        tester
            .widget<AppSvgIcon>(find.byKey(Key('drawer-session-avatar-$id')))
            .assetName,
        name,
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
    final fallback = find.byKey(const Key('drawer-session-avatar-mock-new-1'));
    expect(tester.getSize(fallback), const Size(30, 30));
    expect(
      tester.widget<AppSvgIcon>(fallback).assetName,
      'home_drawer_session_neutral',
    );
    expect(tester.takeException(), isNull);
  });

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
      testWidgets('compact $language drawer supports dark mode: $dark', (
        tester,
      ) async {
        await pumpDrawer(
          tester,
          size: const Size(320, 568),
          theme: dark ? AppTheme.dark : AppTheme.light,
          locale: Locale(language),
        );
        final list = tester.getRect(
          find.byKey(const Key('drawer-session-list')),
        );
        final footer = tester.getRect(
          find.byKey(const Key('drawer-profile-button')),
        );
        expect(list.bottom, lessThan(footer.top));
        expect(footer.bottom, lessThanOrEqualTo(568));
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
      });
    }
  }
}
