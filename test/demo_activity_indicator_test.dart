import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_activity_indicator.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_widgets.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/type/bot_avatar_type.dart';
import 'package:popi_ai_app/shared/widgets/app_generation_indicator.dart';

final _captureKey = GlobalKey();
final _capturesEnabled =
    Platform.environment['CHAT_ACTIVITY_SCREENSHOTS'] == '1';
const _steps = [
  DemoActivityStep(id: 'thinking', kind: 'thinking', status: 'completed'),
  DemoActivityStep(id: 'model', kind: 'model', status: 'completed'),
  DemoActivityStep(id: 'script', kind: 'script', status: 'running'),
];

Future<void> _pump(
  WidgetTester tester, {
  DemoActivity activity = const DemoActivity(
    kind: 'thinking',
    status: 'running',
    steps: _steps,
  ),
  bool dark = false,
  bool reducedMotion = true,
  double scale = 1,
  Size size = const Size(440, 956),
  bool scene = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final theme = dark ? AppTheme.dark : AppTheme.light;
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _capturesEnabled
            ? theme.copyWith(
                textTheme: theme.textTheme.apply(fontFamily: 'ActivityCapture'),
              )
            : theme,
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reducedMotion,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: StatefulBuilder(
                builder: (context, setState) => ListView(
                  children: [
                    if (scene) ...[
                      const SizedBox(height: 80),
                      const Text(
                        '你需要做一个什么样的角色？',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Align(
                        alignment: Alignment.centerRight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              '我想制作一个可爱的萌宠角色',
                              style: TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                    if (scene) ...[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(20),
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: _CaptureAssistantReply(),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    DemoActivityIndicator(
                      activity: activity,
                      memberName: '兜兜',
                      avatar: const DemoAvatar(
                        image: 'assets/animations/bot_avatars/rabbit.png',
                        background: Color(0xFFFFE9B8),
                        size: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _CaptureAssistantReply extends StatelessWidget {
  const _CaptureAssistantReply();

  @override
  Widget build(BuildContext context) => Text(
    '收到，我会根据兜兜的人物与人设，围绕当前选题整理创作方案。'
    '我先整理剧本与分镜，再给你确认。',
    style: TextStyle(
      fontSize: 16,
      height: 1.5,
      color: Theme.of(context).colorScheme.onSurface,
    ),
  );
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_capturesEnabled) return;
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/chat-activity/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUpAll(() async {
    if (!_capturesEnabled) return;
    final fontFile = File(
      '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
    );
    if (fontFile.existsSync()) {
      await (FontLoader(
        'ActivityCapture',
      )..addFont(fontFile.readAsBytes().then(ByteData.sublistView))).load();
    }
  });

  testWidgets('every public stage keeps the supplied assistant avatar', (
    tester,
  ) async {
    for (final (kind, label) in [
      ('thinking', '正在思考你的内容'),
      ('search', '正在搜索资料'),
      ('fetch', '正在阅读网页'),
      ('image', '正在生成图片'),
      ('video', '正在生成视频'),
      ('script', '编写剧本'),
      ('audio', '正在生成音频'),
    ]) {
      await _pump(
        tester,
        activity: DemoActivity(kind: kind, status: 'running'),
      );
      final avatar = tester.widget<DemoAvatar>(find.byType(DemoAvatar));
      expect(avatar.image, BotAvatarCharacter.rabbit.stillAsset);
      expect(find.text(label), findsOneWidget);
      expect(find.byType(AppGenerationIndicator), findsNothing);
      expect(find.byKey(const Key('demo-activity-toggle')), findsNothing);
      expect(find.byKey(const Key('demo-activity-steps')), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('private execution steps never become an expandable chain', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(const Key('demo-activity-steps')), findsNothing);
    expect(find.byKey(const Key('demo-activity-toggle')), findsNothing);
    expect(find.text('正在调用模型'), findsNothing);
    final label = tester.widget<Text>(
      find.byKey(const Key('demo-activity-label')),
    );
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
    expect(label.style?.fontSize, 14);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finished and waiting stages keep a compact public status', (
    tester,
  ) async {
    for (final (status, label) in [
      ('completed', '已完成'),
      ('failed', '执行失败'),
      ('stopped', '已停止回复'),
      ('waiting_user', '等待你补充或确认…'),
    ]) {
      await _pump(
        tester,
        activity: DemoActivity(kind: 'thinking', status: status, steps: _steps),
        reducedMotion: false,
      );
      expect(find.text(label), findsOneWidget);
      expect(find.byType(AppGenerationIndicator), findsNothing);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    }
  });

  for (final (name, kind, dark, size, scale) in [
    ('desktop', 'thinking', false, const Size(440, 956), 1.0),
    ('search', 'search', false, const Size(440, 380), 1.0),
    ('image', 'image', false, const Size(440, 380), 1.0),
    ('video', 'video', false, const Size(440, 380), 1.0),
    ('script', 'script', false, const Size(440, 380), 1.0),
    ('dark', 'thinking', true, const Size(440, 956), 1.0),
    ('mobile', 'thinking', false, const Size(320, 844), 1.5),
  ]) {
    testWidgets('$name layout and reduced motion', (tester) async {
      await _pump(
        tester,
        activity: DemoActivity(kind: kind, status: 'running', steps: _steps),
        dark: dark,
        size: size,
        scale: scale,
        scene: name == 'desktop' || name == 'dark' || name == 'mobile',
      );
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
      await _capture(tester, name);
    });
  }
}
