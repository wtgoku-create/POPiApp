import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/assets/presentation/assets_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/features/profile/presentation/edit_profile_page.dart';
import 'package:popi_ai_app/features/profile/presentation/points_details_page.dart';
import 'package:popi_ai_app/features/profile/presentation/profile_page.dart';
import 'package:popi_ai_app/features/profile/domain/point_package.dart';
import 'package:popi_ai_app/features/profile/domain/user_points_log.dart';
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
        GoRoute(
          path: '/profile/points',
          builder: (_, __) => const PointsDetailsPage(
            refreshOnOpen: false,
            loadPointsLogOnOpen: false,
          ),
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

  testWidgets('renders creation history assets design', (tester) async {
    await pumpPage(tester, const AssetsPage());

    expect(find.text('角色库'), findsOneWidget);
    expect(find.text('资产库'), findsOneWidget);
    expect(find.text('创作历史'), findsOneWidget);
    expect(find.byKey(const Key('assets-history-filters')), findsOneWidget);
    expect(find.text('暂无历史'), findsOneWidget);
    expect(find.byKey(const Key('assets-go-generate')), findsOneWidget);
  });

  testWidgets('switches creation history filter', (tester) async {
    await pumpPage(tester, const AssetsPage());

    await tester.tap(find.text('Vlog'));
    await tester.pumpAndSettle();

    final filter = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const Key('assets-history-filter-2')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = filter.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.surfaceTint);
  });

  testWidgets('renders populated asset center and selection controls',
      (tester) async {
    await pumpPage(tester, const AssetsPage.sample());

    expect(find.byKey(const Key('assets-history-list')), findsOneWidget);
    expect(find.text('继续任务'), findsOneWidget);

    await tester.tap(find.byKey(const Key('assets-section-资产库')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assets-works-grid')), findsOneWidget);
    expect(find.text('2026.09.01'), findsOneWidget);

    await tester.tap(find.byKey(const Key('assets-toggle-selection')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assets-selection-actions')), findsOneWidget);

    await tester.tap(find.byKey(const Key('assets-work-0')));
    await tester.pumpAndSettle();
    expect(find.text('下载'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    await tester.tap(find.byKey(const Key('assets-section-角色库')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assets-roles-grid')), findsOneWidget);
    expect(find.text('AI真人'), findsOneWidget);
    expect(find.text('二次元'), findsOneWidget);
    expect(find.text('夏禾'), findsOneWidget);
    expect(find.text('金发王子'), findsOneWidget);
    expect(find.text('莓莓'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('assets-role-1'))),
      const Size(400, 100),
    );

    await tester.tap(find.text('AI真人'));
    await tester.pumpAndSettle();
    expect(find.text('夏禾'), findsNothing);
    expect(find.text('金发王子'), findsOneWidget);
    expect(find.text('莓莓'), findsNothing);
  });

  testWidgets('renders works and role empty states', (tester) async {
    await pumpPage(
      tester,
      const AssetsPage(initialSection: AssetLibrarySection.works),
    );
    expect(find.text('暂无作品'), findsOneWidget);

    await pumpPage(
      tester,
      const AssetsPage(initialSection: AssetLibrarySection.roles),
    );
    expect(find.text('暂无角色'), findsOneWidget);
    expect(find.text('创建角色为你的视频增添人物资产'), findsOneWidget);
  });

  testWidgets('asset library back button returns to the previous page',
      (tester) async {
    await pumpPage(
      tester,
      const Scaffold(body: Center(child: Text('上一页'))),
    );

    final navigator = Navigator.of(tester.element(find.text('上一页')));
    final routeClosed = navigator.push(
      MaterialPageRoute<void>(builder: (_) => const AssetsPage.sample()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('assets-navigation-back')));
    await tester.pumpAndSettle();
    await routeClosed;

    expect(find.text('上一页'), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('renders profile design', (tester) async {
    await pumpPage(tester, const ProfilePage());

    expect(find.text('--'), findsWidgets);
    expect(find.text('UID:--'), findsOneWidget);
    expect(find.byKey(const Key('profile-uid-copy')), findsOneWidget);
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
    expect(find.byKey(const Key('edit-profile-uid-copy')), findsOneWidget);
    expect(find.text('昵称*'), findsOneWidget);
    expect(find.text('确认'), findsOneWidget);
  });

  testWidgets('renders points details design', (tester) async {
    await pumpPage(
      tester,
      const PointsDetailsPage(
        refreshOnOpen: false,
        loadPointsLogOnOpen: false,
      ),
    );

    expect(find.text('积分详情'), findsNWidgets(2));
    expect(find.byKey(const Key('points-summary-card')), findsOneWidget);
    expect(find.byKey(const Key('points-details-icon')), findsOneWidget);
    expect(find.text('1750'), findsOneWidget);
    expect(find.text('充值积分包'), findsOneWidget);
    expect(find.text('暂无积分明细'), findsOneWidget);
    expect(find.byKey(const Key('points-transaction-card')), findsOneWidget);

    expect(
      tester.getSize(find.byKey(const Key('points-summary-card'))),
      const Size(400, 203),
    );
    final pointsIcon = tester.widget<Image>(
      find.byKey(const Key('points-details-icon')),
    );
    expect(pointsIcon.width, 20);
    expect(pointsIcon.height, closeTo(13.24, 0.01));
  });

  testWidgets('opens and selects a recharge points package', (tester) async {
    await pumpPage(
      tester,
      PointsDetailsPage(
        refreshOnOpen: false,
        loadPointsLogOnOpen: false,
        pointPackageLoader: () async => _pointPackages,
      ),
    );

    await tester.tap(find.byKey(const Key('points-recharge-entry')));
    await tester.pumpAndSettle();

    final sheet = find.byKey(const Key('points-recharge-sheet'));
    expect(sheet, findsOneWidget);
    expect(tester.getSize(sheet).height, 663);
    expect(find.byKey(const Key('points-package-600')), findsOneWidget);
    expect(find.byKey(const Key('points-package-20000')), findsOneWidget);
    expect(find.byKey(const Key('points-package-selected')), findsOneWidget);
    expect(find.byType(ImageFiltered), findsOneWidget);

    await tester.tap(find.byKey(const Key('points-package-1000')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('points-package-1000')),
        matching: find.byKey(const Key('points-package-selected')),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('points-recharge-confirm')));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
  });

  testWidgets('loads the next points log page near the bottom', (tester) async {
    final requests = <(int, int)>[];

    Future<UserPointsLogPage> loadPage(int page, int pageSize) async {
      requests.add((page, pageSize));
      final start = (page - 1) * pageSize + 1;
      final itemCount = page == 1 ? pageSize : 1;
      return UserPointsLogPage(
        page: page,
        pageSize: pageSize,
        pageCount: 2,
        total: 21,
        items: List.generate(
          itemCount,
          (index) => _pointsLogEntry(start + index),
        ),
      );
    }

    await pumpPage(
      tester,
      PointsDetailsPage(
        refreshOnOpen: false,
        pointsLogPageLoader: loadPage,
      ),
    );

    expect(requests, [(1, 20)]);
    expect(find.byKey(const Key('points-log-1')), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('points-details-scroll')),
      const Offset(0, -1400),
    );
    await tester.pumpAndSettle();

    expect(requests, [(1, 20), (2, 20)]);
    expect(find.byKey(const Key('points-log-21')), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('points-details-scroll')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(requests, [(1, 20), (2, 20)]);
  });

  testWidgets('separates points cards from the page in dark mode',
      (tester) async {
    await pumpPage(
      tester,
      const PointsDetailsPage(
        refreshOnOpen: false,
        loadPointsLogOnOpen: false,
      ),
      theme: AppTheme.dark,
    );

    for (final key in const [
      Key('points-summary-card'),
      Key('points-transaction-card'),
    ]) {
      final card = tester.widget<Container>(find.byKey(key));
      final decoration = card.decoration! as BoxDecoration;
      expect(decoration.color, AppTheme.dark.colorScheme.surfaceContainerHigh);
      expect(decoration.color, isNot(AppTheme.dark.scaffoldBackgroundColor));
      expect(decoration.boxShadow, hasLength(2));
    }
  });

  testWidgets('layers the recharge sheet and packages in dark mode',
      (tester) async {
    await pumpPage(
      tester,
      PointsDetailsPage(
        refreshOnOpen: false,
        loadPointsLogOnOpen: false,
        pointPackageLoader: () async => _pointPackages,
      ),
      theme: AppTheme.dark,
    );

    await tester.tap(find.byKey(const Key('points-recharge-entry')));
    await tester.pumpAndSettle();

    final sheet = tester.widget<Container>(
      find.byKey(const Key('points-recharge-sheet')),
    );
    final sheetDecoration = sheet.decoration! as BoxDecoration;
    expect(sheetDecoration.color, AppTheme.dark.colorScheme.surfaceContainer);
    expect(sheetDecoration.boxShadow, hasLength(2));

    final unselectedPackage = tester.widget<DecoratedBox>(
      find.byKey(const Key('points-package-1000')),
    );
    final packageDecoration = unselectedPackage.decoration as BoxDecoration;
    expect(
      packageDecoration.color,
      AppTheme.dark.colorScheme.surfaceContainerHigh,
    );
    expect(packageDecoration.border, isNotNull);
  });

  testWidgets('opens points details from profile and returns', (tester) async {
    await pumpPage(tester, const ProfilePage());

    await tester.tap(find.byKey(const Key('profile-points-details')));
    await tester.pumpAndSettle();
    expect(find.byType(PointsDetailsPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('points-details-back')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
  });

  testWidgets('opens recharge sheet directly from profile', (tester) async {
    await pumpPage(
      tester,
      ProfilePage(pointPackageLoader: () async => _pointPackages),
    );

    await tester.tap(find.byKey(const Key('profile-points-recharge')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('points-recharge-sheet')), findsOneWidget);
    expect(find.byKey(const Key('points-package-600')), findsOneWidget);
    expect(find.byType(PointsDetailsPage), findsNothing);
  });
}

UserPointsLogEntry _pointsLogEntry(int id) {
  return UserPointsLogEntry(
    id: id,
    userId: 0,
    userCode: '',
    userName: '',
    points: id.isEven ? 10 : -1,
    changeType: 2,
    sourceType: 'post_refund',
    sourceId: 'source-$id',
    content: '积分记录 $id',
    beforePoints: 134,
    afterPoints: 133,
    status: 1,
    createTime: DateTime.parse('2026-09-02T16:05:48+08:00'),
  );
}

final _pointPackages = List.generate(
  6,
  (index) => PointPackage(
    id: index + 1,
    name: '${30 * (index + 1)}包',
    currency: 'CNY',
    priceAmount: [30, 50, 100, 300, 500, 1000][index].toDouble(),
    pointsAmount: [600, 1000, 2000, 6000, 10000, 20000][index],
    bonusPoints: 0,
    enabled: true,
    sortOrder: index + 1,
    createdAt: null,
    updatedAt: null,
  ),
);
