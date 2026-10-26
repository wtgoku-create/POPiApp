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
import 'package:popi_ai_app/features/demo/presentation/demo_home_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_remote_media.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/type/bot_avatar_type.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

final _screenshotsEnabled =
    Platform.environment['POPI_THREE_COLUMN_SCREENSHOTS'] != null;
final _capturePhase =
    Platform.environment['POPI_THREE_COLUMN_PHASE'] ?? 'baseline';
const _captureRoot = '.omx/state/three-column-workspace';

const _assets = [
  DemoAsset(
    id: 'video-v-key-art',
    title: '夏日故事主视觉',
    kind: DemoAssetKind.image,
    cover: 'assets/images/demo_scene_1.png',
    sessionId: 'video-v',
    width: 1672,
    height: 941,
  ),
  DemoAsset(
    id: 'video-v-board',
    title: '角色分镜稿',
    kind: DemoAssetKind.image,
    cover: 'assets/images/demo_scene_3.png',
    sessionId: 'video-v',
    width: 540,
    height: 788,
  ),
  DemoAsset(
    id: 'claude-key-art',
    title: '睡前故事封面',
    kind: DemoAssetKind.image,
    cover: 'assets/images/demo_milk_tea.png',
    sessionId: 'claude-c',
    width: 1024,
    height: 1024,
  ),
  DemoAsset(
    id: 'claude-scene',
    title: '夜晚场景草图',
    kind: DemoAssetKind.image,
    cover: 'assets/images/demo_scene_4.png',
    sessionId: 'claude-c',
    width: 1600,
    height: 900,
  ),
];

