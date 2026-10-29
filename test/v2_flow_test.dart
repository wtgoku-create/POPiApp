import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:popi_ai_app/features/auth/presentation/login_page.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/notifications/presentation/notifications_page.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/v2_shared/data/v2_repository.dart';
import 'package:popi_ai_app/features/v2_shared/data/v2_fixtures.dart';
import 'package:popi_ai_app/features/v2_home/presentation/v2_home_page.dart';
import 'package:popi_ai_app/features/v2_session/presentation/v2_chat_page.dart';
import 'package:popi_ai_app/app/v2_app.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/session_artifacts_sheet.dart';
import 'package:popi_ai_app/features/profile/presentation/profile_page.dart';
import 'package:popi_ai_app/features/profile/presentation/edit_profile_page.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/safe_area_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';
import 'package:popi_ai_app/shared/type/bot_avatar_type.dart';
import 'package:popi_ai_app/shared/widgets/app_glass_app_bar.dart';
import 'package:popi_ai_app/features/v2_shared/presentation/widgets/v2_widgets.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

class _ControlledStorage extends PreferencesStorage {
  _ControlledStorage(super.preferences);
  bool failWrites = false;
  Completer<void>? writeGate;
  @override
  Future<void> setString(String key, String value) async {
    await writeGate?.future;
    if (failWrites) throw StateError('Disk unavailable');
    await super.setString(key, value);
  }
}

class _ReturningUser extends UserController {
  @override
  User? build() => const User(id: 'returning', name: '用户', email: '');
}

