import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/assets/presentation/assets_page.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/home/presentation/home_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/features/profile/presentation/edit_profile_page.dart';
import 'package:popi_ai_app/features/profile/presentation/membership_page.dart';
import 'package:popi_ai_app/features/profile/presentation/points_details_page.dart';
import 'package:popi_ai_app/features/profile/presentation/profile_page.dart';
import 'package:popi_ai_app/features/profile/domain/point_package.dart';
import 'package:popi_ai_app/features/profile/domain/product_plan.dart';
import 'package:popi_ai_app/features/profile/domain/user_points_log.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/widgets/legal_document_links.dart';

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
        GoRoute(
          path: '/profile/membership',
          builder: (_, __) => MembershipPage(
            initialPlans: _membershipPlans,
            loadPlansOnOpen: false,
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

  testWidgets('renders and switches membership plans', (tester) async {
    await pumpPage(
      tester,
      MembershipPage(
        initialPlans: _membershipPlans,
        loadPlansOnOpen: false,
      ),
    );

    expect(find.text('积分详情'), findsNothing);
    expect(find.text('Starter 灵感初启'), findsNWidgets(2));
    expect(find.text('1750'), findsOneWidget);
    expect(find.text('Starter 1750 专属权益'), findsOneWidget);
    expect(find.text('starter-小小尝试'), findsOneWidget);
    expect(
      find.byKey(const Key('membership-feature-title-icon')),
      findsOneWidget,
    );
    final featureTitle = tester.widget<Text>(
      find.byKey(const Key('membership-feature-title')),
    );
    expect(featureTitle.style?.fontSize, 16);
    expect(
      find.ancestor(
        of: find.byKey(const Key('membership-feature-title')),
        matching: find.byType(ListView),
      ),
      findsOneWidget,
    );
    expect(find.text('立即购买'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('membership-plan-card'))).height,
      closeTo(620, .01),
    );
    expect(
      tester.getSize(find.byKey(const Key('membership-open-button'))),
      const Size(400, 46),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('membership-open-button'))).dy -
          tester
              .getBottomLeft(find.byKey(const Key('membership-plan-card')))
              .dy,
      closeTo(12, .5),
    );
    final starterMarkdown = tester.widget<MarkdownBody>(
      find.byKey(const Key('membership-description-markdown')),
    );
    expect(starterMarkdown.data, contains('- [x] **Starter 1750 专属权益**'));
    expect(starterMarkdown.data, contains('---\n\n### 创作能力'));

    tester.view.physicalSize = const Size(440, 800);
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('membership-plan-card'))).height,
      closeTo(548, .01),
    );
    tester.view.physicalSize = const Size(440, 956);
    await tester.pumpAndSettle();

    LinearGradient membershipGradient() {
      final background = tester.widget<DecoratedBox>(
        find.byKey(const Key('membership-background')),
      );
      return (background.decoration as BoxDecoration).gradient!
          as LinearGradient;
    }

    expect(
      membershipGradient().colors,
      const [Color(0xFFF1EEFA), Color(0xFFF8F8F8)],
    );

    await tester.tap(find.byKey(const Key('membership-plan-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('Plus-小有成就'), findsOneWidget);
    expect(
      membershipGradient().colors,
      const [Color(0xFFF9E9FF), Color(0xFFF8F8F8)],
    );

    await tester.tap(find.byKey(const Key('membership-plan-tab-2')));
    await tester.pumpAndSettle();
    expect(
      membershipGradient().colors,
      const [Color(0xFFD9CDFF), Color(0xFFF8F8F8)],
    );

    await tester.drag(
      find.byKey(const Key('membership-plan-tabs')),
      const Offset(-900, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('membership-plan-tab-3')));
    await tester.pumpAndSettle();
    expect(find.text('50000'), findsOneWidget);
    expect(
      membershipGradient().colors,
      const [
        Color(0xFFFFD8B2),
        Color(0xFFE2D9FF),
        Color(0xFFF8F8F8),
      ],
    );
    expect(membershipGradient().stops, const [0, .2073, 1]);
    final markdown = tester.widget<MarkdownBody>(
      find.byKey(const Key('membership-description-markdown')),
    );
    expect(markdown.data, contains('Max 50000 专属权益'));
  });

  testWidgets('reverses plans and groups both Plus point options',
      (tester) async {
    await pumpPage(
      tester,
      MembershipPage(
        initialPlans: _membershipPlans,
        loadPlansOnOpen: false,
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const Key('membership-plan-tab-0')),
        matching: find.text('Starter 灵感初启'),
      ),
      findsOneWidget,
    );
    expect(find.text('Plus 创作进阶'), findsOneWidget);

    await tester.tap(find.byKey(const Key('membership-plan-tab-1')));
    await tester.pumpAndSettle();

    expect(find.text('Plus 创作进阶'), findsNWidgets(2));
    expect(find.byKey(const Key('membership-points-option-0')), findsOneWidget);
    expect(find.byKey(const Key('membership-points-option-1')), findsOneWidget);
    expect(find.text('5500'), findsOneWidget);
    expect(find.text('14400'), findsOneWidget);
    expect(find.text('包含：5500/套餐积分+0/赠送积分'), findsOneWidget);
    expect(
      tester
          .widget<MarkdownBody>(
            find.byKey(const Key('membership-description-markdown')),
          )
          .data,
      contains('Plus 5500 专属权益'),
    );

    await tester.tap(find.byKey(const Key('membership-points-option-1')));
    await tester.pumpAndSettle();
    expect(find.text('包含：14400/套餐积分+0/赠送积分'), findsOneWidget);
    expect(find.text('包含：5500/套餐积分+0/赠送积分'), findsNothing);
    expect(
      tester
          .widget<MarkdownBody>(
            find.byKey(const Key('membership-description-markdown')),
          )
          .data,
      contains('Plus 14400 专属权益'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps spacing between the membership card and bottom button',
      (tester) async {
    await pumpPage(
      tester,
      MembershipPage(
        initialPlans: _membershipPlans,
        loadPlansOnOpen: false,
      ),
    );

    final cardBottom =
        tester.getBottomLeft(find.byKey(const Key('membership-plan-card'))).dy;
    final buttonTop =
        tester.getTopLeft(find.byKey(const Key('membership-open-button'))).dy;
    expect(buttonTop - cardBottom, closeTo(12, .5));
  });

  testWidgets('aligns the selected membership tab to the content margin',
      (tester) async {
    await pumpPage(
      tester,
      MembershipPage(
        initialPlans: _membershipPlans,
        loadPlansOnOpen: false,
      ),
    );

    expect(
      tester.getTopLeft(find.byKey(const Key('membership-plan-tab-0'))).dx,
      closeTo(20, .5),
    );

    await tester.drag(
      find.byKey(const Key('membership-plan-tabs')),
      const Offset(-900, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('membership-plan-tab-3')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const Key('membership-plan-tab-3'))).dx,
      closeTo(20, .5),
    );

    await tester.drag(
      find.byKey(const Key('membership-plan-tabs')),
      const Offset(900, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('membership-plan-tab-0')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const Key('membership-plan-tab-0'))).dx,
      closeTo(20, .5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the membership page with dark theme surfaces',
      (tester) async {
    await pumpPage(
      tester,
      MembershipPage(
        initialPlans: _membershipPlans,
        loadPlansOnOpen: false,
      ),
      theme: AppTheme.dark,
    );

    final scheme = AppTheme.dark.colorScheme;
    final background = tester.widget<DecoratedBox>(
      find.byKey(const Key('membership-background')),
    );
    final backgroundDecoration = background.decoration as BoxDecoration;
    final gradient = backgroundDecoration.gradient! as LinearGradient;
    expect(gradient.colors, [const Color(0xFF241D38), scheme.surface]);

    final card = tester.widget<Container>(
      find.byKey(const Key('membership-plan-card')),
    );
    final cardDecoration = card.decoration! as BoxDecoration;
    expect(cardDecoration.color, scheme.surfaceContainerHigh);
    expect(cardDecoration.border, isNotNull);

    final benefits = tester.widget<Container>(
      find.byKey(const Key('membership-benefits')),
    );
    final benefitsDecoration = benefits.decoration! as BoxDecoration;
    expect(benefitsDecoration.color, scheme.surfaceContainerHighest);

    final selectedTab = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const Key('membership-plan-tab-0')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final selectedDecoration = selectedTab.decoration! as BoxDecoration;
    expect(selectedDecoration.color, scheme.surfaceContainerHighest);
    expect(selectedDecoration.border, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens membership from profile', (tester) async {
    await pumpPage(tester, const ProfilePage());

    await tester.tap(find.byKey(const Key('profile-upgrade-membership')));
    await tester.pumpAndSettle();

    expect(find.byType(MembershipPage), findsOneWidget);
    expect(find.text('立即购买'), findsOneWidget);
  });

  testWidgets('opens membership from the home app bar', (tester) async {
    await pumpPage(tester, const HomePage());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomePage)),
    );
    await container.read(userProvider.notifier).setUser(
          const User(
            id: '10561',
            name: '当前用户',
            email: 'user@popi.art',
            allCoins: 200,
          ),
        );
    await tester.pump();

    await tester.tap(find.byKey(const Key('home-membership-entry')));
    await tester.pumpAndSettle();

    expect(find.byType(MembershipPage), findsOneWidget);
    expect(find.text('立即购买'), findsOneWidget);
  });

  testWidgets('loads membership plan values from the repository',
      (tester) async {
    final product = ProductPlan.fromJson({
      'id': 3,
      'type': 1,
      'title': 'Pro 旗舰能力',
      'level': 3,
      'coins': 32000,
      'bonusPointsAmount': 2000,
      'price': 8900,
      'original_price_amount': 119,
      'custom_info': {
        'buttonText': '立即购买',
        'discount_info': '限时7折',
        'new_user': true,
        'point_amount': '每100积分≈￥3.68元',
      },
    });

    await pumpPage(
      tester,
      MembershipPage(planLoader: () async => [product]),
    );

    expect(find.text('34000'), findsOneWidget);
    expect(find.text('8900'), findsNothing);
    expect(find.text('¥89'), findsNothing);
    expect(find.text('89'), findsOneWidget);
    expect(find.text('限时7折'), findsOneWidget);
    expect(find.text('立即购买'), findsOneWidget);
  });

  testWidgets('uses zero bonus points returned by the membership API',
      (tester) async {
    final product = ProductPlan.fromJson({
      'id': 2,
      'type': 1,
      'title': 'Starter 灵感初启',
      'level': 1,
      'coins': 1750,
      'bonusPointsAmount': 0,
      'price': 7900,
      'original_price_amount': 99,
      'custom_info': {
        'buttonText': '立即购买',
        'discount_info': '限时活动 8折',
        'new_user': true,
        'point_amount': '每100积分≈￥4.5元',
      },
    });

    await pumpPage(
      tester,
      MembershipPage(planLoader: () async => [product]),
    );

    expect(find.text('Starter 灵感初启'), findsNWidgets(2));
    expect(find.text('79'), findsOneWidget);
    expect(find.text('¥99'), findsOneWidget);
    expect(find.text('1750'), findsOneWidget);
    expect(find.text('限时活动 8折'), findsOneWidget);
    expect(find.text('每100积分≈￥4.5元'), findsOneWidget);
    expect(find.text('立即购买'), findsOneWidget);
    final discountBadgeSize =
        tester.getSize(find.byKey(const Key('membership-discount-badge')));
    expect(discountBadgeSize.height, 36);
    expect(discountBadgeSize.width, greaterThan(97));
    expect(find.text('包含：1750/套餐积分+0/赠送积分'), findsOneWidget);
  });

  testWidgets('does not render local membership plan defaults', (tester) async {
    await pumpPage(
      tester,
      const MembershipPage(loadPlansOnOpen: false),
    );

    expect(find.byKey(const Key('membership-plans-empty')), findsOneWidget);
    expect(find.text('暂无可用会员方案'), findsOneWidget);
    expect(find.byKey(const Key('membership-plan-card')), findsNothing);
    expect(find.byKey(const Key('membership-plan-tabs')), findsNothing);
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
      const Size(400, 176),
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
    expect(
      find.byKey(const Key('recharge-legal-document-links')),
      findsOneWidget,
    );
    final legalLinks = tester.widget<LegalDocumentLinks>(
      find.byKey(const Key('recharge-legal-document-links')),
    );
    expect(legalLinks.style.fontSize, 12);
    expect(legalLinks.style.height, 1.5);
    expect(tester.getSize(sheet).height, 600);
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

final _membershipPlans = [
  _membershipPlan(
    id: 5,
    level: 4,
    title: 'Max 作品研修',
    price: 12900,
    originalPrice: 169,
    coins: 50000,
    bonusPoints: 0,
    discount: '限时6折',
    pointAmount: '每100积分≈￥2.58元',
    concurrentTasks: 8,
    storageMb: 10000,
  ),
  _membershipPlan(
    id: 4,
    level: 3,
    title: 'Pro 旗舰能力',
    price: 7900,
    originalPrice: 99,
    coins: 28000,
    bonusPoints: 0,
    discount: '限时6折',
    pointAmount: '每100积分≈￥4.51元',
    concurrentTasks: 4,
    storageMb: 5000,
  ),
  _membershipPlan(
    id: 31,
    level: 2,
    title: 'Plus 创作进阶',
    price: 7900,
    originalPrice: 99,
    coins: 14400,
    bonusPoints: 0,
    discount: '限时6折',
    pointAmount: '每100积分≈￥4.51元',
    concurrentTasks: 4,
    storageMb: 5000,
  ),
  _membershipPlan(
    id: 3,
    level: 2,
    title: 'Plus 创作进阶',
    price: 7900,
    originalPrice: 99,
    coins: 5500,
    bonusPoints: 0,
    discount: '限时6折',
    pointAmount: '每100积分≈￥4.51元',
    concurrentTasks: 4,
    storageMb: 5000,
  ),
  _membershipPlan(
    id: 2,
    level: 1,
    title: 'Starter 灵感初启',
    price: 7900,
    originalPrice: 99,
    coins: 1750,
    bonusPoints: 0,
    discount: '限时活动 8折',
    pointAmount: '每100积分≈￥4.5元',
    concurrentTasks: 2,
    storageMb: 1000,
  ),
];

ProductPlan _membershipPlan({
  required int id,
  required int level,
  required String title,
  required int price,
  required int originalPrice,
  required int coins,
  required int bonusPoints,
  required String discount,
  required String pointAmount,
  required int concurrentTasks,
  required int storageMb,
}) {
  return ProductPlan.fromJson({
    'id': id,
    'type': 1,
    'title': title,
    'description': '<mark>${title.split(' ').first} $coins 专属权益</mark>\n\n'
        '<title>创作能力</title>\n\n'
        '同时排队 ×$concurrentTasks\n\n会员存储空间限制 ${storageMb}mb',
    'level': level,
    'coins': coins,
    'bonusPointsAmount': bonusPoints,
    'price': price,
    'original_price_amount': originalPrice,
    'custom_info': {
      'buttonText': '立即购买',
      'discount_info': discount,
      'point_amount': pointAmount,
      'feature_title': switch (level) {
        1 => 'starter-小小尝试',
        2 => 'Plus-小有成就',
        3 => 'Pro-IP进阶',
        _ => 'Max-IP诊断',
      },
    },
  });
}
