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
    testWidgets('role expansion survives streamed updates at $name', (
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
      final expand = find.text(
        locale.languageCode == 'zh'
            ? '查看完整角色档案'
            : 'View full character profile',
      );
      await tester.ensureVisible(expand);
      await tester.pumpAndSettle();
      await _capture(tester, '$name-draft');
      await tester.tap(expand);
      await tester.pumpAndSettle();
      expect(find.text('校园, 可爱角色'), findsOneWidget);
      role['title'] = 'Updated Alice';
      repository.streams.first.add(
        chatEvent(3, 'message.updated', {
          'timelineUpdates': [roleMessage(2)],
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('Updated Alice'), findsOneWidget);
      expect(find.text('校园, 可爱角色'), findsOneWidget);
      final collapse = find.text(
        locale.languageCode == 'zh' ? '收起档案' : 'Collapse profile',
      );
      await tester.ensureVisible(collapse);
      await tester.pumpAndSettle();
      await tester.tap(collapse);
      await tester.pumpAndSettle();
      expect(find.text('校园, 可爱角色'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

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
