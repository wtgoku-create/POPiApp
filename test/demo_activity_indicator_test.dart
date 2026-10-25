import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_activity_indicator.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_generation_indicator.dart';
import 'package:popi_ai_app/shared/widgets/app_svg_icon.dart';

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
  bool expanded = false,
  bool dark = false,
  bool reducedMotion = true,
  double scale = 1,
  Size size = const Size(440, 956),
  VoidCallback? onToggle,
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
                    DemoActivityIndicator(
                      activity: activity,
                      memberName: 'POPi',
                      expanded: expanded,
                      onToggle: () {
                        onToggle?.call();
                        setState(() => expanded = !expanded);
                      },
                    ),
                    if (scene) ...[
                      const SizedBox(height: 16),
                      const Text(
                        '收到，我会根据兜兜的人物与人设，围绕当前选题整理创作方案。'
                        '采用安静认真、反应慢但责任心强的表达风格，'
                        '用具体行动完成承诺，陪它发现不起眼的温柔。',
                        style: TextStyle(fontSize: 18, height: 1.65),
                      ),
                    ],
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
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('each public stage uses its matching artwork', (tester) async {
    for (final (kind, asset) in [
      ('thinking', null),
      ('search', 'demo_search'),
      ('fetch', 'demo_search'),
      ('image', 'demo_image'),
      ('video', 'demo_video'),
      ('script', 'session_artifact_script'),
      ('audio', 'demo_audio'),
    ]) {
      await _pump(
        tester,
        activity: DemoActivity(kind: kind, status: 'running'),
      );
      if (asset == null) {
        expect(find.byType(AppGenerationIndicator), findsOneWidget);
      } else {
        expect(
          tester
              .widgetList<AppSvgIcon>(find.byType(AppSvgIcon))
              .map((icon) => icon.assetName),
          contains(asset),
        );
      }
      expect(find.byKey(const Key('demo-activity-toggle')), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('steps expand and collapse using mouse or keyboard', (
    tester,
  ) async {
    var toggles = 0;
    await _pump(tester, onToggle: () => toggles++);
    expect(find.byKey(const Key('demo-activity-steps')), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(toggles, 1);
    expect(find.text('正在调用模型'), findsOneWidget);
    expect(find.text('编写剧本'), findsOneWidget);
    await tester.tap(find.byKey(const Key('demo-activity-toggle')));
    await tester.pump();
    expect(toggles, 2);
    expect(find.byKey(const Key('demo-activity-steps')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('finished and waiting stages never retain running animation', (
    tester,
  ) async {
    for (final status in ['completed', 'failed', 'stopped', 'waiting_user']) {
      await _pump(
        tester,
        activity: DemoActivity(kind: 'thinking', status: status, steps: _steps),
        expanded: true,
        reducedMotion: false,
      );
      expect(
        tester
            .widget<AppGenerationIndicator>(find.byType(AppGenerationIndicator))
            .animated,
        isFalse,
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    }
  });

  for (final (name, kind, expanded, dark, size, scale) in [
    ('thinking', 'thinking', true, false, const Size(440, 956), 1.0),
    ('search', 'search', false, false, const Size(440, 380), 1.0),
    ('image', 'image', false, false, const Size(440, 380), 1.0),
    ('video', 'video', false, false, const Size(440, 380), 1.0),
    ('script', 'script', false, false, const Size(440, 380), 1.0),
    ('dark', 'thinking', true, true, const Size(440, 956), 1.0),
    ('mobile', 'thinking', true, false, const Size(320, 844), 1.5),
  ]) {
    testWidgets('$name layout and reduced motion', (tester) async {
      await _pump(
        tester,
        activity: DemoActivity(kind: kind, status: 'running', steps: _steps),
        expanded: expanded,
        dark: dark,
        size: size,
        scale: scale,
        scene: expanded,
      );
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
      await _capture(tester, name);
    });
  }
}
