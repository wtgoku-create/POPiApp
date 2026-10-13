import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/session/data/session_repository.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/session/domain/conversation_task.dart';
import 'package:popi_ai_app/features/session/presentation/conversation_controller.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_card_content.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_task_card.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_timeline.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_network_image.dart';
import 'package:popi_ai_app/shared/widgets/app_video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'conversation_events_test.dart' show chatMessageJson, chatSnapshotJson;
import 'support/fake_video_player.dart';
import 'support/session_fixtures.dart';

Map<String, Object?> _task({
  String state = 'completed',
  String mediaType = 'image',
  List<Map<String, Object?>>? outputs,
}) => {
  'type': 'object',
  'kind': 'task',
  'action': 'generation',
  'data': {
    'id': 'generation',
    'state': state,
    'mediaType': mediaType,
    'confirmationId': 'confirmation',
    'outputs':
        outputs ??
        [
          {'kind': 'media', 'id': 'output'},
        ],
    'configuration': '模型：saved-model\n比例：16:9',
    'estimatedPoints': 12,
    'plan': {
      'items': [
        {
          'key': 'three_view',
          'mediaType': mediaType,
          'modelId': 'saved-model',
          'params': {'ratio': '16:9'},
          'prompt': 'Final saved prompt',
        },
      ],
    },
  },
};

Map<String, Object?> _content({
  String id = 'content',
  String mediaId = 'output',
  String action = 'generated',
  String version = 'v1',
}) => {
  'type': 'object',
  'kind': 'content',
  'action': action,
  'data': {
    'id': id,
    'ref': {'kind': 'content', 'id': id, 'versionId': version},
    'kind': 'image',
    'title': '生成结果',
    'mediaIds': [mediaId],
    'status': 'completed',
    'editable': false,
  },
};

Map<String, Object?> _message(
  int seq,
  List<Map<String, Object?>> blocks, {
  String role = 'assistant',
}) => {
  ...chatMessageJson(seq: seq),
  'id': 'message-$seq',
  'role': role,
  'blocks': blocks,
};

ConversationSnapshot _snapshot(
  List<Map<String, Object?>> messages, {
  List<Map<String, Object?>> contents = const [],
}) => ConversationSnapshot.fromJson({
  ...chatSnapshotJson(seq: messages.length, messages: messages),
  'contents': contents,
});

class _Images extends Fake implements BaseCacheManager {
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    yield FileInfo(
      const LocalFileSystem().file('assets/images/home_welcome_character.png'),
      FileSource.Cache,
      DateTime(2099),
      url,
    );
  }
}

class _Repository extends FixtureSessionRepository {
  String kind = 'image';
  @override
  Future<ConversationMedia> media(
    String id, {
    CancelToken? cancelToken,
  }) async => ConversationMedia(
    id: id,
    kind: kind,
    url: 'https://example.com/$id.${kind == 'video' ? 'mp4' : 'png'}',
  );
}

