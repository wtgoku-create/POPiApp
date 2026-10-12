import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/session/presentation/conversation_controller.dart';
import 'package:popi_ai_app/features/session/presentation/session_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_timeline.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/session_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

import 'conversation_controller_test.dart' show StreamingSessionRepository;
import 'conversation_events_test.dart'
    show chatId, chatEvent, chatMessageJson, chatSnapshotJson;

final _captureKey = GlobalKey();
final _captureDirectory = Platform.environment['CHAT_UX_SCREENSHOTS'];

Future<void> _capture(WidgetTester tester, String name) async {
  if (_captureDirectory == null) return;
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(_captureDirectory!).create(recursive: true);
    await File(
      '$_captureDirectory/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Map<String, Object?> _topic(
  String id, {
  String scopeId = '301',
  String action = 'generated',
  String? title,
}) => {
  'type': 'object',
  'kind': 'topic',
  'action': action,
  'scope': {'kind': 'creation', 'id': scopeId},
  'data': {
    'ref': {'kind': 'topic', 'id': id},
    'title': title ?? 'Topic $id',
    'summary':
        '### 故事梗概\n\nStory $id\n\n'
        '### 适合角色的原因\n\nA warm, quiet afternoon together.\n\n'
        '### 核心看点\n\nA playful moment in a familiar home.',
  },
};

Future<StreamingSessionRepository> _pumpTopicPage(
  WidgetTester tester,
  List<Map<String, Object?>> blocks, {
  Size size = const Size(390, 844),
  Locale locale = const Locale('zh'),
  bool dark = false,
  double scale = 1,
  bool sentByUser = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = StreamingSessionRepository()
    ..data = chatSnapshotJson(
      seq: 1,
      messages: [
        {
          ...chatMessageJson(),
          if (sentByUser) 'role': 'user',
          'blocks': blocks,
        },
      ],
    );
  final container = ProviderContainer(
    overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(() async {
    container.dispose();
    await repository.close();
  });
  await container
      .read(userProvider.notifier)
      .setUser(const User(id: 'a', name: 'User', email: ''));
  final theme = dark ? AppTheme.dark : AppTheme.light;
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _captureDirectory == null
              ? theme
              : theme.copyWith(
                  textTheme: theme.textTheme.apply(fontFamily: 'ChatCapture'),
                ),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: const SessionPage(sessionId: chatId),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  setUpAll(() async {
    // Optional local captures use a real CJK font; CI has no system-font dependency.
    if (_captureDirectory != null) {
      final font = FontLoader('ChatCapture');
      font.addFont(
        File(
          '/System/Library/Fonts/Supplemental/Arial Unicode.ttf',
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });

  for (final (name, size, locale, dark, scale) in [
    ('mobile', const Size(390, 844), const Locale('zh'), false, 1.0),
    ('desktop', const Size(1280, 900), const Locale('en'), false, 1.0),
    ('accessible-dark', const Size(320, 844), const Locale('en'), true, 1.5),
  ]) {
    testWidgets('topics share one card and retain the selected item at $name', (
      tester,
    ) async {
      final title = locale.languageCode == 'zh'
          ? '来财的专属晒太阳角落'
          : 'A quiet afternoon in a sunny cardboard home';
      final topics = [_topic('1', title: title), _topic('2'), _topic('3')];
      const intro = {'type': 'text', 'text': 'Recommendations'};
      const ending = {'type': 'text', 'text': 'Choose your favorite story.'};
      final repository = await _pumpTopicPage(
        tester,
        [intro, ...topics, ending],
        size: size,
        locale: locale,
        dark: dark,
        scale: scale,
      );
      final previous = find.byKey(const Key('conversation-topic-previous'));
      final next = find.byKey(const Key('conversation-topic-next'));
      expect(find.byType(ConversationObjectView), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('Story 1'), findsOneWidget);
      expect(find.text('Story 2'), findsNothing);
      expect(tester.widget<IconButton>(previous).onPressed, isNull);
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      final card = tester.getRect(find.byType(ConversationObjectView));
      final button = tester.getRect(next);
      expect(button.right, closeTo(card.right - 20, .01));
      expect(button.top, closeTo(card.top + 24, .01));
      expect(
        button.center.dx - tester.getCenter(previous).dx,
        closeTo(24, .01),
      );
      await _capture(tester, '$name-topics-first');
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('Story 1'), findsNothing);
      expect(find.text('Story 2'), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);
      await _capture(tester, '$name-topics-second');
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('3/3'), findsOneWidget);
      expect(tester.widget<IconButton>(next).onPressed, isNull);
      await tester.tap(previous);
      await tester.pumpAndSettle();
      repository.streams.first.add(
        chatEvent(2, 'message.updated', {
          'timelineUpdates': [
            {
              ...chatMessageJson(revision: 2),
              'blocks': [
                intro,
                _topic('2', title: 'Updated topic 2'),
                topics[2],
                topics[0],
                ending,
              ],
            },
          ],
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Updated topic 2'), findsOneWidget);
      expect(find.text('Story 2'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      repository.streams.first.add(
        chatEvent(3, 'message.updated', {
          'timelineUpdates': [
            {
              ...chatMessageJson(revision: 3),
              'blocks': [intro, topics[0], ending],
            },
          ],
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Story 1'), findsOneWidget);
      expect(next, findsNothing);
      expect(previous, findsNothing);
      expect(find.text('Recommendations'), findsOneWidget);
      expect(find.text('Choose your favorite story.'), findsOneWidget);
      expect(repository.sends, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Web role card collapse survives streamed updates at $name', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final role = <String, Object?>{
        'id': 'role-draft',
        'title': locale.languageCode == 'zh'
            ? '校园爱丽丝'
            : 'Alice in the schoolyard',
        'status': 'draft',
        'profile': {
          'description': locale.languageCode == 'zh'
              ? '叮叮的同桌、室友和闺蜜。'
              : 'A classmate, roommate and close friend.',
          'expressionStyle': locale.languageCode == 'zh'
              ? '轻松日常，略带幽默'
              : 'Relaxed, warm and a little witty',
          'targetAudience': locale.languageCode == 'zh'
              ? '校园故事的读者'
              : 'Readers of school stories',
          'contentTags': ['校园', '可爱角色'],
          'profileData': {
            'personality': {'label': '性格', 'value': '认真、温柔'},
          },
        },
      };
      Map<String, Object?> roleMessage(int revision) => {
        ...chatMessageJson(revision: revision, seq: 2),
        'blocks': [
          {'type': 'object', 'kind': 'role', 'action': 'created', 'data': role},
        ],
      };
      final repository = StreamingSessionRepository()
        ..data = chatSnapshotJson(
          seq: 2,
          messages: [
            {
              ...chatMessageJson(
                text: locale.languageCode == 'zh'
                    ? '我想制作一个可爱的萌宠角色'
                    : 'Create a friendly character for my story.',
              ),
              'id': 'user-message',
              'role': 'user',
            },
            roleMessage(1),
          ],
        );
      final container = ProviderContainer(
        overrides: [sessionRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(() async {
        container.dispose();
        await repository.close();
      });
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: 'a', name: 'User', email: ''));
      final theme = dark ? AppTheme.dark : AppTheme.light;
      await tester.pumpWidget(
        RepaintBoundary(
          key: _captureKey,
          child: UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: _captureDirectory == null
                  ? theme
                  : theme.copyWith(
                      textTheme: theme.textTheme.apply(
                        fontFamily: 'ChatCapture',
                      ),
                    ),
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const SessionPage(sessionId: chatId),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final toggle = find.byKey(const Key('conversation-role-toggle'));
      final preview = find.byKey(const Key('conversation-role-view-profile'));
      expect(find.text('校园, 可爱角色'), findsOneWidget);
      expect(find.text('认真、温柔'), findsOneWidget);
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await _capture(tester, '$name-draft');
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('校园, 可爱角色'), findsNothing);
      role['title'] = 'Updated Alice';
      repository.streams.first.add(
        chatEvent(3, 'message.updated', {
          'timelineUpdates': [roleMessage(2)],
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Updated Alice'), findsNothing);
      expect(find.text('校园, 可爱角色'), findsNothing);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('Updated Alice'), findsOneWidget);
      await tester.ensureVisible(preview);
      await tester.pumpAndSettle();
      await tester.tap(preview);
      await tester.pumpAndSettle();
      final sheet = find.byKey(const Key('conversation-role-profile'));
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('Updated Alice')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.descendant(of: sheet, matching: find.text('认真、温柔')),
        150,
        scrollable: find
            .descendant(of: sheet, matching: find.byType(Scrollable))
            .first,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('认真、温柔')),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(find.text('校园, 可爱角色'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('user role objects use full card width outside the text bubble', (
    tester,
  ) async {
    await _pumpTopicPage(tester, [
      {'type': 'text', 'text': 'Use this character'},
      {
        'type': 'object',
        'kind': 'role',
        'action': 'created',
        'data': {'title': 'Saved draft', 'status': 'draft'},
      },
    ], sentByUser: true);
    final card = tester.getRect(
      find.byKey(const Key('conversation-role-card')),
    );
    expect(card.left, closeTo(20, .01));
    expect(card.width, closeTo(350, .01));
    final text = tester.getRect(find.text('Use this character'));
    expect(text.right, lessThanOrEqualTo(card.right));
    expect(text.bottom, lessThan(card.top));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('topic groups preserve text boundaries, scopes and selections', (
    tester,
  ) async {
    await _pumpTopicPage(tester, [
      _topic('1'),
      _topic('2'),
      {'type': 'text', 'text': 'Another batch'},
      _topic('3'),
      _topic('4', scopeId: '302'),
      _topic('5', action: 'selected'),
    ]);
    expect(find.byType(ConversationObjectView), findsNWidgets(4));
    expect(find.byKey(const Key('conversation-topic-next')), findsOneWidget);
    expect(find.text('Topic 2'), findsNothing);
    expect(find.text('Topic 3'), findsOneWidget);
    expect(find.text('Topic 4'), findsOneWidget);
    expect(find.text('Topic 5'), findsOneWidget);
    expect(find.text('Another batch'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'progress collapses and generation uses the shared confirmation dialog',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = StreamingSessionRepository();
      final controller = ConversationController(repository, 'a');
      addTearDown(() async {
        controller.dispose();
        await repository.close();
      });
      final progress = ConversationBlock.fromJson({
        'type': 'object',
        'kind': 'progress',
        'data': {
          'state': 'running',
          'steps': [
            {'labelKey': 'script.run.preparing', 'status': 'completed'},
            {
              'labelKey': 'pages.studio.progress.readRole',
              'status': 'completed',
            },
            {'labelKey': 'script.run.generatingReply', 'status': 'running'},
          ],
        },
      });
      final plan = ConversationBlock.fromJson({
        'type': 'object',
        'kind': 'plan',
        'data': {
          'id': 'plan',
          'title': '角色图生成方案',
          'status': 'ready',
          'body': '让校园爱丽丝穿着校服，站在温暖的校园里。',
          'estimatedPoints': 675,
          'allowedActions': ['confirm', 'cancel'],
        },
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: _captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _captureDirectory == null
                ? AppTheme.light
                : AppTheme.light.copyWith(
                    textTheme: AppTheme.light.textTheme.apply(
                      fontFamily: 'ChatCapture',
                    ),
                  ),
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFEDE9FD), Colors.white],
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const SizedBox(height: 40),
                    ConversationObjectView(
                      block: progress,
                      controller: controller,
                    ),
                    ConversationObjectView(block: plan, controller: controller),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('正在读取角色档案'), findsOneWidget);
      await _capture(tester, 'mobile-progress-plan');
      await tester.tap(find.byTooltip('收起进度'));
      await tester.pump();
      expect(find.text('正在读取角色档案'), findsNothing);
      await tester.tap(find.text('确认生成'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, '取消').last);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
