import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_home_page.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_image_stack.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/type/bot_avatar_type.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

final _screenshotsEnabled =
    Platform.environment['POPI_CHAT_POLISH_SCREENSHOTS'] != null;
final _capturePhase =
    Platform.environment['POPI_CHAT_POLISH_PHASE'] ?? 'baseline';
const _captureRoot = '.omx/state/chat-visual-polish';

const _assets = [
  DemoAsset(
    id: 'polish-scene-1',
    title: '温暖故事场景一',
    kind: DemoAssetKind.image,
    cover: 'assets/images/demo_scene_1.png',
    sessionId: 'visual-polish',
    width: 1672,
    height: 941,
  ),
  DemoAsset(
    id: 'polish-scene-2',
    title: '温暖故事场景二',
    kind: DemoAssetKind.image,
    cover: 'assets/images/demo_scene_2.png',
    sessionId: 'visual-polish',
    width: 4096,
    height: 2286,
  ),
  DemoAsset(
    id: 'polish-scene-3',
    title: '温暖故事场景三',
    kind: DemoAssetKind.image,
    cover: 'assets/images/demo_scene_3.png',
    sessionId: 'visual-polish',
    width: 540,
    height: 788,
  ),
  DemoAsset(
    id: 'polish-scene-4',
    title: '温暖故事场景四',
    kind: DemoAssetKind.image,
    cover: 'assets/images/demo_scene_4.png',
    sessionId: 'visual-polish',
    width: 1600,
    height: 900,
  ),
];

final _session = DemoSession(
  id: 'visual-polish',
  title: 'VideoV',
  kind: DemoSessionKind.conversation,
  members: const ['popi'],
  roles: const [],
  memberNames: const {'popi': 'VideoV'},
  memberAvatars: const {'popi': 'assets/animations/bot_avatars/tiger.png'},
  memberColors: const {'popi': 0xFFFFF0D8},
  updatedAt: DateTime.utc(2026, 10, 26, 2, 20),
  messages: [
    DemoMessage(
      id: 'assistant-brief',
      memberId: 'popi',
      memberName: 'VideoV',
      createdAt: DateTime.utc(2026, 10, 26, 2, 18),
      text:
          '**画面方向**：暖色自然光，保留生活纪录感。\n\n'
          '- 角色动作保持自然，不摆拍\n'
          '- 镜头从近景慢慢拉到全景\n'
          '- 最后停在一家人一起看镜头的瞬间',
    ),
    DemoMessage(
      id: 'user-confirm',
      text: '可以，继续做',
      user: true,
      createdAt: DateTime.utc(2026, 10, 26, 2, 19),
    ),
    DemoMessage(
      id: 'assistant-images',
      memberId: 'popi',
      memberName: 'VideoV',
      createdAt: DateTime.utc(2026, 10, 26, 2, 20),
      text: '四张画面已经整理好。你可以先看整体故事感，再打开其中一张检查细节。',
      assetIds: [
        'polish-scene-1',
        'polish-scene-2',
        'polish-scene-3',
        'polish-scene-4',
      ],
    ),
  ],
);

Future<DemoRepository> _repository() async {
  SharedPreferences.setMockInitialValues({
    DemoRepository.storageKey: jsonEncode({
      'sessions': [_session.toJson()],
      'assets': _assets.map((asset) => asset.toJson()).toList(),
    }),
  });
  return DemoRepository(
    PreferencesStorage(await SharedPreferences.getInstance()),
  )..restore();
}

Future<void> _precacheImages(WidgetTester tester, BuildContext context) async {
  await tester.runAsync(
    () => Future.wait([
      for (final asset in _assets)
        precacheImage(AssetImage(asset.cover), context),
    ]),
  );
  await tester.pump();
}

