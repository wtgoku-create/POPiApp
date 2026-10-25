import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_home_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_welcome_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_app.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/session_artifacts_sheet.dart';
import 'package:popi_ai_app/features/profile/presentation/profile_page.dart';
import 'package:popi_ai_app/features/profile/presentation/edit_profile_page.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/safe_area_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/type/bot_avatar_type.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_widgets.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

Future<DemoRepository> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  Locale locale = const Locale('zh'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final repository = DemoRepository(
    PreferencesStorage(await SharedPreferences.getInstance()),
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
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: DemoHomePage(repository: repository),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  for (final testCase in [
    (name: 'without system insets', padding: FakeViewPadding.zero),
    (
      name: 'with top and horizontal system insets',
      padding: const FakeViewPadding(top: 59, left: 12, right: 8),
    ),
  ]) {
    testWidgets('avatar and profile backs share a position ${testCase.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(440, 956);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = testCase.padding;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            userBootstrapProvider.overrideWith((ref) async {}),
          ],
          child: const DemoApp(),
        ),
      );
      await tester.pumpAndSettle();
      final profileEntry = find.byTooltip('个人资料');
      final entryRect = tester.getRect(profileEntry);
      expect(entryRect.size, const Size.square(40));
      await tester.tap(profileEntry);
      await tester.pumpAndSettle();
      expect(find.byType(ProfilePage), findsOneWidget);
      final profileBack = find.byKey(const Key('profile-back'));
      final profileBackRect = tester.getRect(profileBack);
      expect(profileBackRect.size, const Size.square(40));
      expect(profileBackRect.center.dx, closeTo(entryRect.center.dx, .01));
      expect(profileBackRect.center.dy, closeTo(entryRect.center.dy, .01));
      await tester.tap(find.text('编辑资料'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProfilePage), findsOneWidget);
      final editBackRect = tester.getRect(profileBack);
      expect(editBackRect.size, const Size.square(40));
      expect(editBackRect.center.dx, closeTo(entryRect.center.dx, .01));
      expect(editBackRect.center.dy, closeTo(entryRect.center.dy, .01));
      await tester.tap(profileBack);
      await tester.pumpAndSettle();
      await tester.tap(profileBack);
      await tester.pumpAndSettle();
      expect(find.byType(DemoHomePage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

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
    expect(find.byType(DemoBottomOverlay), findsOneWidget);
    final backdrop = find.descendant(
      of: find.byType(DemoBottomOverlay),
      matching: find.byType(BackdropFilter),
    );
    // A collapsed backdrop leaves list text sharp behind the floating controls.
    expect(tester.getSize(backdrop.first).width, 390);
    expect(tester.getSize(backdrop.first).height, greaterThan(0));
    final tabs = find.byKey(const Key('demo-bottom-tabs'));
    expect(tester.getSize(tabs).height, 48);
    expect(tester.getRect(tabs).bottom, closeTo(844 - 34, .01));
    tester.view.padding = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(tester.getRect(tabs).bottom, closeTo(844 - 20, .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'settings identity scrolls away before tabs pin below the app bar',
    (tester) async {
      await _pump(tester);
      await tester.tap(find.text('灵感到成片'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('demo-settings')));
      await tester.pumpAndSettle();
      final tabs = find.byType(DemoSegments).hitTestable();
      final start = tester.getTopLeft(tabs).dy;
      await tester.drag(
        find.byType(ListView).hitTestable().first,
        const Offset(0, -450),
      );
      await tester.pumpAndSettle();
      final pinned = tester.getTopLeft(tabs).dy;
      expect(pinned, lessThan(start));
      expect(pinned, closeTo(kToolbarHeight, 1));
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
      final segments = find.byType(DemoSegments).hitTestable();
      final mainTabs = tester.getRect(segments.first);
      final filters = tester.getRect(segments.last);
      expect(mainTabs.top, closeTo(pinned, 1));
      expect(filters.top - mainTabs.bottom, closeTo(13, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('asset search and filters remain pinned after a long scroll', (
    tester,
  ) async {
    await _pump(tester, size: const Size(360, 740));
    await tester.tap(find.byKey(const Key('demo-tab-1')));
    await tester.pumpAndSettle();
    final search = find.byType(DemoSearch).hitTestable();
    final y = tester.getTopLeft(search).dy;
    expect(find.text('爱丽丝的场景 5'), findsNothing);
    await tester.drag(
      find.byType(CustomScrollView).hitTestable(),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(search).dy, y);
    final filters = find.byType(DemoSegments).hitTestable();
    expect(
      find.descendant(of: filters, matching: find.text('图片')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(
      find.descendant(of: filters, matching: find.text('视频')).hitTestable(),
    );
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
      expect(tester.getTopLeft(find.byType(BottomSheet)).dy, closeTo(60, 1));
      expect(
        find.byWidgetPredicate((w) => w is DemoSelectionMark && w.number == 1),
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
      await tester.tap(find.byKey(const Key('demo-create')));
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
    await tester.tap(find.byKey(const Key('demo-search-toggle')));
    await tester.pumpAndSettle();
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

  testWidgets('settings retain DSH defaults and edit the existing assistant', (
    tester,
  ) async {
    final repository = await _pump(tester);
    await tester.tap(find.text('灵感到成片'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('能力'));
    await tester.pumpAndSettle();
    final add = find.descendant(
      of: find.byKey(const Key('demo-add-members')),
      matching: find.byType(TextButton),
    );
    expect(tester.widget<TextButton>(add).onPressed, isNull);
    expect(repository.session('inspiration').members, [
      'popi',
      'writer',
      'director',
    ]);
    expect(
      find.byKey(const ValueKey('demo-style-film-capability-popi')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Switch>(
            find.byKey(const ValueKey('demo-style-film-capability-popi')),
          )
          .onChanged,
      isNull,
    );
    expect(
      repository.session('inspiration').capabilitiesFor('popi'),
      containsAll(['character', 'script', 'image', 'video', 'audio', 'vision']),
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
    final context = tester.element(find.byType(DemoHomePage));
    ProviderScope.containerOf(context)
        .read(safeAreaInsetsProvider.notifier)
        .update(const EdgeInsets.only(bottom: 34));
    await tester.tap(find.byKey(const Key('demo-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('demo-assistant-name')),
      '安全区测试',
    );
    tester.testTextInput.hide();
    final create = find.byKey(const Key('demo-create-assistant-confirm'));
    await tester.ensureVisible(create);
    await tester.pump();
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.text('AI生成结果可能有误，仅供参考'), findsNothing);
    final frame = find.byKey(const Key('popi-message-composer'));
    expect(844 - tester.getBottomLeft(frame).dy, closeTo(42, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('new session generates local results and persists them', (
    tester,
  ) async {
    final repository = await _pump(tester);
    await tester.tap(find.byKey(const Key('demo-create')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('demo-assistant-name')),
      '本地生成',
    );
    tester.testTextInput.hide();
    final create = find.byKey(const Key('demo-create-assistant-confirm'));
    await tester.ensureVisible(create);
    await tester.pump();
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.text('嗨，用户～'), findsOneWidget);
    final attachment = repository.assets.first;
    await tester.tap(find.byTooltip('添加附件'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-add-from-device')), findsNothing);
    expect(find.byKey(const Key('demo-add-from-library')), findsOneWidget);
    await tester.tap(find.byKey(const Key('demo-add-from-library')));
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
    'welcome matches the design geometry and keeps real line breaks',
    (tester) async {
      final repository = await _pump(tester, size: const Size(440, 956));
      Navigator.of(tester.element(find.byType(DemoHomePage))).push<void>(
        MaterialPageRoute(
          builder: (_) => DemoWelcomePage(repository: repository),
        ),
      );
      await tester.pumpAndSettle();
      final panel = find.byKey(const Key('demo-welcome-options'));
      expect(tester.getSize(panel), const Size(400, 262));
      expect(tester.getTopLeft(panel).dy, closeTo(311, 1));
      expect(
        tester.getTopLeft(find.byKey(const Key('demo-welcome-greeting'))).dy,
        closeTo(164, 1),
      );
      expect(find.text('在创建会话之前\n请告诉我：\n你现在最想做什么？'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('all welcome entries remain reachable on a small English phone', (
    tester,
  ) async {
    final repository = await _pump(
      tester,
      size: const Size(320, 680),
      locale: const Locale('en'),
    );
    final intent = Navigator.of(tester.element(find.byType(DemoHomePage)))
        .push<DemoCreateIntent>(
          MaterialPageRoute(
            builder: (_) => DemoWelcomePage(repository: repository),
          ),
        );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('demo-welcome-entry-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Let's chat first"));
    await tester.pumpAndSettle();
    expect((await intent)?.title, "Let's chat first");
    expect(find.byType(DemoHomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English layout fits the smaller phone viewport', (tester) async {
    await _pump(tester, size: const Size(320, 680), locale: const Locale('en'));
    await tester.tap(find.byKey(const Key('demo-tab-1')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('demo-create')));
    await tester.pumpAndSettle();
    expect(find.text('Upload material'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
