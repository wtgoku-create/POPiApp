import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:popi_ai_app/features/ip_guide/data/ip_guide_repository.dart';
import 'package:popi_ai_app/shared/providers/ip_guide_provider.dart';
import 'support/ip_guide_fixtures.dart';

import 'package:popi_ai_app/app/router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/auth/presentation/login_page.dart';
import 'package:popi_ai_app/features/home/presentation/home_page.dart';
import 'package:popi_ai_app/features/ip_guide/presentation/ip_guide_page.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';
import 'package:popi_ai_app/features/role_guide/presentation/role_guide_page.dart';
import 'package:popi_ai_app/features/session/presentation/session_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';
import 'package:popi_ai_app/shared/providers/safe_area_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

import 'support/project_fixtures.dart';
import 'support/role_library_fixtures.dart';
import 'support/session_fixtures.dart';
import 'package:popi_ai_app/shared/providers/session_provider.dart';

void main() {
  Future<ProviderContainer> pumpHome(
    WidgetTester tester, {
    Size size = const Size(440, 956),
    ThemeData? theme,
    Locale locale = const Locale('zh'),
    User? user,
    double textScale = 1,
    double systemTopInset = 0,
    EdgeInsets? safeArea,
  }) async {
    safeArea ??= const EdgeInsets.only(top: 52, bottom: 34);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(top: systemTopInset);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    SharedPreferences.setMockInitialValues({});
    final guideStorage = MemoryGuideStorage(
      await SharedPreferences.getInstance(),
    );
    final container = ProviderContainer(
      overrides: [
        ipGuideRepositoryProvider.overrideWithValue(
          IpGuideRepository(
            guideStorage,
            FixtureIpGuideApi(),
            userId: user?.id,
          ),
        ),
        sessionRepositoryProvider.overrideWithValue(FixtureSessionRepository()),
        projectRepositoryProvider.overrideWithValue(FixtureProjectRepository()),
        dioProvider.overrideWithValue(roleLibraryDio()),
      ],
    );
    addTearDown(container.dispose);
    container.read(safeAreaInsetsProvider.notifier).update(safeArea);
    if (user != null) await container.read(userProvider.notifier).setUser(user);
    final router = container.read(routerProvider(false));
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              padding: safeArea,
              viewPadding: safeArea,
            ),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  for (final topInset in [0.0, 24.0, 62.0]) {
    testWidgets('home counts the status bar inset once: $topInset', (
      tester,
    ) async {
      await pumpHome(
        tester,
        safeArea: EdgeInsets.only(top: topInset, bottom: 34),
      );
      expect(tester.getSize(find.byType(AppBar)).height, 56);
      expect(tester.getTopLeft(find.byType(AppBar)).dy, topInset);
      expect(
        tester.getCenter(find.byKey(const Key('popi-open-navigation'))).dy,
        topInset + 28,
      );
      expect(
        tester.getTopLeft(find.byKey(const Key('home-banner-carousel'))).dy,
        topInset + 56 + 12,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'new home shows three creation entries and personal account data',
    (tester) async {
      final container = await pumpHome(
        tester,
        user: const User(id: '1', name: '逍遥的小柯子', email: '', allCoins: 200),
      );
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(PopiMessageComposer), findsNothing);
      expect(find.text('嗨，逍遥的小柯子～'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(find.text('做一个新IP账号'), findsOneWidget);
      expect(find.text('从创建角色开始'), findsOneWidget);
      expect(find.text('从选题/内容/脚本开始'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('home-banner-carousel'))).dy,
        120,
      );
      expect(
        tester.getSize(find.byKey(const Key('home-creation-panel'))).height,
        235,
      );

      await container
          .read(userProvider.notifier)
          .setUser(const User(id: '1', name: '新昵称', email: '', allCoins: 350));
      await tester.pump();
      expect(find.text('嗨，新昵称～'), findsOneWidget);
      expect(find.text('350'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'status bar inset is counted once and toolbar does not cover the banner',
    (tester) async {
      await pumpHome(tester, systemTopInset: 52);
      final menu = find.byKey(const Key('popi-open-navigation'));
      final banner = find.byKey(const Key('home-banner-carousel'));
      expect(tester.getSize(menu), const Size(40, 40));
      expect(tester.getTopLeft(menu).dy, 52 + 8);
      expect(tester.getTopLeft(banner).dy, 52 + 56 + 12);
      expect(
        tester.getBottomRight(menu).dy,
        lessThan(tester.getTopLeft(banner).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'creation entries open the IP guide or a session and return home',
    (tester) async {
      final container = await pumpHome(tester);
      final router = container.read(routerProvider(false));
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(Key('home-start-$i')));
        await tester.pumpAndSettle();
        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.byType(IpGuidePage), findsNothing);
        expect(find.byType(SessionPage), findsNothing);
        router.pop();
        await tester.pumpAndSettle();
        expect(find.byType(HomePage), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      await container
          .read(userProvider.notifier)
          .setUser(const User(id: '1', name: '用户', email: ''));
      await tester.pump();
      await tester.tap(find.byKey(const Key('home-start-0')));
      await tester.pumpAndSettle();
      expect(find.byType(IpGuidePage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'creation entries open the IP guide, role guide or a session and return home',
    (tester) async {
      final container = await pumpHome(
        tester,
        user: const User(id: '1', name: '用户', email: ''),
      );
      final prompts = ['做一个新IP账号', '从创建角色开始', '从选题/内容/脚本开始'];
      for (var i = 0; i < prompts.length; i++) {
        await tester.tap(find.byKey(Key('home-start-$i')));
        await tester.pumpAndSettle();
        if (i == 0) {
          expect(find.byType(IpGuidePage), findsOneWidget);
          expect(find.byType(SessionPage), findsNothing);
          expect(find.byKey(const Key('ip-guide-start')), findsOneWidget);
        } else if (i == 1) {
          expect(find.byType(RoleGuidePage), findsOneWidget);
          expect(find.byType(SessionPage), findsNothing);
        } else {
          final page = tester.widget<SessionPage>(find.byType(SessionPage));
          expect(page.initialPrompt, prompts[i]);
          expect(
            tester
                .widget<PopiMessageComposer>(find.byType(PopiMessageComposer))
                .controller
                .markdown,
            prompts[i],
          );
        }
        container.read(routerProvider(false)).pop();
        await tester.pumpAndSettle();
        expect(find.byType(HomePage), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('banner supports swiping and indicator navigation', (
    tester,
  ) async {
    await pumpHome(tester);
    expect(
      tester
          .widget<Semantics>(
            find
                .ancestor(
                  of: find.byKey(const Key('home-banner-dot-1')),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .selected,
      isTrue,
    );
    await tester.drag(
      find.byKey(const Key('home-banner-carousel')),
      const Offset(-284, 0),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Semantics>(
            find
                .ancestor(
                  of: find.byKey(const Key('home-banner-dot-2')),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .selected,
      isTrue,
    );
    await tester.tap(find.byKey(const Key('home-banner-dot-0')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Semantics>(
            find
                .ancestor(
                  of: find.byKey(const Key('home-banner-dot-0')),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .properties
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('home drawer starts a new mock conversation', (tester) async {
    final container = await pumpHome(
      tester,
      user: const User(id: '1', name: '用户', email: ''),
    );
    await tester.tap(find.byKey(const Key('popi-open-navigation')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('drawer-new-session')));
    await tester.pumpAndSettle();
    expect(find.byType(SessionPage), findsOneWidget);
    expect(tester.widget<AppBar>(find.byType(AppBar)).title, isNull);
    final sessionId = tester
        .widget<SessionPage>(find.byType(SessionPage))
        .sessionId;
    expect(sessionId, isNotEmpty);
    expect(
      container
          .read(sessionsProvider)
          .requireValue
          .any((session) => session.id == sessionId),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(1024, 768),
  ]) {
    testWidgets(
      'English dark home fits $size with large text and a long name',
      (tester) async {
        await pumpHome(
          tester,
          size: size,
          theme: AppTheme.dark,
          locale: const Locale('en'),
          textScale: 1.3,
          user: const User(
            id: '1',
            name: 'A very long creator display name',
            email: '',
          ),
        );
        expect(find.byType(HomePage), findsOneWidget);
        expect(find.byType(PopiMessageComposer), findsNothing);
        await tester.scrollUntilVisible(
          find.byKey(const Key('home-start-2')),
          200,
          scrollable: find
              .descendant(
                of: find.byKey(const Key('home-welcome-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(
          find.byKey(const Key('home-start-2')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