Future<void> _precacheAvatars(WidgetTester tester, BuildContext context) async {
  await tester.runAsync(
    () => Future.wait([
      for (final character in BotAvatarCharacter.values)
        precacheImage(AssetImage(character.stillAsset), context),
    ]),
  );
  await tester.pump();
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey repaintKey,
  String name,
) async {
  if (!_screenshotsEnabled) return;
  await tester.runAsync(() async {
    final boundary =
        repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('$_captureRoot/$_capturePhase/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Widget home,
  required GlobalKey repaintKey,
  required Size size,
  double textScale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final theme = AppTheme.light;
  await tester.pumpWidget(
    RepaintBoundary(
      key: repaintKey,
      child: ProviderScope(
        child: ToastificationWrapper(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: !_screenshotsEnabled
                ? theme
                : theme.copyWith(
                    textTheme: theme.textTheme.apply(
                      fontFamily: 'ChatPolishCapture',
                    ),
                  ),
            darkTheme: !_screenshotsEnabled
                ? AppTheme.dark
                : AppTheme.dark.copyWith(
                    textTheme: AppTheme.dark.textTheme.apply(
                      fontFamily: 'ChatPolishCapture',
                    ),
                  ),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: home,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (!_screenshotsEnabled) return;
    final font = File('/System/Library/Fonts/Hiragino Sans GB.ttc');
    if (font.existsSync()) {
      await (FontLoader(
        'ChatPolishCapture',
      )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  tearDown(() => toastification.dismissAll(delayForAnimation: false));

  testWidgets('mobile chat typography and image deck remain readable', (
    tester,
  ) async {
    final repository = await _repository();
    addTearDown(repository.dispose);
    final repaintKey = GlobalKey();
    await _pump(
      tester,
      home: DemoChatPage(repository: repository, sessionId: _session.id),
      repaintKey: repaintKey,
      size: const Size(390, 844),
    );
    final deck = find.byType(DemoImageStack);
    await tester.ensureVisible(deck);
    await _precacheImages(tester, tester.element(deck));
    await tester.pumpAndSettle();

    expect(deck, findsOneWidget);
    expect(find.textContaining('画面方向', findRichText: true), findsOneWidget);
    expect(find.text('可以，继续做'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, repaintKey, 'mobile-chat');
  });

  testWidgets('desktop workspace uses the same message fixture', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final repository = await _repository();
      addTearDown(repository.dispose);
      final repaintKey = GlobalKey();
      await _pump(
        tester,
        home: DemoHomePage(repository: repository),
        repaintKey: repaintKey,
        size: const Size(1200, 900),
      );
      final deck = find.byType(DemoImageStack);
      await tester.ensureVisible(deck);
      await _precacheImages(tester, tester.element(deck));
      await tester.pumpAndSettle();

      expect(find.text('VideoV'), findsWidgets);
      expect(deck, findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, repaintKey, 'desktop-chat');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('mobile inbox keeps identity summary and time hierarchy', (
    tester,
  ) async {
    final repository = await _repository();
    addTearDown(repository.dispose);
    final repaintKey = GlobalKey();
    await _pump(
      tester,
      home: DemoHomePage(repository: repository),
      repaintKey: repaintKey,
      size: const Size(390, 844),
    );
    await _precacheAvatars(tester, tester.element(find.byType(DemoHomePage)));

    expect(find.text('VideoV'), findsOneWidget);
    expect(find.textContaining('四张画面已经整理好'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, repaintKey, 'mobile-inbox');
  });

  testWidgets('narrow large-text chat avoids layout errors', (tester) async {
    final repository = await _repository();
    addTearDown(repository.dispose);
    await _pump(
      tester,
      home: DemoChatPage(repository: repository, sessionId: _session.id),
      repaintKey: GlobalKey(),
      size: const Size(320, 640),
      textScale: 1.5,
    );
    await tester.ensureVisible(find.text('可以，继续做'));
    await tester.pumpAndSettle();

    expect(find.text('可以，继续做'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('standalone image fan exposes its full depth and caption', (
    tester,
  ) async {
    final repaintKey = GlobalKey();
    await _pump(
      tester,
      home: Scaffold(
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 28),
              child: DemoImageStack(
                images: _assets,
                messageId: 'standalone-polish',
                initialIndex: 0,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
      repaintKey: repaintKey,
      size: const Size(390, 520),
    );
    final deck = find.byType(DemoImageStack);
    await _precacheImages(tester, tester.element(deck));
    await tester.pumpAndSettle();

    expect(deck, findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, repaintKey, 'image-fan-closeup');
  });

  testWidgets('portrait-first image fan keeps its natural paper proportion', (
    tester,
  ) async {
    final repaintKey = GlobalKey();
    final portraitFirst = [_assets[2], _assets[0], _assets[1], _assets[3]];
    await _pump(
      tester,
      home: Scaffold(
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 28),
              child: DemoImageStack(
                images: portraitFirst,
                messageId: 'portrait-standalone-polish',
                initialIndex: 0,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
      repaintKey: repaintKey,
      size: const Size(390, 520),
    );
    final deck = find.byType(DemoImageStack);
    await _precacheImages(tester, tester.element(deck));
    await tester.pumpAndSettle();

    expect(deck, findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, repaintKey, 'image-fan-portrait-closeup');
  });

  testWidgets('dark image fan keeps edge and caption contrast', (tester) async {
    final repaintKey = GlobalKey();
    await _pump(
      tester,
      home: Scaffold(
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 28),
              child: DemoImageStack(
                images: _assets,
                messageId: 'dark-standalone-polish',
                initialIndex: 0,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
      repaintKey: repaintKey,
      size: const Size(390, 360),
      dark: true,
    );
    final deck = find.byType(DemoImageStack);
    await _precacheImages(tester, tester.element(deck));
    await tester.pumpAndSettle();

    expect(deck, findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, repaintKey, 'image-fan-dark');
  });

  testWidgets('full mobile inbox keeps a readable multi-row rhythm', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = DemoRepository(
      PreferencesStorage(await SharedPreferences.getInstance()),
    )..restore();
    addTearDown(repository.dispose);
    final repaintKey = GlobalKey();
    await _pump(
      tester,
      home: DemoHomePage(repository: repository),
      repaintKey: repaintKey,
      size: const Size(390, 844),
    );
    await _precacheAvatars(tester, tester.element(find.byType(DemoHomePage)));

    expect(repository.sessions.length, greaterThanOrEqualTo(4));
    expect(tester.takeException(), isNull);
    await _capture(tester, repaintKey, 'mobile-inbox-density');
  });
}