final _sessions = [
  DemoSession(
    id: 'video-v',
    title: 'VideoV',
    kind: DemoSessionKind.conversation,
    members: const ['director'],
    roles: const ['alice'],
    messages: [
      DemoMessage(
        id: 'video-intro',
        text: '这次把夏日角色做成一条完整的小故事。',
        user: true,
        createdAt: DateTime.utc(2026, 10, 26, 7, 35),
      ),
      DemoMessage(
        id: 'video-reply',
        memberId: 'director',
        memberName: 'VideoV',
        createdAt: DateTime.utc(2026, 10, 26, 7, 36),
        text:
            '收到啦～这张夏日版我也很喜欢：她托着腮、笑得眼睛都弯了，冰饮的水珠和绣球花的光，都像是夏天下午三四点那种最松弛的时刻。\n\n'
            '知夏这个角色现在已经有自己的样子了：\n\n'
            '- **定妆**：低马尾、金耳环、月牙笑眼\n'
            '- **夏日版**：白亚麻、绣球与冰饮\n'
            '- **人设**：花艺师，慢、心软但有自己的原则\n\n'
            '接下来想做什么都可以跟我说一声，比如：再出一张傍晚逆光，或者让她开口说两句台词。',
        assetIds: const ['video-v-key-art', 'video-v-board'],
      ),
    ],
    time: '15:15',
    updatedAt: DateTime.utc(2026, 10, 26, 7, 36),
    direction: '把生活里的松弛瞬间拍成温暖、可连续观看的角色短片。',
    positioning: '面向喜欢治愈故事与角色成长的年轻创作者。',
    accountPreferences: const {
      'feeling': '温暖、松弛、有生活质感',
      'format': '竖屏角色短片与分镜图',
      'audience': '年轻创作者与治愈系内容观众',
    },
    creativeMemory: const DemoCreativeMemory(
      text: '暖色自然光，人物动作克制，优先 Seedance 2.5 与 9:16。',
    ),
    memberNames: const {'director': 'VideoV'},
    memberInstructions: const {'director': '把创作意图整理成故事、分镜与可执行的视听方案。'},
    memberAvatars: const {
      'director': 'assets/animations/bot_avatars/dragon.png',
    },
    memberColors: const {'director': 0xFFFFF0D8},
    roleProfiles: const {
      'alice': DemoRoleProfile(
        name: '爱丽丝',
        instructions: '棕发红蝴蝶结，温暖又有主见的故事角色。',
        revision: 'alice-visual-v1',
        referenceAssetIds: ['video-v-board'],
      ),
    },
    capabilities: DemoSession.defaultCapabilities,
    memberCapabilities: const {
      'director': ['character', 'script', 'image', 'video', 'vision'],
    },
    memberSkills: const {
      'director': ['style_film'],
    },
    workMode: 'onDemand',
    activeMemberId: 'director',
    configurationStatus: 'configured',
  ),
  DemoSession(
    id: 'claude-c',
    title: 'ClaudeC',
    kind: DemoSessionKind.conversation,
    members: const ['writer'],
    roles: const [],
    messages: const [
      DemoMessage(
        id: 'claude-reply',
        memberId: 'writer',
        memberName: 'ClaudeC',
        text: '睡前故事的第十七夜已经整理好，下一步可以继续配音。',
      ),
    ],
    time: '14:30',
    updatedAt: DateTime.utc(2026, 10, 26, 6, 30),
    direction: '安静、有余韵的睡前故事。',
    positioning: '亲子与成年人的共同阅读内容。',
    accountPreferences: const {
      'feeling': '安静温柔',
      'format': '短篇故事',
      'audience': '家庭读者',
    },
    creativeMemory: const DemoCreativeMemory(text: '避免惊吓与说教，结尾留一点余韵。'),
    memberNames: const {'writer': 'ClaudeC'},
    memberInstructions: const {'writer': '写清楚、克制、适合朗读的中文故事。'},
    memberAvatars: const {'writer': 'assets/animations/bot_avatars/monkey.png'},
    memberColors: const {'writer': 0xFFFFE6F1},
    activeMemberId: 'writer',
    configurationStatus: 'configured',
  ),
  DemoSession(
    id: 'watt',
    title: 'Watt',
    kind: DemoSessionKind.conversation,
    members: const ['popi'],
    roles: const [],
    messages: const [
      DemoMessage(
        id: 'watt-reply',
        memberId: 'popi',
        memberName: 'Watt',
        text: '我会把判断写得直接，也把依据讲清楚。',
      ),
    ],
    time: '昨天',
    updatedAt: DateTime.utc(2026, 10, 25, 8),
    direction: '帮助用户判断方案，给出清楚的依据。',
    positioning: '直接但不失礼的通用工作伙伴。',
    memberNames: const {'popi': 'Watt'},
    memberInstructions: const {'popi': '先给结论，再解释关键判断。'},
    memberAvatars: const {'popi': 'assets/animations/bot_avatars/tiger.png'},
    memberColors: const {'popi': 0xFFFFFFFF},
    activeMemberId: 'popi',
    configurationStatus: 'configured',
  ),
];

Future<DemoRepository> _repository() async {
  SharedPreferences.setMockInitialValues({
    DemoRepository.storageKey: jsonEncode({
      'sessions': _sessions.map((session) => session.toJson()).toList(),
      'assets': _assets.map((asset) => asset.toJson()).toList(),
    }),
  });
  return DemoRepository(
    PreferencesStorage(await SharedPreferences.getInstance()),
  )..restore();
}

