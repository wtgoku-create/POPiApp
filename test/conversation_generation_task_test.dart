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
import 'package:popi_ai_app/features/session/domain/conversation_generation.dart';
import 'package:popi_ai_app/features/session/domain/conversation_generation_view.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/session/domain/conversation_task.dart';
import 'package:popi_ai_app/features/session/presentation/conversation_controller.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_card_content.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_card.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_generation_card.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_generation_configuration.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_progress.dart';
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
    'progress': [
      {
        'id': 'compile',
        'labelKey': 'pages.studio.progress.compilePrompt',
        'status': 'completed',
      },
      {
        'id': 'generate',
        'labelKey': 'pages.studio.progress.generateImage',
        'status': 'completed',
      },
    ],
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
  int generationOptionsCalls = 0;

  @override
  Future<ConversationGenerationOptions> generationOptions(
    String userId,
    String sessionId,
    ConversationBlock card, {
    CancelToken? cancelToken,
  }) {
    generationOptionsCalls++;
    return super.generationOptions(
      userId,
      sessionId,
      card,
      cancelToken: cancelToken,
    );
  }

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
    'generation references include every plan item and deduplicate materials',
    () {
      final view = ConversationGenerationView(
        ConversationBlock.fromJson({
          'type': 'object',
          'kind': 'plan',
          'data': {
            'roleTemplate': {'mediaId': 'style'},
            'plan': {
              'items': [
                {
                  'references': [
                    {'mediaId': 'character', 'purpose': 'identity'},
                    {'mediaId': 'style', 'purpose': 'style'},
                  ],
                },
                {
                  'references': [
                    {'mediaId': 'character', 'purpose': 'identity'},
                    {'mediaId': 'second-character', 'purpose': 'identity'},
                    {'mediaId': ''},
                  ],
                },
              ],
            },
          },
        }),
      );
      expect(view.savedReferenceIds, [
        'style',
        'character',
        'second-character',
      ]);
    },
  );

  for (final width in [320.0, 390.0]) {
    for (final mode in ['ready', 'completed', 'embedded']) {
      testWidgets(
        'reference thumbnails stay above the prompt: $mode at $width',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repository = _Repository();
          final controller = ConversationController(repository, 'user')
            ..sessionId = 'session';
          addTearDown(controller.dispose);
          final capture = GlobalKey();
          await _pump(tester, const SizedBox());
          await tester.runAsync(() async {
            final context = tester.element(find.byType(Scaffold));
            for (final id in ['character', 'second-character']) {
              await precacheImage(
                AppImageCache.provider('https://example.com/$id.png'),
                context,
              );
            }
          });
          await _pump(
            tester,
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ConversationGenerationCard(
                  block: ConversationBlock.fromJson({
                    'type': 'object',
                    'kind': 'plan',
                    'data': {
                      'id': 'references-plan',
                      'title': '确认生成',
                      'status': mode == 'completed' ? 'completed' : 'ready',
                      'allowedActions': ['confirm', 'cancel'],
                      'configuration': '模型：Seedance 2.0\n比例：9:16',
                      'plan': {
                        'items': [
                          {
                            'key': 'video',
                            'mediaType': 'video',
                            'modelId': 'saved-model',
                            'params': {'ratio': '9:16'},
                            'prompt': List.filled(
                              30,
                              '9:16竖屏，总时长15秒。保持角色形象和服装一致。\n\n',
                            ).join(),
                            'references': [
                              {'mediaId': 'character', 'purpose': 'identity'},
                            ],
                          },
                          {
                            'references': [
                              {'mediaId': 'character', 'purpose': 'identity'},
                              {
                                'mediaId': 'second-character',
                                'purpose': 'identity',
                              },
                            ],
                          },
                        ],
                      },
                    },
                  }),
                  controller: controller,
                  embedded: mode == 'embedded',
                  readOnly: mode == 'embedded',
                ),
              ],
            ),
            dark: width == 320,
            scale: width == 320 ? 1.5 : 1,
            capture: capture,
          );
          final references = find.byKey(
            const Key('conversation-generation-references'),
          );
          final images = find.descendant(
            of: references,
            matching: find.byType(ConversationMediaView),
          );
          final content = find.byType(ConversationCardContent);
          expect(images, findsNWidgets(2));
          expect(
            tester
                .widgetList<ConversationMediaView>(images)
                .map((image) => image.id),
            ['character', 'second-character'],
          );
          expect(tester.getSize(images.first), const Size(80, 80));
          final pixels = find.descendant(
            of: references,
            matching: find.byType(RawImage),
          );
          expect(pixels, findsNWidgets(2));
          expect(
            tester
                .widgetList<RawImage>(pixels)
                .every((image) => image.image != null),
            isTrue,
          );
          expect(
            tester.getBottomLeft(references).dy,
            lessThan(tester.getTopLeft(content).dy),
          );
          expect(
            find.descendant(of: content, matching: references),
            findsNothing,
          );
          final position = tester.getTopLeft(references);
          await _capture(tester, capture, 'references-$mode-${width.toInt()}');
          await tester.drag(content, const Offset(0, -180));
          await tester.pumpAndSettle();
          expect(tester.getTopLeft(references), position);
          expect(tester.takeException(), isNull);
          if (mode == 'completed' && width == 390) {
            await tester.tap(images.first);
            await tester.pumpAndSettle();
            expect(
              find.byKey(const Key('asset-preview-image')),
              findsOneWidget,
            );
            await tester.tap(find.byKey(const Key('asset-preview-close')));
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('asset-preview-image')), findsNothing);
          }
        },
      );
    }
  }

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
    'sync_error',
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
        expect(find.text('正在生成图片'), findsNWidgets(2));
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
    expect(find.text('执行进度'), findsNothing);
    expect(find.byType(ConversationProgressSteps), findsNothing);
    await _capture(tester, capture, 'completed-390');
    await tester.tap(
      find.byKey(const Key('conversation-generation-task-plan-generation')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Final saved prompt'), findsOneWidget);
    final planCard = tester.widget<ConversationGenerationCard>(
      find.byType(ConversationGenerationCard),
    );
    expect(planCard.readOnly, isTrue);
    expect(planCard.embedded, isTrue);
    expect(find.byType(ConversationGenerationConfiguration), findsOneWidget);
    expect(find.text('模型：saved-model'), findsOneWidget);
    expect(find.text('12 积分'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(repository.generationOptionsCalls, 0);
    final content = find.byWidgetPredicate(
      (widget) =>
          widget is ConversationCardContent &&
          widget.storageId == 'generation:confirmation',
    );
    expect(tester.getSize(content).height, lessThanOrEqualTo(320));
    await tester.tap(
      find.byKey(const Key('conversation-generation-task-toggle-generation')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ConversationMediaView), findsNothing);
    final toggle = find.byKey(
      const Key('conversation-generation-task-toggle-generation'),
    );
    final header = find.ancestor(of: toggle, matching: find.byType(Row)).first;
    expect(
      tester.getSize(find.byType(ConversationCard)).height,
      tester.getSize(header).height + 40,
    );
    expect(tester.takeException(), isNull);
  });

  for (final (width, scale) in [(320.0, 1.5), (390.0, 1.0), (1024.0, 1.0)]) {
    testWidgets('saved task plan reuses a read-only confirmation at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _Repository();
      final controller = ConversationController(repository, 'user');
      addTearDown(controller.dispose);
      final capture = GlobalKey();
      await _pump(tester, const Text('Precache'));
      await tester.runAsync(
        () => precacheImage(
          AppImageCache.provider('https://example.com/output.png'),
          tester.element(find.text('Precache')),
        ),
      );
      await _pump(
        tester,
        ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ConversationTaskCard(
              block: ConversationBlock.fromJson(_task()),
              controller: controller,
            ),
          ],
        ),
        scale: scale,
        capture: capture,
      );
      await tester.tap(
        find.byKey(const Key('conversation-generation-task-plan-generation')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ConversationGenerationCard), findsOneWidget);
      expect(find.byType(ConversationGenerationConfiguration), findsOneWidget);
      expect(find.text('Final saved prompt'), findsOneWidget);
      expect(find.byType(ConversationProgressSteps), findsNothing);
      expect(find.text('执行进度'), findsNothing);
      expect(find.byTooltip('收起档案'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(repository.generationOptionsCalls, 0);
      expect(tester.takeException(), isNull);
      await _capture(tester, capture, 'saved-plan-${width.toInt()}');
    });
  }

  testWidgets('read-only plan never loads or exposes ready-plan actions', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = ConversationController(repository, 'user')
      ..sessionId = 'session';
    addTearDown(controller.dispose);
    final task = ConversationBlock.fromJson(_task());
    final saved = ConversationGenerationTaskView(task, null).fixedPlan!;
    await _pump(
      tester,
      ConversationGenerationCard(
        block: ConversationBlock.fromJson({
          'type': 'object',
          'kind': 'plan',
          'data': {
            ...saved.data,
            'roleTemplate': {'title': 'Saved style'},
            'roleImage': {'requirements': 'Keep the original outfit'},
            'status': 'ready',
            'allowedActions': ['confirm', 'cancel'],
          },
        }),
        controller: controller,
        readOnly: true,
        embedded: true,
      ),
    );
    expect(find.text('Final saved prompt'), findsOneWidget);
    expect(find.text('画风：Saved style'), findsOneWidget);
    expect(find.text('Keep the original outfit'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(repository.generationOptionsCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('embedded home plan keeps production sections without actions', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = ConversationController(repository, 'user')
      ..sessionId = 'session';
    addTearDown(controller.dispose);
    final task = ConversationBlock.fromJson(_task());
    final saved = ConversationGenerationTaskView(task, null).fixedPlan!;
    await _pump(
      tester,
      ListView(
        children: [
          ConversationGenerationCard(
            block: ConversationBlock.fromJson({
              'type': 'object',
              'kind': 'plan',
              'data': {
                ...saved.data,
                'status': 'ready',
                'homePlan': {
                  'cast': [],
                  'topic': {'title': 'Saved story', 'body': 'Saved synopsis'},
                },
              },
            }),
            controller: controller,
            readOnly: true,
            embedded: true,
          ),
        ],
      ),
    );
    expect(find.text('Saved story'), findsOneWidget);
    expect(find.text('Saved synopsis'), findsOneWidget);
    expect(find.text('出场角色'), findsOneWidget);
    expect(find.text('模型配置'), findsOneWidget);
    expect(find.text('12 积分'), findsOneWidget);
    expect(find.text('生产方案'), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(repository.generationOptionsCalls, 0);
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
