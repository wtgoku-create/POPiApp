import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/assets/presentation/assets_page.dart';
import 'package:popi_ai_app/features/profile/presentation/edit_profile_page.dart';
import 'package:popi_ai_app/features/profile/presentation/profile_page.dart';
import 'package:popi_ai_app/features/settings/presentation/settings_page.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, __) => page),
        GoRoute(
          path: '/settings',
          builder: (_, __) => const SettingsPage(),
        ),
        GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
        GoRoute(
          path: '/profile/edit',
          builder: (_, __) => const EditProfilePage(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
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

    expect(find.text('啵啵'), findsOneWidget);
    expect(find.text('UID:09821'), findsOneWidget);
    expect(find.text('编辑资料'), findsOneWidget);
  });

  testWidgets('renders settings design', (tester) async {
    await pumpPage(tester, const SettingsPage());

    expect(find.text('普通用户'), findsOneWidget);
    expect(find.text('AI水印设置'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
  });

  testWidgets('renders editable profile design', (tester) async {
    await pumpPage(tester, const EditProfilePage());

    expect(find.byKey(const Key('profile-name')), findsOneWidget);
    expect(find.text('昵称*'), findsOneWidget);
    expect(find.text('确认'), findsOneWidget);
  });
}
