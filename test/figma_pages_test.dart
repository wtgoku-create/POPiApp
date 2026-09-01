import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/assets/presentation/assets_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/features/profile/presentation/edit_profile_page.dart';
import 'package:popi_ai_app/features/profile/presentation/profile_page.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => page),
        GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
        GoRoute(
          path: '/profile/edit',
          builder: (_, __) => const EditProfilePage(),
        ),
      ],
    );
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp.router(
          theme: theme ?? AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('renders populated assets design', (tester) async {
    await pumpPage(tester, const AssetsPage());

    expect(find.byKey(const Key('assets-works-grid')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('assets-works-grid')),
        matching: find.byType(Image),
      ),
      findsWidgets,
    );
    expect(find.text('作品'), findsOneWidget);
  });

  testWidgets('renders empty assets design', (tester) async {
    await pumpPage(tester, const AssetsPage(showWorks: false));

    expect(find.text('暂无作品'), findsOneWidget);
    expect(find.text('去生成'), findsOneWidget);
  });

  testWidgets('renders profile design', (tester) async {
    await pumpPage(tester, const ProfilePage());

    expect(find.text('--'), findsWidgets);
    expect(find.text('UID:--'), findsOneWidget);
    expect(find.text('编辑资料'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.byKey(const Key('profile-points-icon')), findsOneWidget);

    final logoutMenu = find.byKey(const Key('profile-logout-menu'));
    await tester.ensureVisible(logoutMenu);
    await tester.pumpAndSettle();
    expect(logoutMenu, findsOneWidget);
  });

  testWidgets('renders profile settings with theme-aware icons in dark mode',
      (tester) async {
    await pumpPage(tester, const ProfilePage(), theme: AppTheme.dark);

    expect(find.text('语言'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.byType(ColorFiltered), findsWidgets);

    final preferencesSurface = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(SettingsGroup).last,
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = preferencesSurface.decoration! as BoxDecoration;
    expect(
      decoration.color,
      AppTheme.dark.colorScheme.surfaceContainerLow,
    );
  });

  testWidgets('expands language and theme selection trees', (tester) async {
    await pumpPage(tester, const ProfilePage());

    final languageMenu = find.byKey(const Key('language-settings-menu'));
    await tester.scrollUntilVisible(languageMenu, 300);
    await tester.tap(find.text('语言'));
    await tester.pumpAndSettle();
    expect(find.text('中文'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('跟随系统'), findsNWidgets(3));

    await tester.tap(find.text('主题'));
    await tester.pumpAndSettle();
    expect(find.text('浅色'), findsOneWidget);
    expect(find.text('深色'), findsOneWidget);
    expect(find.text('跟随系统'), findsNWidgets(4));
  });

  testWidgets('asks for confirmation before profile logout', (tester) async {
    await pumpPage(tester, const ProfilePage());

    final logoutMenu = find.byKey(const Key('profile-logout-menu'));
    await tester.ensureVisible(logoutMenu);
    await tester.pumpAndSettle();
    await tester.tap(logoutMenu);
    await tester.pumpAndSettle();

    expect(find.text('退出后需要重新登录才能继续使用'), findsOneWidget);
    expect(find.byKey(const Key('confirm-logout-button')), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('退出后需要重新登录才能继续使用'), findsNothing);
  });

  testWidgets('renders editable profile design', (tester) async {
    await pumpPage(tester, const EditProfilePage());

    expect(find.byKey(const Key('profile-name')), findsOneWidget);
    expect(find.text('昵称*'), findsOneWidget);
    expect(find.text('确认'), findsOneWidget);
  });
}
