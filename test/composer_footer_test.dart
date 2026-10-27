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
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_activity_indicator.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/safe_area_provider.dart';
import 'package:popi_ai_app/shared/type/bot_avatar_type.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

final _captureKey = GlobalKey();
final _captureEnabled =
    Platform.environment['MOBILE_FOOTER_SCREENSHOTS'] == '1';
const _frameKey = Key('popi-message-composer');
const _disclaimers = [
  'AI生成结果可能有误，仅供参考',
  'AI 生成结果可能有误，仅供参考',
  'AI-generated results may be inaccurate and are for reference only',
  'AI-generated results may contain errors',
];

void _expectNoDisclaimer() {
  for (final text in _disclaimers) {
    expect(find.text(text), findsNothing);
  }
}

Future<void> _configureView(
  WidgetTester tester, {
  required Size size,
  required double safeBottom,
  required double keyboard,
  double top = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: safeBottom);
  tester.view.padding = FakeViewPadding(
    top: top,
    bottom: keyboard == 0 ? safeBottom : 0,
  );
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.view.resetViewInsets);
}

Future<void> _pumpComposer(
  WidgetTester tester, {
  required double safeBottom,
  double keyboard = 0,
  Locale locale = const Locale('zh'),
  bool sessionLayout = true,
}) async {
  await _configureView(
    tester,
    size: const Size(390, 844),
    safeBottom: safeBottom,
    keyboard: keyboard,
  );
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container
      .read(safeAreaInsetsProvider.notifier)
      .update(EdgeInsets.only(bottom: safeBottom));
  final controller = PopiMessageComposerController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light.copyWith(platform: TargetPlatform.iOS),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopiMessageComposer(
                    controller: controller,
                    conversationMode: true,
                    sessionLayout: sessionLayout,
                    selectedImages: const [],
                    onAttachment: () {},
                    onRemoveImage: (_) {},
                    onHeightChanged: (_) {},
                    onSubmitted: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

DemoSession _chatSession({bool thinking = true}) => DemoSession(
  id: 'mobile-footer',
  title: 'POPi',
  kind: DemoSessionKind.conversation,
  members: const ['popi'],
  memberNames: const {'popi': 'POPi'},
  roles: thinking ? const [] : const ['alice'],
  roleProfiles: thinking
      ? const {}
      : const {
          'alice': DemoRoleProfile(
            name: 'ALICE',
            instructions: '咖啡馆短片主角',
            revision: '1',
          ),
        },
  messages: [
    const DemoMessage(id: 'user-1', text: '帮我写一个咖啡馆短片的脚本。', user: true),
    const DemoMessage(
      id: 'reply-1',
      text:
          '已经整理好故事方向：\n\n'
          '雨停后，主角推开街角咖啡馆的门，发现熟悉的位置为自己留着。'
          '我们用一个小小的误会，让故事在温暖的笑声里结束。',
      memberId: 'popi',
      activity: DemoActivity(
        kind: 'script',
        status: 'completed',
        steps: [
          DemoActivityStep(id: 'read', kind: 'thinking', status: 'completed'),
          DemoActivityStep(id: 'write', kind: 'script', status: 'completed'),
        ],
      ),
    ),
    if (thinking) ...[
      const DemoMessage(id: 'user-2', text: '再增加一个有趣的结尾。', user: true),
      const DemoMessage(
        id: 'thinking',
        text: '',
        memberId: 'popi',
        activity: DemoActivity(
          kind: 'thinking',
          status: 'running',
          steps: [
            DemoActivityStep(
              id: 'understand',
              kind: 'thinking',
              status: 'running',
            ),
          ],
        ),
      ),
    ],
  ],
);

Future<void> _pumpChat(
  WidgetTester tester, {
  Size size = const Size(393, 852),
  TargetPlatform platform = TargetPlatform.iOS,
  double safeBottom = 34,
  double keyboard = 0,
  bool dark = false,
  double textScale = 1,
}) async {
  await _configureView(
    tester,
    size: size,
    safeBottom: safeBottom,
    keyboard: keyboard,
    top: platform == TargetPlatform.iOS ? 54 : 24,
  );
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container
      .read(safeAreaInsetsProvider.notifier)
      .update(EdgeInsets.only(bottom: safeBottom));
  SharedPreferences.setMockInitialValues({
    DemoRepository.storageKey: jsonEncode({
      'sessions': [_chatSession(thinking: keyboard == 0).toJson()],
      'assets': const [],
    }),
  });
  final repository = DemoRepository(
    PreferencesStorage(await SharedPreferences.getInstance()),
  )..restore();
  addTearDown(repository.dispose);
  var theme = (dark ? AppTheme.dark : AppTheme.light).copyWith(
    platform: platform,
    scaffoldBackgroundColor: dark
        ? AppTheme.dark.scaffoldBackgroundColor
        : AppColors.profileBackground,
  );
  if (_captureEnabled) {
    theme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: 'MobileFooterCapture'),
    );
  }
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: UncontrolledProviderScope(
        container: container,
        child: ToastificationWrapper(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: TextScaler.linear(textScale),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  child!,
                  if (keyboard > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: keyboard,
                      child: ColoredBox(
                        color: dark
                            ? const Color(0xFF242424)
                            : const Color(0xFFD5D8DD),
                        child: Center(
                          child: Text(
                            'Keyboard',
                            style: TextStyle(
                              fontFamily: _captureEnabled
                                  ? 'MobileFooterCapture'
                                  : null,
                              fontSize: 14,
                              color: dark ? Colors.white54 : Colors.black45,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (safeBottom > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: Center(
                        child: Container(
                          width: 134,
                          height: 5,
                          decoration: BoxDecoration(
                            color: dark ? Colors.white : Colors.black,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            home: DemoChatPage(
              repository: repository,
              sessionId: 'mobile-footer',
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (keyboard == 0) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
  }
  if (keyboard > 0) {
    final composer = tester.widget<PopiMessageComposer>(
      find.byType(PopiMessageComposer),
    );
    await composer.controller.setText('这个结尾再温暖一点。');
    await tester.pumpAndSettle();
  }
  if (_captureEnabled) {
    await tester.runAsync(
      () => Future.wait([
        precacheImage(
          AssetImage(BotAvatarCharacter.tiger.stillAsset),
          tester.element(find.byType(DemoChatPage)),
        ),
        if (keyboard > 0)
          precacheImage(
            const AssetImage('assets/images/demo_role_1.png'),
            tester.element(find.byType(DemoChatPage)),
          ),
      ]),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (!_captureEnabled) return;
  if (name == 'keyboard') {
    final paragraph = tester.renderObject<RenderParagraph>(find.text('ALICE'));
    final span = paragraph.text as TextSpan;
    // Buttons use the platform's default font on device; the test engine's
    // default is Ahem. Resolve it only in the optional capture host.
    paragraph.text = TextSpan(
      text: span.text,
      children: span.children,
      style: (span.style ?? const TextStyle()).copyWith(
        fontFamily: 'MobileFooterCapture',
      ),
    );
    await tester.pump();
  }
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/mobile-chat-footer/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  tearDown(() => toastification.dismissAll(delayForAnimation: false));
  setUpAll(() async {
    if (!_captureEnabled) return;
    final fontBytes = await File(
      '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
    ).readAsBytes();
    final font = FontLoader('MobileFooterCapture')
      ..addFont(Future.value(ByteData.sublistView(fontBytes)));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final locale in [const Locale('zh'), const Locale('en')]) {
    for (final sessionLayout in [true, false]) {
      testWidgets(
        'shared ${locale.languageCode} composer has no footer in sessionLayout=$sessionLayout',
        (tester) async {
          await _pumpComposer(
            tester,
            safeBottom: 0,
            locale: locale,
            sessionLayout: sessionLayout,
          );
          _expectNoDisclaimer();
          expect(
            844 - tester.getRect(find.byKey(_frameKey)).bottom,
            closeTo(8, .1),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final scenario in [
    (name: 'safe area', safeBottom: 34.0, keyboard: 0.0, expected: 42.0),
    (name: 'keyboard', safeBottom: 34.0, keyboard: 300.0, expected: 8.0),
  ]) {
    testWidgets(
      'shared composer keeps one safe-area reserve and visual gap for ${scenario.name}',
      (tester) async {
        await _pumpComposer(
          tester,
          safeBottom: scenario.safeBottom,
          keyboard: scenario.keyboard,
        );
        _expectNoDisclaimer();
        final frame = tester.getRect(find.byKey(_frameKey));
        expect(
          844 - scenario.keyboard - frame.bottom,
          closeTo(scenario.expected, .1),
        );
        expect(
          tester.getSize(find.byType(PopiMessageComposer)).height -
              frame.height,
          closeTo(8 + scenario.expected, .1),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scenario in [
    (
      name: 'iphone',
      size: const Size(393, 852),
      platform: TargetPlatform.iOS,
      safeBottom: 34.0,
      keyboard: 0.0,
      dark: false,
      scale: 1.0,
    ),
    (
      name: 'android',
      size: const Size(393, 852),
      platform: TargetPlatform.android,
      safeBottom: 0.0,
      keyboard: 0.0,
      dark: false,
      scale: 1.0,
    ),
    (
      name: 'keyboard',
      size: const Size(393, 852),
      platform: TargetPlatform.iOS,
      safeBottom: 34.0,
      keyboard: 300.0,
      dark: false,
      scale: 1.0,
    ),
    (
      name: 'dark',
      size: const Size(393, 852),
      platform: TargetPlatform.iOS,
      safeBottom: 34.0,
      keyboard: 0.0,
      dark: true,
      scale: 1.0,
    ),
    (
      name: 'compact',
      size: const Size(320, 640),
      platform: TargetPlatform.iOS,
      safeBottom: 34.0,
      keyboard: 0.0,
      dark: false,
      scale: 1.5,
    ),
  ]) {
    testWidgets('${scenario.name} chat keeps its input near the safe bottom', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = scenario.platform;
      try {
        await _pumpChat(
          tester,
          size: scenario.size,
          platform: scenario.platform,
          safeBottom: scenario.safeBottom,
          keyboard: scenario.keyboard,
          dark: scenario.dark,
          textScale: scenario.scale,
        );
        _expectNoDisclaimer();
        final expectedGap = scenario.keyboard > 0
            ? 8.0
            : scenario.safeBottom + 8;
        expect(
          scenario.size.height -
              scenario.keyboard -
              tester.getRect(find.byKey(_frameKey)).bottom,
          closeTo(expectedGap, 1),
        );
        if (scenario.keyboard == 0) {
          expect(find.byType(DemoActivityIndicator), findsWidgets);
          expect(find.text('正在思考你的内容'), findsOneWidget);
          expect(find.byKey(const Key('demo-activity-avatar')), findsWidgets);
        }
        expect(tester.takeException(), isNull);
        await _capture(tester, scenario.name);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