Future<V2Repository> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  Locale locale = const Locale('zh'),
  bool disableAnimations = true,
  PreferencesStorage? storage,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final repository = V2Repository(
    storage ?? PreferencesStorage(await SharedPreferences.getInstance()),
  )..restore();
  addTearDown(repository.dispose);
  await tester.pumpWidget(
    ProviderScope(
      child: ToastificationWrapper(
        child: MaterialApp(
          theme: AppTheme.light,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
          home: V2HomePage(repository: repository),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  for (final width in [320.0, 390.0, 440.0]) {
    testWidgets('navigation buttons use equal side margins at $width', (
      tester,
    ) async {
      await _pump(tester, size: Size(width, 844));
      final avatar = tester.getRect(find.byTooltip('个人资料'));
      final create = tester.getRect(find.byKey(const Key('demo-create')));
      final notifications = tester.getRect(
        find.byKey(const Key('v2-notifications')),
      );
      expect(avatar.size, const Size.square(40));
      expect(avatar.left, 20);
      expect(width - create.right, 20);
      expect(notifications.size, const Size.square(40));
      expect(create.left - notifications.right, 10);
      expect(tester.getCenter(find.text('会话')).dx, width / 2);
      await tester.tap(find.text('灵感到成片'));
      await tester.pumpAndSettle();
      final back = tester.getRect(find.byTooltip('返回'));
      final settings = tester.getRect(find.byKey(const Key('demo-settings')));
      expect(back.size, const Size.square(40));
      expect(back.left, 20);
      expect(settings.size, const Size.square(40));
      expect(width - settings.right, 20);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [440.0, 1200.0]) {
    testWidgets('profile and edit routes stay in the detail pane at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 956);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        V2Repository.storageKey: jsonEncode({
          'sessions': V2Fixtures.sessions().map((s) => s.toJson()).toList(),
          'assets': V2Fixtures.assets().map((a) => a.toJson()).toList(),
          'onboardingSessions': {'returning': 'alice'},
        }),
      });
      final preferences = await SharedPreferences.getInstance();
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) =>
                handler.reject(DioException(requestOptions: options)),
          ),
        );
      addTearDown(() => dio.close(force: true));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            userBootstrapProvider.overrideWith((ref) async {}),
            userProvider.overrideWith(_ReturningUser.new),
            dioProvider.overrideWithValue(dio),
          ],
          child: const V2App(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('个人资料'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(
        tester.getRect(find.byType(ProfilePage)).left,
        width >= 840 ? 320 : 0,
      );
      expect(
        find.text('爱丽丝视频').hitTestable(),
        width >= 840 ? findsOneWidget : findsNothing,
      );
      await tester.tap(find.text('编辑资料'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfilePage), findsOneWidget);
      expect(
        tester.getRect(find.byType(EditProfilePage)).left,
        width >= 840 ? 320 : 0,
      );
      final editState = tester.state(find.byType(EditProfilePage));
      await tester.enterText(
        find
            .descendant(
              of: find.byType(EditProfilePage),
              matching: find.byType(TextField),
            )
            .first,
        '待保存的昵称',
      );
      tester.view.physicalSize = Size(width >= 840 ? 440 : 1200, 956);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(EditProfilePage)), same(editState));
      expect(find.text('待保存的昵称'), findsOneWidget);
      expect(
        tester.getRect(find.byType(EditProfilePage)).left,
        width >= 840 ? 0 : 320,
      );
      await tester.tap(find.byKey(const Key('profile-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-back')));
      await tester.pumpAndSettle();
      expect(find.byType(V2HomePage), findsOneWidget);
      tester.view.physicalSize = const Size(1200, 956);
      await tester.pumpAndSettle();
      await tester.tap(find.text('爱丽丝视频').hitTestable());
      await tester.pumpAndSettle();
      final chatState = tester.state(find.byType(V2ChatPage));
      await tester.tap(find.byKey(const Key('v2-notifications')));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsOneWidget);
      expect(tester.getRect(find.byType(NotificationsPage)).left, 320);
      await tester.tap(find.byKey(const Key('notification-back')));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(V2ChatPage)), same(chatState));
      await tester.tap(find.byTooltip('个人资料'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(V2ChatPage)), same(chatState));
      await tester.tap(find.byTooltip('个人资料'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('demo-tab-1')));
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsNothing);
      await tester.tap(find.text('奶茶店的午后').hitTestable());
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(SessionArtifactDetailPage)).left, 320);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(SessionArtifactDetailPage), findsNothing);
      await tester.tap(find.byKey(const Key('demo-tab-0')));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(V2ChatPage)), same(chatState));
      final router = GoRouter.of(tester.element(find.byType(V2HomePage)));
      router.push<void>('/login');
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(LoginPage)),
        const Rect.fromLTWH(0, 0, 1200, 956),
      );
      expect(find.text('爱丽丝视频').hitTestable(), findsNothing);
      await tester.tap(find.byKey(const Key('login-back-button')));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(V2ChatPage)), same(chatState));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('chat applies the status and toolbar inset only once', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 62, bottom: 34);
    addTearDown(tester.view.resetPadding);
    await _pump(tester);
    await tester.tap(find.text('灵感到成片'));
    await tester.pumpAndSettle();
    final avatar = find.byWidgetPredicate(
      (widget) => widget is V2Avatar && widget.size == 32,
    );
    expect(
      tester.getTopLeft(avatar.first).dy,
      tester.getRect(find.byType(AppBar).hitTestable()).bottom + 10,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom navigation floats over the full-height scroll area', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPadding);
    await _pump(tester);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.extendBody, true);
    final nav = tester.getRect(find.byKey(const Key('demo-tab-1')));
    final list = tester.getRect(find.byType(ListView).hitTestable().first);
    expect(list.bottom, greaterThan(nav.bottom));
    expect(find.byType(V2BottomOverlay), findsOneWidget);
    final backdrop = find.descendant(
      of: find.byType(V2BottomOverlay),
      matching: find.byType(BackdropFilter),
    );
    // A collapsed backdrop leaves list text sharp behind the floating controls.
    expect(tester.getSize(backdrop.first).width, 390);
    expect(tester.getSize(backdrop.first).height, greaterThan(0));
    final tabs = find.byKey(const Key('demo-bottom-tabs'));
    expect(tester.getSize(tabs).height, 54);
    expect(tester.getRect(tabs).bottom, closeTo(844 - 34, .01));
    tester.view.padding = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(tester.getRect(tabs).bottom, closeTo(844 - 20, .01));
    expect(tester.takeException(), isNull);
  });

  for (final tab in [0, 1]) {
    testWidgets('bottom navigation follows list scroll direction on tab $tab', (
      tester,
    ) async {
      await _pump(tester, size: const Size(360, 640), disableAnimations: false);
      await tester.tap(find.byKey(Key('demo-tab-$tab')));
      await tester.pumpAndSettle();
      final tabs = find.byKey(const Key('demo-bottom-tabs'));
      final list = tab == 0
          ? find.byType(ListView).hitTestable()
          : find.byType(CustomScrollView).hitTestable();
      final bounds = tester.getRect(list);
      final navBounds = tester.getRect(tabs);
      final backdrop = find
          .descendant(
            of: find.byType(V2BottomOverlay),
            matching: find.byType(BackdropFilter),
          )
          .first;
      final backdropBounds = tester.getRect(backdrop);
      await tester.drag(list, const Offset(0, -220));
      await tester.pumpAndSettle();
      expect(tabs.hitTestable(), findsNothing);
      expect(tester.getRect(list), bounds);
      expect(tester.getRect(backdrop), backdropBounds);
      await tester.drag(list, const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(tabs.hitTestable(), findsOneWidget);
      expect(tester.getRect(tabs), navBounds);
      expect(tester.getRect(list), bounds);
      expect(tester.getRect(backdrop), backdropBounds);
      await tester.drag(list, const Offset(0, -220));
      await tester.pumpAndSettle();
      expect(tabs.hitTestable(), findsNothing);
      await tester.enterText(
        find.byType(TextField).hitTestable(),
        'no matching results',
      );
      await tester.pumpAndSettle();
      expect(tabs.hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(Key('demo-tab-${1 - tab}')));
      await tester.pumpAndSettle();
      expect(tabs.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'settings identity scrolls away before tabs pin below the app bar',
    (tester) async {
      await _pump(tester);
      await tester.tap(find.text('灵感到成片'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('demo-settings')));
      await tester.pumpAndSettle();
      final tabs = find.byType(V2Segments).hitTestable();
      final start = tester.getTopLeft(tabs).dy;
      await tester.drag(
        find.byType(ListView).hitTestable().first,
        const Offset(0, -450),
      );
      await tester.pumpAndSettle();
      final pinned = tester.getTopLeft(tabs).dy;
      expect(pinned, lessThan(start));
      expect(pinned, closeTo(kToolbarHeight + AppGlassHeader.topSpacing, 1));
      expect(find.byTooltip('重命名会话').hitTestable(), findsNothing);
      await tester.drag(
        find.byType(ListView).hitTestable().first,
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(tabs).dy, closeTo(pinned, 1));
      await tester.tap(find.text('能力').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('添加成员').hitTestable(), findsOneWidget);
      await tester.tap(find.text('产物').hitTestable());
      await tester.pumpAndSettle();
      final segments = find.byType(V2Segments).hitTestable();
      final mainTabs = tester.getRect(segments.first);
      final filters = tester.getRect(segments.last);
      expect(mainTabs.top, closeTo(pinned, 1));
      expect(filters.top - mainTabs.bottom, closeTo(20, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('asset search and filters remain pinned after a long scroll', (
    tester,
  ) async {
    await _pump(tester, size: const Size(360, 740));
    await tester.tap(find.byKey(const Key('demo-tab-1')));
    await tester.pumpAndSettle();
    final search = find.byType(V2Search).hitTestable();
    final y = tester.getTopLeft(search).dy;
    expect(find.text('爱丽丝的场景 5'), findsNothing);
    await tester.drag(
      find.byType(CustomScrollView).hitTestable(),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(search).dy, y);
    expect(find.text('图片').hitTestable(), findsOneWidget);
    await tester.tap(find.text('视频').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('奶茶店的午后'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'role sheet keeps selection order and its action fixed while scrolling',
    (tester) async {
      final repository = await _pump(tester, size: const Size(440, 956));
      await tester.tap(find.text('灵感到成片'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('demo-settings')));
      await tester.pumpAndSettle();
      final back = tester.widget<RotatedBox>(
        find.descendant(
          of: find.byTooltip('返回'),
          matching: find.byType(RotatedBox),
        ),
      );
      expect(back.quarterTurns, 1);
      await tester.tap(find.text('关联角色'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
        false,
      );
      expect(tester.getTopLeft(find.byType(BottomSheet)).dy, closeTo(66, 1));
      expect(
        find.byWidgetPredicate((w) => w is V2SelectionMark && w.number == 1),
        findsOneWidget,
      );
      final action = find.text('加入创作');
      final actionY = tester.getTopLeft(action).dy;
      await tester.drag(find.byType(GridView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(action).dy, actionY);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(repository.session('inspiration').roles, ['alice', 'er', 'dou']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rename dialog uses a separate label and saves the edited name', (
    tester,
  ) async {
    final repository = await _pump(tester);
    await tester.tap(find.text('灵感到成片'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('重命名会话'));
    await tester.pumpAndSettle();
    expect(find.text('会话名称'), findsOneWidget);
    expect(find.text('5/15'), findsOneWidget);
    final field = find.descendant(
      of: find.byType(Dialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, '校园生活制作组');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(repository.session('inspiration').title, '校园生活制作组');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'upload sheet removes and restores chosen files on a small phone',
    (tester) async {
      await _pump(tester, size: const Size(320, 680));
      await tester.tap(find.byKey(const Key('demo-tab-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('demo-upload')));
      await tester.pumpAndSettle();
      expect(find.text('已选择 4 个文件'), findsOneWidget);
      await tester.tap(find.byTooltip('删除').first);
      await tester.pumpAndSettle();
      expect(find.text('已选择 3 个文件'), findsOneWidget);
      await tester.tap(find.text('点击选择文件'));
      await tester.pumpAndSettle();
      expect(find.text('已选择 4 个文件'), findsOneWidget);
      expect(find.text('上传到官方资产库').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('search filters conversations and asset tabs stay interactive', (
    tester,
  ) async {
    await _pump(tester, size: const Size(360, 740));
    await tester.enterText(find.byType(TextField).first, '爱丽丝视频');
    await tester.pumpAndSettle();
    expect(
      find.text('爱丽丝视频', findRichText: false).hitTestable().last,
      findsOneWidget,
    );
    expect(find.text('叮叮制作组'), findsNothing);
    await tester.tap(find.byKey(const Key('demo-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('奶茶店的午后'), findsOneWidget);
    await tester.tap(find.text('脚本').first);
    await tester.pumpAndSettle();
    expect(find.text('奶茶店的重逢'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('asset cards open image and script detail pages and return', (
    tester,
  ) async {
    await _pump(tester, size: const Size(320, 680));
    await tester.tap(find.byKey(const Key('demo-tab-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('奶茶店的午后'));
    await tester.pumpAndSettle();
    expect(find.byType(SessionArtifactDetailPage), findsOneWidget);
    expect(find.text('图片详情'), findsOneWidget);
    expect(
      find.byKey(const Key('session-artifact-detail-milk')),
      findsOneWidget,
    );
    expect(find.byTooltip('下载'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('奶茶店的午后'), findsOneWidget);
    await tester.tap(find.text('脚本').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('奶茶店的重逢'));
    await tester.pumpAndSettle();
    expect(find.text('脚本详情'), findsOneWidget);
    expect(
      find.byKey(const Key('session-artifact-detail-script')),
      findsOneWidget,
    );
    expect(find.textContaining('场景一', findRichText: true), findsWidgets);
    expect(find.byTooltip('下载'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('奶茶店的重逢'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat images open a preview and return to the conversation', (
    tester,
  ) async {
    final repository = await _pump(tester);
    await tester.tap(find.text('爱丽丝视频'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('奶茶店的午后'));
    await tester.runAsync(
      () => precacheImage(
        AssetImage(repository.assets.firstWhere((a) => a.id == 'milk').cover),
        tester.element(find.text('奶茶店的午后')),
      ),
    );
    await tester.tap(find.text('奶茶店的午后'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('asset-preview-image')), findsOneWidget);
    expect(find.byType(SessionArtifactDetailPage), findsNothing);
    await tester.tap(find.byKey(const Key('asset-preview-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-settings')), findsOneWidget);
    expect(find.text('奶茶店的午后'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 440.0]) {
    testWidgets('stacked chat images swipe both ways at $width', (
      tester,
    ) async {
      final repository = await _pump(tester, size: Size(width, 844));
      await tester.tap(find.text('灵感到成片'));
      await tester.pumpAndSettle();
      final deck = find.byKey(const ValueKey('demo-image-stack-ins2'));
      await tester.ensureVisible(deck);
      await tester.pumpAndSettle();
      final size = tester.getSize(deck);
      expect(find.text('1/5'), findsOneWidget);
      await tester.drag(deck, const Offset(-220, 0));
      await tester.pumpAndSettle();
      expect(find.text('2/5'), findsOneWidget);
      expect(tester.getSize(deck), size);
      await tester.drag(deck, const Offset(220, 0));
      await tester.pumpAndSettle();
      expect(find.text('1/5'), findsOneWidget);
      await tester.drag(deck, const Offset(-220, 0));
      await tester.pumpAndSettle();
      final images = repository
          .session('inspiration')
          .messages
          .last
          .assetIds
          .map((id) => repository.assets.firstWhere((a) => a.id == id))
          .toList();
      await tester.runAsync(
        () => Future.wait([
          for (final asset in images)
            precacheImage(AssetImage(asset.cover), tester.element(deck)),
        ]),
      );
      await tester.tapAt(tester.getTopLeft(deck) + const Offset(80, 80));
      await tester.pumpAndSettle();
      final preview = find.byKey(const Key('asset-preview-image'));
      expect(preview, findsOneWidget);
      expect(
        tester
            .widget<Image>(
              find.descendant(of: preview, matching: find.byType(Image)),
            )
            .image,
        AssetImage(images[1].cover),
      );
      await tester.tap(find.byKey(const Key('asset-preview-close')));
      await tester.pumpAndSettle();
      expect(find.text('2/5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('settings retain capability edits and selected members', (
    tester,
  ) async {
    final repository = await _pump(tester);
    await tester.tap(find.text('灵感到成片'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('能力'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('添加成员'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('角色设计师'));
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(repository.session('inspiration').members, contains('designer'));
    expect(find.text('工作方式'), findsNothing);
    final control = find.byType(Switch).first;
    await tester.ensureVisible(control);
    await tester.pumpAndSettle();
    final controlSize =
        tester.getBottomRight(control) - tester.getTopLeft(control);
    expect(controlSize.dx, greaterThanOrEqualTo(51));
    expect(controlSize.dy, greaterThanOrEqualTo(31));
    await tester.tap(control);
    await tester.pumpAndSettle();
    expect(
      repository.session('inspiration').capabilities,
      isNot(contains('character')),
    );
    await tester.drag(
      find.byKey(const PageStorageKey('demo-settings-skills')),
      const Offset(0, 700),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('POPi').last);
    await tester.pumpAndSettle();
    expect(find.text('编辑成员'), findsOneWidget);
    expect(find.text('我的名字'), findsOneWidget);
    final rabbit = find.byKey(const ValueKey('demo-avatar-rabbit'));
    await tester.ensureVisible(rabbit);
    await tester.tap(rabbit);
    await tester.ensureVisible(find.text('背景颜色').first);
    await tester.pumpAndSettle();
    expect(find.text('工作方式'), findsNothing);
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    expect(
      repository.session('inspiration').memberAvatars['popi'],
      BotAvatarCharacter.rabbit.stillAsset,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat bottom spacing does not duplicate the safe area', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPadding);
    await _pump(tester);
    final context = tester.element(find.byType(V2HomePage));
    ProviderScope.containerOf(context)
        .read(safeAreaInsetsProvider.notifier)
        .update(const EdgeInsets.only(bottom: 34));
    await tester.tap(find.byKey(const Key('demo-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v2-create-popi-confirm')));
    await tester.pumpAndSettle();
    final disclaimer = find.text('AI生成结果可能有误，仅供参考');
    final bottom = tester.getBottomLeft(disclaimer).dy;
    expect(844 - bottom, closeTo(34, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('new session generates local results and persists them', (
    tester,
  ) async {
    final repository = await _pump(tester);
    await tester.tap(find.byKey(const Key('demo-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v2-create-popi-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('嗨，用户～'), findsOneWidget);
    final attachment = repository.assets.first;
    await tester.tap(find.byTooltip('添加附件'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(attachment.id)));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ValueKey('popi-selected-asset-${attachment.id}')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('移除资产'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('popi-selected-assets')), findsNothing);
    await tester.tap(find.byKey(const Key('popi-message-input')));
    await tester.pumpAndSettle();
    tester.testTextInput.enterText('批量生成五张场景图');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('popi-send-button')));
    await tester.pump();
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (i == 0) {
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(find.byKey(const Key('popi-send-button')))
              .onPressed,
          isNull,
        );
      }
    }
    await tester.pumpAndSettle();
    expect(repository.sessions.first.messages.last.assetIds, hasLength(5));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'create sheet saves the configured assistant before opening an empty chat',
    (tester) async {
      final repository = await _pump(tester, size: const Size(440, 956));
      await tester.tap(find.byKey(const Key('demo-create')));
      await tester.pumpAndSettle();
      expect(find.text('创建一个POPi'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('v2-create-popi-preview'))),
        const Size.square(100),
      );
      expect(repository.sessions, hasLength(7));
      await tester.enterText(
        find.byKey(const Key('v2-create-popi-name')),
        '画画搭子',
      );
      await tester.enterText(
        find.byKey(const Key('v2-create-popi-instructions')),
        '帮我设计角色，简洁表达',
      );
      tester.testTextInput.hide();
      await tester.ensureVisible(
        find.byKey(const ValueKey('v2-create-avatar-rabbit')),
      );
      await tester.tap(find.byKey(const ValueKey('v2-create-avatar-rabbit')));
      final color = find.byKey(const ValueKey('v2-create-color-4293188862'));
      await tester.ensureVisible(color);
      await tester.tap(color);
      await tester.tap(find.byKey(const Key('v2-create-popi-confirm')));
      await tester.pumpAndSettle();
      final session = repository.sessions.first;
      expect(session.title, '画画搭子');
      expect(session.memberNames, {'popi': '画画搭子'});
      expect(session.memberInstructions, {'popi': '帮我设计角色，简洁表达'});
      expect(session.memberAvatars, {
        'popi': 'assets/images/popi_avatar_rabbit.png',
      });
      expect(session.memberColors, {'popi': 0xFFE4DCFE});
      expect(session.messages, isEmpty);
      expect(find.text('画画搭子'), findsOneWidget);
      expect(find.byKey(const Key('v2-role-onboarding')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('create controls remain reachable on a small English phone', (
    tester,
  ) async {
    await _pump(tester, size: const Size(320, 680), locale: const Locale('en'));
    await tester.tap(find.byKey(const Key('demo-create')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('v2-create-avatar-pig')),
      100,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('v2-create-popi-form')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('v2-create-avatar-pig')));
    await tester.tap(find.byKey(const Key('v2-create-popi-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-settings')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling creation leaves the conversation list unchanged', (
    tester,
  ) async {
    final repository = await _pump(tester);
    await tester.tap(find.byKey(const Key('demo-create')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    expect(repository.sessions, hasLength(7));
    expect(find.byType(V2ChatPage), findsNothing);
    expect(find.byKey(const Key('demo-create')), findsOneWidget);
  });

  testWidgets(
    'creation failure retains inputs and pending saves cannot duplicate',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = _ControlledStorage(await SharedPreferences.getInstance())
        ..failWrites = true;
      final repository = await _pump(tester, storage: storage);
      await tester.tap(find.byKey(const Key('demo-create')));
      await tester.pumpAndSettle();
      final name = find.byKey(const Key('v2-create-popi-name'));
      await tester.enterText(name, '我的助手');
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('v2-create-popi-confirm'));
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(repository.sessions, hasLength(7));
      expect(tester.widget<TextField>(name).controller!.text, '我的助手');
      storage.failWrites = false;
      final gate = storage.writeGate = Completer<void>();
      await tester.tap(confirm);
      await tester.pump();
      final button = find.descendant(
        of: confirm,
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      gate.complete();
      await tester.pumpAndSettle();
      expect(repository.sessions, hasLength(8));
      expect(repository.sessions.first.title, '我的助手');
      expect(find.byType(V2ChatPage), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('empty chat links a role and removes the onboarding card', (
    tester,
  ) async {
    final repository = await _pump(tester);
    await tester.tap(find.byKey(const Key('demo-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v2-create-popi-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v2-link-role')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('er')));
    await tester.tap(find.text('加入创作'));
    await tester.pumpAndSettle();
    expect(repository.sessions.first.roles, ['er']);
    expect(find.byKey(const Key('v2-role-onboarding')), findsNothing);
    expect(find.text('嗨，用户～'), findsOneWidget);
  });

  testWidgets('empty chat can create and link a custom role', (tester) async {
    final repository = await _pump(tester);
    await tester.tap(find.byKey(const Key('demo-create')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v2-create-popi-confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('v2-create-diy-role')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '小橘');
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加入创作'));
    await tester.pumpAndSettle();
    expect(repository.sessions.first.roles, ['custom:小橘']);
    expect(find.byKey(const Key('v2-role-onboarding')), findsNothing);
  });

  testWidgets('English layout fits the smaller phone viewport', (tester) async {
    await _pump(tester, size: const Size(320, 680), locale: const Locale('en'));
    await tester.tap(find.byKey(const Key('demo-tab-1')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('demo-upload')));
    await tester.pumpAndSettle();
    expect(find.text('Upload material'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