class _Controller extends ConversationController {
  _Controller(super.repository, super.userId);
  void publish(ConversationSnapshot value) {
    snapshot = value;
    notifyListeners();
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
  bool dark = false,
  GlobalKey? capture,
}) async {
  final theme = dark ? AppTheme.dark : AppTheme.light;
  await tester.pumpWidget(
    MaterialApp(
      theme: const String.fromEnvironment('CONVERSATION_CAPTURE_FONT').isEmpty
          ? theme
          : theme.copyWith(
              textTheme: theme.textTheme.apply(fontFamily: 'GenerationCapture'),
            ),
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: TextScaler.linear(scale),
        ),
        child: RepaintBoundary(key: capture, child: child!),
      ),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 660),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_CONVERSATION_CARDS')) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '/tmp/conversation-generation-task-$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    const path = String.fromEnvironment('CONVERSATION_CAPTURE_FONT');
    if (path.isEmpty) return;
    await (FontLoader(
      'GenerationCapture',
    )..addFont(File(path).readAsBytes().then(ByteData.sublistView))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() {
    AppImageCache.debugCacheManager = _Images();
    addTearDown(() {
      AppImageCache.debugCacheManager = null;
    });
  });

  test(
    'generated result is rendered only in its task while source stays intact',
    () {
      final snapshot = _snapshot([
        _message(1, [_task()]),
        _message(2, [_content()]),
      ]);
      expect(snapshot.messages, hasLength(2));
      expect(snapshot.presentationMessages, hasLength(1));
      expect(
        ConversationGenerationTaskView(
          snapshot.messages.first.blocks.single,
          snapshot,
        ).mediaIds,
        ['output'],
      );
    },
  );

  test('mixed messages preserve text, unrelated content and user input', () {
    final snapshot = _snapshot([
      _message(1, [_task()]),
      _message(2, [
        {'type': 'text', 'text': 'Completed'},
        _content(),
        _content(id: 'other', mediaId: 'other'),
        _content(action: 'edited'),
      ]),
      _message(3, [_content()], role: 'user'),
    ]);
    final message = snapshot.presentationMessages[1];
    expect(message.id, 'message-2');
    expect(message.seq, 2);
    expect(message.revision, 1);
    expect(message.text, 'Completed');
    expect(message.blocks, hasLength(3));
    expect(snapshot.presentationMessages.last.blocks, hasLength(1));
  });

  test('content references resolve exact versions in source and timeline', () {
    final task = _task(
      outputs: [
        {'kind': 'content', 'id': 'content', 'versionId': 'v1'},
      ],
    );
    final result = _content();
    final snapshot = _snapshot(
      [
        _message(1, [task]),
        _message(2, [result]),
        _message(3, [_content(mediaId: 'new-output', version: 'v2')]),
      ],
      contents: [result['data']! as Map<String, Object?>],
    );
    expect(
      ConversationGenerationTaskView(
        snapshot.messages.first.blocks.single,
        snapshot,
      ).mediaIds,
      ['output'],
    );
    expect(snapshot.presentationMessages.map((message) => message.id), [
      'message-1',
      'message-3',
    ]);
    expect(
      conversationReferenceMatches(
        {'kind': 'media', 'id': 'content'},
        {'kind': 'content', 'id': 'content'},
      ),
      isFalse,
    );
  });

  test('result stays visible until the late task output update arrives', () {
    final messages = [
      _message(1, [_task(state: 'running', outputs: [])]),
      _message(2, [_content()]),
    ];
    expect(_snapshot(messages).presentationMessages, hasLength(2));
    messages[0] = _message(1, [_task()]);
    expect(_snapshot(messages).presentationMessages, hasLength(1));
  });

  test(
    'saved task plan prefers decision and recovers matching role version',
    () {
      final confirmation = {
        'id': 'confirmation',
        'status': 'confirmed',
        'targetRef': {'kind': 'role', 'id': 'role', 'versionId': 'v1'},
        'roleTemplate': {'id': 'style', 'title': 'Saved style'},
        'configuration': 'old config',
      };
      final snapshot = _snapshot([
        _message(1, [
          {
            'type': 'object',
            'kind': 'role',
            'data': {
              'id': 'role',
              'ref': {'kind': 'role', 'id': 'role', 'versionId': 'v1'},
              'title': 'Saved role',
            },
          },
        ]),
        _message(2, [
          {
            'type': 'object',
            'kind': 'generation_decision',
            'action': 'confirm',
            'data': confirmation,
          },
        ]),
        _message(3, [
          {
            'type': 'object',
            'kind': 'plan',
            'data': {
              ...confirmation,
              'roleTemplate': {'title': 'Other style'},
            },
          },
        ]),
        _message(4, [_task()]),
        _message(5, [
          {
            'type': 'object',
            'kind': 'role',
            'data': {
              'id': 'role',
              'ref': {'kind': 'role', 'id': 'role'},
              'title': 'Unversioned role',
            },
          },
        ]),
      ]);
      final plan = ConversationGenerationTaskView(
        snapshot.messages[3].blocks.single,
        snapshot,
      ).fixedPlan!;
      expect(plan.previewRole!.title, 'Saved role');
      expect(plan.data['roleTemplate'], {
        'id': 'style',
        'title': 'Saved style',
      });
      expect(plan.configuration, '模型：saved-model\n比例：16:9');
      expect(plan.planPrompts, ['Final saved prompt']);
      expect(plan.allowedActions, isEmpty);
      expect(plan.estimatedPoints, 12);
    },
  );

  for (final state in [
    'queued',
    'pending',
    'running',
    'waiting_external',
    'saving',
    'resuming',
    'pause_requested',
  ]) {
    test('generation state $state stays active', () {
      expect(
        ConversationGenerationTaskView(
          ConversationBlock.fromJson(_task(state: state)),
          null,
        ).active,
        isTrue,
      );
    });
  }

  for (final width in [320.0, 390.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('generation placeholder fits $width with text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = ConversationController(_Repository(), 'user');
        addTearDown(controller.dispose);
        final capture = GlobalKey();
        await _pump(
          tester,
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ConversationTaskCard(
                block: ConversationBlock.fromJson(_task(state: 'running')),
                controller: controller,
              ),
            ],
          ),
          scale: scale,
          capture: capture,
        );
        expect(find.text('任务正在生成...'), findsOneWidget);
        expect(
          find.byKey(const Key('conversation-generation-placeholder')),
          findsOneWidget,
        );
        expect(find.byType(ConversationMediaView), findsNothing);
        expect(tester.takeException(), isNull);
        await _capture(tester, capture, 'loading-${width.toInt()}-$scale');
      });
    }
  }

  testWidgets('history shows one output card and folded saved plan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _Repository();
    final controller = ConversationController(repository, 'user')
      ..snapshot = _snapshot([
        _message(1, [_task()]),
        _message(2, [_content()]),
      ]);
    addTearDown(controller.dispose);
    await _pump(tester, const Text('Precache'));
    await tester.runAsync(
      () => precacheImage(
        AppImageCache.provider('https://example.com/output.png'),
        tester.element(find.text('Precache')),
      ),
    );
    final capture = GlobalKey();
    await _pump(
      tester,
      ConversationTimeline(controller: controller),
      capture: capture,
    );
    expect(find.text('任务已完成'), findsOneWidget);
    expect(find.text('生成结果'), findsNothing);
    expect(find.byType(ConversationMediaView), findsOneWidget);
    expect(
      find.byKey(const Key('conversation-media-download-output')),
      findsNothing,
    );
    expect(find.text('Final saved prompt'), findsNothing);
    await _capture(tester, capture, 'completed-390');
    await tester.tap(
      find.byKey(const Key('conversation-generation-task-plan-generation')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Final saved prompt'), findsOneWidget);
    final content = find.byWidgetPredicate(
      (widget) =>
          widget is ConversationCardContent &&
          widget.storageId == 'generation-task:generation:plan',
    );
    expect(tester.getSize(content).height, lessThanOrEqualTo(320));
    await tester.tap(
      find.byKey(const Key('conversation-generation-task-toggle-generation')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ConversationMediaView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'video result uses inline player and leaves download to preview',
    (tester) async {
      final original = VideoPlayerPlatform.instance;
      final platform = FakeVideoPlayer();
      VideoPlayerPlatform.instance = platform;
      addTearDown(() => VideoPlayerPlatform.instance = original);
      final repository = _Repository()..kind = 'video';
      final controller = ConversationController(repository, 'user');
      addTearDown(controller.dispose);
      await _pump(
        tester,
        ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ConversationTaskCard(
              block: ConversationBlock.fromJson(_task(mediaType: 'video')),
              controller: controller,
            ),
          ],
        ),
      );
      expect(find.byType(AppVideoPlayer), findsOneWidget);
      expect(
        find.byKey(const Key('conversation-media-download-output')),
        findsNothing,
      );
      expect(platform.sources.single.uri, 'https://example.com/output.mp4');
      expect(platform.playing, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'late outputs remove standalone result and keep task plan expansion',
    (tester) async {
      final repository = _Repository();
      final controller = _Controller(repository, 'user');
      addTearDown(controller.dispose);
      await _pump(tester, const Text('Precache'));
      await tester.runAsync(
        () => precacheImage(
          AppImageCache.provider('https://example.com/output.png'),
          tester.element(find.text('Precache')),
        ),
      );
      controller.publish(
        _snapshot([
          _message(1, [_task(state: 'running', outputs: [])]),
        ]),
      );
      final capture = GlobalKey();
      await _pump(
        tester,
        ConversationTimeline(controller: controller),
        capture: capture,
      );
      await tester.tap(
        find.byKey(const Key('conversation-generation-task-plan-generation')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Final saved prompt'), findsOneWidget);
      controller.publish(
        _snapshot([
          _message(1, [_task(state: 'completed', outputs: [])]),
          _message(2, [_content()]),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('生成结果'), findsOneWidget);
      controller.publish(
        _snapshot([
          _message(1, [_task()]),
          _message(2, [_content()]),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('生成结果'), findsNothing);
      await _capture(tester, capture, 'late');
      expect(find.byType(ConversationMediaView), findsOneWidget);
      expect(find.text('Final saved prompt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final mediaType in ['image', 'video']) {
    testWidgets('$mediaType failure fits narrow screen with large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ConversationController(_Repository(), 'user');
      addTearDown(controller.dispose);
      final block = ConversationBlock.fromJson(
        _task(state: 'failed', mediaType: mediaType),
      );
      await _pump(
        tester,
        ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ConversationTaskCard(block: block, controller: controller),
          ],
        ),
        scale: 2,
        dark: true,
      );
      expect(
        find.text(mediaType == 'image' ? '图片生成失败' : '视频生成失败'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('conversation-generation-placeholder')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