Future<void> _precacheVisuals(WidgetTester tester, BuildContext context) async {
  await tester.runAsync(
    () => Future.wait([
      for (final asset in _assets)
        precacheImage(AssetImage(asset.cover), context),
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

Future<DemoRepository> _pumpWorkspace(
  WidgetTester tester, {
  required Size size,
  required GlobalKey repaintKey,
  bool dark = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = await _repository();
  addTearDown(repository.dispose);
  final light = AppTheme.light;
  await tester.pumpWidget(
    RepaintBoundary(
      key: repaintKey,
      child: ProviderScope(
        child: ToastificationWrapper(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: !_screenshotsEnabled
                ? light
                : light.copyWith(
                    textTheme: light.textTheme.apply(
                      fontFamily: 'ThreeColumnCapture',
                    ),
                  ),
            darkTheme: !_screenshotsEnabled
                ? AppTheme.dark
                : AppTheme.dark.copyWith(
                    textTheme: AppTheme.dark.textTheme.apply(
                      fontFamily: 'ThreeColumnCapture',
                    ),
                  ),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
            locale: const Locale('zh'),
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
    ),
  );
  await tester.pumpAndSettle();
  await _precacheVisuals(tester, tester.element(find.byType(DemoHomePage)));
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  setUpAll(() async {
    if (!_screenshotsEnabled) return;
    final font = File('/System/Library/Fonts/Hiragino Sans GB.ttc');
    if (font.existsSync()) {
      await (FontLoader(
        'ThreeColumnCapture',
      )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  tearDown(() => toastification.dismissAll(delayForAnimation: false));

  for (final testCase in [
    (name: 'wide-1440', size: const Size(1440, 900)),
    (name: 'wide-1680', size: const Size(1680, 960)),
    (name: 'medium-1200', size: const Size(1200, 900)),
  ]) {
    testWidgets('desktop workspace visual ${testCase.name}', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        final repaintKey = GlobalKey();
        await _pumpWorkspace(
          tester,
          size: testCase.size,
          repaintKey: repaintKey,
        );

        expect(find.text('VideoV'), findsWidgets);
        expect(find.textContaining('夏日版', findRichText: true), findsWidgets);
        final inspector = find.byKey(const Key('demo-desktop-inspector-frame'));
        if (testCase.size.width >= 1440) {
          expect(inspector, findsOneWidget);
          expect(
            tester.getSize(inspector).width,
            testCase.size.width >= 1680 ? 360 : 320,
          );
          expect(
            find.descendant(
              of: inspector,
              matching: find.byKey(const Key('demo-inspector-instructions')),
            ),
            findsOneWidget,
          );
        } else {
          expect(inspector, findsNothing);
        }
        expect(tester.takeException(), isNull);
        await _capture(tester, repaintKey, testCase.name);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('wide inspector outputs and collapse visual remain clear', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final repaintKey = GlobalKey();
      await _pumpWorkspace(
        tester,
        size: const Size(1680, 960),
        repaintKey: repaintKey,
      );
      final inspector = find.byKey(const Key('demo-desktop-inspector-frame'));
      await tester.tap(
        find.descendant(of: inspector, matching: find.text('产物')),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future.wait([
          for (final asset in _assets.where(
            (asset) => asset.sessionId == 'video-v',
          ))
            precacheImage(
              demoAssetImageProvider(asset, cacheWidth: 800),
              tester.element(inspector),
            ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: inspector, matching: find.text('夏日故事主视觉')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await _capture(tester, repaintKey, 'wide-1680-outputs');

      await tester.tap(find.byKey(const Key('demo-inspector-close')));
      await tester.pumpAndSettle();
      expect(inspector, findsNothing);
      expect(tester.takeException(), isNull);
      await _capture(tester, repaintKey, 'wide-1680-collapsed');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('wide dark inspector keeps column and card contrast', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final repaintKey = GlobalKey();
      await _pumpWorkspace(
        tester,
        size: const Size(1440, 900),
        repaintKey: repaintKey,
        dark: true,
      );
      expect(
        find.byKey(const Key('demo-desktop-inspector-frame')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await _capture(tester, repaintKey, 'wide-1440-dark');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('mobile layout remains a single workspace', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final repaintKey = GlobalKey();
      await _pumpWorkspace(
        tester,
        size: const Size(390, 844),
        repaintKey: repaintKey,
      );

      expect(find.text('VideoV'), findsOneWidget);
      expect(
        find.byKey(const Key('demo-desktop-inspector-frame')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await _capture(tester, repaintKey, 'mobile-390');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
