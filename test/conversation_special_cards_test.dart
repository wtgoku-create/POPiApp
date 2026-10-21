import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/assets/presentation/role_detail_page.dart';
import 'package:popi_ai_app/features/role_guide/presentation/widgets/role_profile_sheet.dart';
import 'package:popi_ai_app/features/role_guide/domain/home_creation.dart';
import 'package:popi_ai_app/features/role_guide/domain/session_media_preferences.dart';
import 'package:popi_ai_app/features/session/domain/conversation_generation.dart';
import 'package:popi_ai_app/features/session/data/session_repository.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/session/presentation/conversation_controller.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_generation_card.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_task_card.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_timeline.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:toastification/toastification.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_card.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_card_content.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_style.dart';

import 'conversation_events_test.dart' show chatId;
import 'support/session_fixtures.dart';
import 'support/fake_video_player.dart';

class _CardRepository extends FixtureSessionRepository {
  int estimates = 0;
  num estimatedPoints = 10;
  bool failEstimateOnce = false;
  ConversationGenerationOptions? generationOverride;
  ConversationGenerationSelection? submitted;
  final controls = <String>[];

  @override
  Future<ConversationMedia> media(
    String id, {
    CancelToken? cancelToken,
  }) async => id == 'home-task-video'
      ? ConversationMedia(
          id: id,
          kind: 'video',
          url: 'https://example.com/result.mp4',
        )
      : await super.media(id, cancelToken: cancelToken);

  @override
  Future<ListPage<ConversationRoleTemplate>> roleTemplates({
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async => fixturePage(
    [
      ConversationRoleTemplate.fromJson({
        'id': 'watercolor',
        'title': 'Watercolor',
        'mediaId': 'style-image',
      }),
    ],
    page: page,
    pageSize: pageSize,
  );
  @override
  Future<ConversationGenerationOptions> generationOptions(
    String userId,
    String sessionId,
    ConversationBlock card, {
    CancelToken? cancelToken,
  }) async =>
      generationOverride ??
      await super.generationOptions(
        userId,
        sessionId,
        card,
        cancelToken: cancelToken,
      );

  @override
  Future<num> estimateGeneration(
    String mediaType,
    HomeConfig config, {
    CancelToken? cancelToken,
  }) async {
    estimates++;
    if (failEstimateOnce) {
      failEstimateOnce = false;
      throw StateError('offline');
    }
    return estimatedPoints;
  }

  @override
  Future<void> confirmGeneration(
    String userId,
    String sessionId,
    ConversationBlock card,
    ConversationGenerationSelection selection, {
    CancelToken? cancelToken,
  }) async {
    submitted = selection;
  }

  @override
  Future<void> controlTask(
    String userId,
    ConversationBlock task,
    String action, {
    Map<String, Object?>? capabilities,
    CancelToken? cancelToken,
  }) async {
    controls.add(action);
  }
}

ConversationBlock _generation() => ConversationBlock.fromJson({
  'type': 'object',
  'kind': 'plan',
  'data': {
    'id': 'image-plan',
    'kind': 'generation',
    'title': 'Character three-view',
    'status': 'ready',
    'revision': 1,
    'allowedActions': ['confirm', 'cancel'],
    'roleImage': {'requirements': 'Keep the character silhouette and costume'},
    'presentation': {'requirements': 'A clean character sheet'},
    'plan': {
      'items': [
        {
          'key': 'three_view',
          'mediaType': 'image',
          'modelId': 'model',
          'params': {'ratio': '16:9'},
        },
      ],
    },
  },
});

ConversationBlock _videoGeneration() => ConversationBlock.fromJson({
  'type': 'object',
  'kind': 'plan',
  'data': {
    'id': 'video-plan',
    'kind': 'generation',
    'title': '确认生成',
    'status': 'ready',
    'revision': 1,
    'allowedActions': ['confirm', 'cancel'],
    'presentation': {
      'requirements': List.generate(
        30,
        (i) =>
            '${i + 1}. 画面：主人弯腰在花盆里找到金牌，拿出来轻轻擦了擦，递到来财的嘴边，来财用脑袋蹭主人的手心，画面温馨；音效：温柔的笑声、咕噜声。',
      ).join('\n\n'),
    },
    'plan': {
      'items': [
        {
          'key': 'video',
          'mediaType': 'video',
          'modelId': 'model',
          'params': {'duration': 15, 'ratio': '9:16', 'resolution': '480p'},
        },
      ],
    },
  },
});

ConversationBlock _roleImageGeneration({
  bool long = false,
  bool reference = false,
}) => ConversationBlock.fromJson({
  'type': 'object',
  'kind': 'plan',
  'data': {
    ..._generation().data,
    'title': '生成角色形象',
    'roleImage': {
      'requirements': '',
      if (reference) 'referenceMediaId': 'reference-image',
      'role': {
        'title': '林小绘',
        'description': '热爱插画创作的年轻自由职业者，热衷于用画笔记录生活。',
        'profile': {'description': '热爱插画创作的年轻自由职业者'},
      },
    },
    'presentation': {
      'requirements': long
          ? List.filled(40, '保留角色轮廓和服饰，三视图使用一致的画风。\n\n').join()
          : '',
    },
  },
});

ConversationBlock _task({bool home = false}) => ConversationBlock.fromJson({
  'type': 'object',
  'kind': 'task',
  'action': home ? 'home' : 'workflow',
  'data': {
    'id': 'task',
    'title': 'Story production',
    'state': home ? 'awaiting_confirmation' : 'paused',
    'confirmationPending': home,
    'allowedActions': ['resume', 'cancel'],
    'steps': [
      {
        'key': 'script',
        'state': 'completed',
        'output': {
          'title': 'Episode script',
          'kind': 'script',
          'body': 'Scene 1: A letter arrives.',
        },
      },
      {'key': 'storyboard', 'state': 'pending'},
      {'key': 'video', 'state': 'pending'},
    ],
  },
});

ConversationBlock _homePlan({
  String status = 'confirmed',
  bool long = false,
}) => ConversationBlock.fromJson({
  'type': 'object',
  'kind': 'plan',
  'data': {
    'id': 'home-plan',
    'title': '生产方案',
    'status': status,
    'allowedActions': <String>[],
    'homePlan': {
      'cast': [
        {
          'ref': {'kind': 'role', 'id': 'cat', 'versionId': 'cat-v1'},
          'title': '来财',
          'description': '橘纹软萌猫，戴着写有来财的金牌，慵懒又温柔。',
          'avatar': 'assets/images/home_welcome_character.png',
        },
      ],
      'topic': {
        'ref': {'kind': 'topic', 'id': 'story'},
        'title': '来财的窝边小确幸',
        'summary':
            '### 故事梗概\n午后阳光洒在阳台绒布小窝，来财蜷成毛球打着盹。\n\n'
            '### 适合角色的原因\n软萌慵懒的性格，适合治愈陪伴的角色定位。\n\n'
            '${long ? List.filled(60, '阳光下的小猫轻轻翻身，继续享受温暖的午后。\n\n').join() : ''}',
        'hook': '软萌橘猫用金牌当小金币，带你感受午后的慵懒温柔。',
      },
    },
    'configuration': '模型：seedance-2.5\n清晰度：480p\n比例：9:16\n时长：15s',
    'estimatedPoints': 478,
    'plan': {
      'items': [
        {
          'modelId': 'saved-model',
          'mediaType': 'video',
          'params': {'resolution': '480p', 'ratio': '9:16', 'duration': 15},
        },
      ],
    },
  },
});

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  GlobalKey? capture,
  double textScale = 1,
  Locale locale = const Locale('en'),
  bool dark = false,
}) async {
  final theme = dark ? AppTheme.dark : AppTheme.light;
  await tester.pumpWidget(
    MaterialApp(
      builder: (_, child) => ProviderScope(child: child!),
      theme: const String.fromEnvironment('CONVERSATION_CAPTURE_FONT').isEmpty
          ? theme
          : theme.copyWith(
              textTheme: theme.textTheme.apply(
                fontFamily: 'ConversationCapture',
              ),
            ),
      locale: locale,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          size: tester.view.physicalSize,
          textScaler: TextScaler.linear(textScale),
        ),
        child: RepaintBoundary(
          key: capture,
          child: Scaffold(
            backgroundColor: dark
                ? theme.colorScheme.surface
                : ConversationStyle.background,
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 660,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [child],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    const path = String.fromEnvironment('CONVERSATION_CAPTURE_FONT');
    if (path.isEmpty) return;
    await (FontLoader(
      'ConversationCapture',
    )..addFont(File(path).readAsBytes().then(ByteData.sublistView))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final task in [false, true]) {
    for (final width in [320.0, 390.0]) {
      testWidgets(
        'home cast groups roles and opens saved profiles: task=$task width=$width',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final controller = ConversationController(_CardRepository(), 'a')
            ..sessionId = chatId;
          addTearDown(controller.dispose);
          final roles = [
            for (final (id, title) in [('first', '软软'), ('second', '阿栗')])
              {
                'id': id,
                'roleId': id,
                'versionId': '$id-v1',
                'ref': {'kind': 'role', 'id': id, 'versionId': '$id-v1'},
                'title': title,
                'profile': {
                  'title': title,
                  'description': 'Saved character profile',
                },
                'avatar':
                    'assets/images/role_guide_avatar_${id == 'first' ? 1 : 2}.png',
              },
          ];
          final original = task ? _task(home: true) : _homePlan();
          final block = ConversationBlock.fromJson({
            'type': 'object',
            'kind': task ? 'task' : 'plan',
            if (task) 'action': 'home',
            'data': {
              ...original.data,
              if (task) 'input': {'cast': roles},
              if (!task)
                'homePlan': {
                  ...conversationMap(original.data['homePlan']),
                  'cast': roles,
                },
            },
          });
          await _pump(
            tester,
            task
                ? ConversationTaskCard(block: block, controller: controller)
                : ConversationGenerationCard(
                    block: block,
                    controller: controller,
                  ),
            locale: const Locale('zh'),
            dark: width == 320,
            textScale: width == 320 ? 1.5 : 1,
          );
          expect(
            find.byKey(const Key('conversation-cast-summary')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('conversation-role-summary')),
            findsNothing,
          );
          expect(find.text('软软、阿栗'), findsOneWidget);
          final l10n = AppLocalizations.of(tester.element(find.text('软软、阿栗')))!;
          expect(find.text(l10n.roleCastCount(2)), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.tap(find.byKey(const Key('role-guide-view-profiles')));
          await tester.pumpAndSettle();
          final sheet = tester.widget<RoleProfileSheet>(
            find.byType(RoleProfileSheet),
          );
          expect(sheet.useSnapshot, isTrue);
          expect(sheet.roles.map((role) => role.id), ['first', 'second']);
          expect(sheet.roles.map((role) => role.profileVersionId), [
            'first-v1',
            'second-v1',
          ]);
          await tester.tap(find.byTooltip(l10n.roleNextProfile));
          await tester.pumpAndSettle();
          expect(
            tester.widget<RoleDetailPage>(find.byType(RoleDetailPage)).role.id,
            'second',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final size in [
    const Size(320, 844),
    const Size(390, 844),
    const Size(1280, 900),
  ]) {
    testWidgets('saved role plan has a compact readable layout at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ConversationController(_CardRepository(), 'a')
        ..sessionId = chatId;
      addTearDown(controller.dispose);
      final capture = GlobalKey();
      await _pump(
        tester,
        ConversationGenerationCard(
          block: ConversationBlock.fromJson({
            'type': 'object',
            'kind': 'plan',
            'data': {
              ..._roleImageGeneration().data,
              'title': '确认生成',
              'status': 'completed',
              'estimatedPoints': 17,
              'configuration': '模型：Popi Image 2\n清晰度：1K\n比例：16:9\n画质：中画质',
            },
          }),
          controller: controller,
        ),
        capture: capture,
        locale: const Locale('zh'),
        textScale: size.width == 320 ? 1.5 : 1,
      );
      expect(find.text('17 积分'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_CONVERSATION_CARDS')) {
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final pixels = await boundary.toImage();
          final bytes = await pixels.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/conversation-saved-role-plan-${size.width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          pixels.dispose();
        });
      }
    });

    for (final dark in [false, true]) {
      testWidgets('production plan matches Web at $size dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _CardRepository();
        final controller = ConversationController(repository, 'a')
          ..sessionId = chatId;
        addTearDown(controller.dispose);
        final capture = GlobalKey();
        await _pump(
          tester,
          ConversationGenerationCard(
            block: _homePlan(),
            controller: controller,
          ),
          capture: capture,
          locale: const Locale('zh'),
          dark: dark,
          textScale: dark ? 1.3 : 1,
        );
        for (final label in [
          '生产方案',
          '出场角色',
          '选题故事',
          '核心看点',
          '模型配置',
          '预计消耗积分',
          '478 积分',
          '模型：seedance-2.5',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.text('saved-model'), findsNothing);
        expect(find.byTooltip('模型/参数'), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
        expect(
          find.text(
            lookupAppLocalizations(const Locale('zh')).generationCreditNotice,
          ),
          findsNothing,
        );
        expect(repository.estimates, 0);
        expect(tester.takeException(), isNull);
        if (!dark && const bool.fromEnvironment('CAPTURE_CONVERSATION_CARDS')) {
          await tester.runAsync(
            () => precacheImage(
              const AssetImage('assets/images/home_welcome_character.png'),
              capture.currentContext!,
            ),
          );
          await tester.pump();
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final pixels = await boundary.toImage();
            final bytes = await pixels.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/tmp/conversation-home-plan-${size.width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            pixels.dispose();
          });
        }
        await tester.tap(find.byTooltip('收起档案'));
        await tester.pumpAndSettle();
        expect(find.text('生产方案'), findsOneWidget);
        expect(find.text('选题故事'), findsNothing);
        final header = find
            .ancestor(
              of: find.byTooltip(
                lookupAppLocalizations(const Locale('zh')).roleGuideViewMore,
              ),
              matching: find.byType(Row),
            )
            .first;
        expect(
          tester.getSize(find.byType(ConversationCard)).height,
          tester.getSize(header).height + 40,
        );
      });
    }
  }

  testWidgets(
    'historical plan falls back to saved parameters and avoids duplicate highlights',
    (tester) async {
      final original = _homePlan();
      final saved = conversationMap(original.data['homePlan']);
      final topic = conversationMap(saved['topic']);
      final controller = ConversationController(_CardRepository(), 'a')
        ..sessionId = chatId;
      addTearDown(controller.dispose);
      await _pump(
        tester,
        ConversationGenerationCard(
          block: ConversationBlock.fromJson({
            'type': 'object',
            'kind': 'plan',
            'data': {
              ...original.data,
              'configuration': '',
              'homePlan': {
                ...saved,
                'topic': {
                  ...topic,
                  'summary':
                      '${topic['summary']}\n\n### 核心看点\n${topic['hook']}',
                },
              },
            },
          }),
          controller: controller,
        ),
      );
      expect(find.text('Resolution: 480p'), findsOneWidget);
      expect(find.text('Aspect ratio: 9:16'), findsOneWidget);
      expect(find.text('Duration: 15s'), findsOneWidget);
      expect(find.text('saved-model'), findsNothing);
      expect(find.text('Core highlight'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is MarkdownMessage && widget.text == topic['hook'],
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'production plan keeps current estimate and actions outside long story',
    (tester) async {
      final repository = _CardRepository();
      final controller = ConversationController(repository, 'a')
        ..sessionId = chatId;
      addTearDown(controller.dispose);
      await _pump(
        tester,
        ConversationGenerationCard(
          block: _homePlan(status: 'ready', long: true),
          controller: controller,
        ),
      );
      expect(find.text('10 points'), findsOneWidget);
      expect(find.text('478 points'), findsNothing);
      expect(find.text('Model: Model'), findsOneWidget);
      expect(find.text('模型：seedance-2.5'), findsNothing);
      expect(find.byTooltip('Model / settings'), findsNothing);
      final content = find.byWidgetPredicate(
        (widget) =>
            widget is ConversationCardContent &&
            widget.storageId == 'generation:home-plan',
      );
      expect(tester.getSize(content).height, 320);
      final role = find.byKey(const Key('conversation-role-summary'));
      final configuration = find.byKey(
        const Key('conversation-plan-configuration'),
      );
      expect(find.descendant(of: content, matching: role), findsNothing);
      final rolePosition = tester.getTopLeft(role);
      final configurationPosition = tester.getTopLeft(configuration);
      expect(
        tester.getBottomLeft(role).dy,
        lessThan(tester.getTopLeft(content).dy),
      );
      expect(
        tester.getBottomLeft(content).dy,
        lessThan(configurationPosition.dy),
      );
      expect(
        find.descendant(of: content, matching: find.byType(FilledButton)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: content,
          matching: find.byKey(const Key('conversation-plan-configuration')),
        ),
        findsNothing,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.drag(
        find.descendant(
          of: content,
          matching: find.byType(SingleChildScrollView),
        ),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(find.text('10 points'), findsOneWidget);
      expect(tester.getTopLeft(role), rolePosition);
      expect(tester.getTopLeft(configuration), configurationPosition);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(390, 844),
    const Size(1280, 900),
    const Size(320, 844),
  ]) {
    testWidgets(
      'home progress matches Web and keeps expansion on updates at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = ConversationController(_CardRepository(), 'a')
          ..sessionId = chatId;
        addTearDown(controller.dispose);
        final task = ConversationBlock.fromJson({
          'type': 'object',
          'kind': 'task',
          'action': 'home',
          'data': {
            ..._task(home: true).data,
            'confirmationReason': 'storyboard_review',
            'allowedActions': ['cancel'],
            'input': {
              'cast': [
                {
                  'roleId': 12,
                  'versionId': 'role-v1',
                  'profile': {
                    'title': '来财',
                    'description': '橘纹软萌懒猫，神态慵懒，是一只治愈的小毛球。',
                  },
                },
              ],
            },
            'steps': [
              {
                'key': 'script',
                'state': 'completed',
                'output': {
                  'kind': 'script',
                  'body':
                      '场景：午后的阳台，金色阳光洒满木质地板。\n\n动作：来财蜷在小窝中，尾巴轻轻晃着，眯着眼睛伸了个懒腰。\n\n对白：无，只有柔软的呼噜声。',
                },
              },
              {
                'key': 'storyboard',
                'state': 'completed',
                'output': {
                  'kind': 'storyboard',
                  'body':
                      '{"shots":[{"duration":5,"description":"镜头缓缓拉近阳光下的小猫。"}]}',
                },
              },
              {'key': 'video', 'state': 'pending'},
              {'key': 'review', 'state': 'pending'},
            ],
          },
        });
        final capture = GlobalKey();
        Future<void> pump(ConversationBlock block) => _pump(
          tester,
          ConversationTaskCard(block: block, controller: controller),
          capture: capture,
          locale: const Locale('zh'),
          textScale: size.width == 320 ? 1.5 : 1,
          dark: size.width == 320,
        );
        await pump(task);
        expect(find.text('视频生成进度'), findsOneWidget);
        expect(find.text('分镜脚本已完成，待确认生成视频'), findsOneWidget);
        expect(find.text('来财'), findsOneWidget);
        expect(find.text('出场角色'), findsOneWidget);
        final role = find.byKey(const Key('conversation-role-view-profile'));
        final colors = Theme.of(tester.element(role)).colorScheme;
        expect(
          tester.widget<TextButton>(role).style!.backgroundColor!.resolve({}),
          colors.primary.withValues(alpha: .05),
        );
        expect(
          tester.getTopLeft(role).dy -
              tester.getBottomLeft(find.text('出场角色')).dy,
          8,
        );
        final cast = find.byKey(const Key('conversation-home-task-cast'));
        final scriptStep = find.byKey(const ValueKey('home-task-step:script'));
        final storyboardStep = find.byKey(
          const ValueKey('home-task-step:storyboard'),
        );
        expect(
          tester.getTopLeft(scriptStep).dy - tester.getBottomLeft(cast).dy,
          16,
        );
        expect(
          tester.getTopLeft(storyboardStep).dy -
              tester.getBottomLeft(scriptStep).dy,
          8,
        );
        final scriptToggle = find.byKey(
          const Key('conversation-task-section-script'),
        );
        final storyboardToggle = find.byKey(
          const Key('conversation-task-section-storyboard'),
        );
        await tester.tap(scriptToggle);
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(storyboardStep).dy -
              tester.getBottomLeft(scriptStep).dy,
          0,
        );
        expect(tester.getSize(scriptToggle).height, 44);
        expect(tester.getSize(storyboardToggle).height, 44);
        expect(
          tester.getCenter(storyboardToggle).dy -
              tester.getCenter(scriptToggle).dy,
          44,
        );
        if (const bool.fromEnvironment('CAPTURE_CONVERSATION_CARDS')) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final pixels = await boundary.toImage();
            final bytes = await pixels.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/tmp/conversation-home-task-collapsed-${size.width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            pixels.dispose();
          });
        }
        await tester.tap(scriptToggle);
        await tester.pumpAndSettle();
        expect(find.textContaining('场景：午后的阳台'), findsOneWidget);
        expect(find.textContaining('镜头缓缓拉近'), findsNothing);
        final stages = ['撰写剧本', '编排分镜', '生成视频', '检测结果'];
        final top = tester.getTopLeft(find.text(stages.first)).dy;
        for (final label in stages) {
          expect(tester.getTopLeft(find.text(label)).dy, top);
        }
        final confirm = find.byKey(
          const Key('conversation-task-confirm-video-task'),
        );
        final cancel = find.byKey(const Key('conversation-task-cancel-task'));
        await tester.ensureVisible(confirm);
        expect(
          tester.getCenter(confirm).dy,
          closeTo(tester.getCenter(cancel).dy, 1),
        );
        expect(
          tester.getSize(confirm).width,
          lessThan(tester.getSize(find.byType(ConversationCard)).width - 60),
        );
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_CONVERSATION_CARDS')) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final pixels = await boundary.toImage();
            final bytes = await pixels.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/tmp/conversation-home-task-${size.width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            pixels.dispose();
          });
        }
        await tester.tap(
          find.byKey(const Key('conversation-task-section-storyboard')),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('镜头缓缓拉近'), findsOneWidget);
        await pump(
          ConversationBlock.fromJson({
            'type': 'object',
            'kind': 'task',
            'action': 'home',
            'data': {...task.data, 'revision': 2},
          }),
        );
        expect(find.textContaining('镜头缓缓拉近'), findsOneWidget);
        await tester.ensureVisible(
          find.byKey(const Key('conversation-task-toggle-task')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('conversation-task-toggle-task')),
        );
        await tester.pumpAndSettle();
        expect(find.text('撰写剧本'), findsNothing);
        expect(confirm, findsNothing);
        await tester.tap(
          find.byKey(const Key('conversation-task-toggle-task')),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('镜头缓缓拉近'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final embedded in [true, false]) {
    testWidgets(
      'home result keeps media with its stage and consistent gaps embedded=$embedded',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final original = VideoPlayerPlatform.instance;
        VideoPlayerPlatform.instance = FakeVideoPlayer();
        addTearDown(() => VideoPlayerPlatform.instance = original);
        final controller = ConversationController(_CardRepository(), 'a')
          ..sessionId = chatId;
        addTearDown(controller.dispose);
        final capture = GlobalKey();
        await _pump(
          tester,
          ConversationTaskCard(
            block: ConversationBlock.fromJson({
              'type': 'object',
              'kind': 'task',
              'action': 'home',
              'data': {
                ..._task(home: true).data,
                'state': 'completed',
                'confirmationPending': false,
                'allowedActions': <String>[],
                'steps': [
                  {
                    'key': 'script',
                    'state': 'completed',
                    'output': {'kind': 'script', 'body': '剧本内容正文。'},
                  },
                  {
                    'key': 'storyboard',
                    'state': 'completed',
                    'output': {'kind': 'storyboard', 'body': '分镜正文。'},
                  },
                  {
                    'key': 'video',
                    'state': 'completed',
                    'output': embedded
                        ? {
                            'title': '视频结果',
                            'body': '视频生成完成',
                            'mediaIds': ['home-task-video'],
                          }
                        : [
                            {'kind': 'media', 'id': 'home-task-video'},
                          ],
                  },
                  {
                    'key': 'review',
                    'state': 'completed',
                    'output': {'title': '视频结果检查', 'body': '检查完成'},
                  },
                ],
              },
            }),
            controller: controller,
          ),
          capture: capture,
          locale: const Locale('zh'),
        );
        expect(find.text('出场角色'), findsNothing);
        final script = find.byKey(const ValueKey('home-task-step:script'));
        final storyboard = find.byKey(
          const ValueKey('home-task-step:storyboard'),
        );
        final video = find.byKey(const ValueKey('home-task-step:video'));
        final review = find.byKey(const ValueKey('home-task-step:review'));
        for (final (before, after, gap) in [
          (script, storyboard, 8),
          (storyboard, video, 8),
          (video, review, 20),
        ]) {
          expect(
            tester.getTopLeft(after).dy - tester.getBottomLeft(before).dy,
            closeTo(gap, .01),
          );
        }
        final media = find.byType(ConversationMediaView);
        expect(find.descendant(of: video, matching: media), findsOneWidget);
        if (embedded) {
          expect(
            tester.getTopLeft(media).dy -
                tester.getBottomLeft(find.text('视频生成完成')).dy,
            closeTo(16, .01),
          );
        }
        final scriptBody = find.byWidgetPredicate(
          (widget) =>
              widget is ConversationCardContent &&
              widget.storageId == 'home-task:task:script',
        );
        expect(
          tester.getTopLeft(scriptBody).dy -
              tester
                  .getBottomLeft(
                    find.byKey(const Key('conversation-task-section-script')),
                  )
                  .dy,
          8,
        );
        expect(tester.takeException(), isNull);
        if (embedded &&
            const bool.fromEnvironment('CAPTURE_CONVERSATION_CARDS')) {
          await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final pixels = await boundary.toImage();
            final bytes = await pixels.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/tmp/conversation-home-task-result.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            pixels.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'estimate failure uses toast and the original generation action can recover',
    (tester) async {
      final repository = _CardRepository()..failEstimateOnce = true;
      final controller = ConversationController(repository, 'a')
        ..sessionId = chatId;
      addTearDown(controller.dispose);
      await _pump(
        tester,
        ConversationGenerationCard(
          block: _generation(),
          controller: controller,
        ),
      );
      expect(find.text('Request failed. Please try again'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ConversationCard),
          matching: find.text('Request failed. Please try again'),
        ),
        findsNothing,
      );
      expect(find.byTooltip('Retry'), findsNothing);
      await tester.ensureVisible(find.text('Generate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate'));
      await tester.pumpAndSettle();
      expect(repository.estimates, 2);
      await tester.tap(find.text('Generate').last);
      await tester.pumpAndSettle();
      expect(
        repository.submitted?.requirements,
        'Keep the character silhouette and costume',
      );
      toastification.dismissAll(delayForAnimation: false);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'plain storyboard payload uses one prompt in content and task cards',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ConversationController(_CardRepository(), 'a')
        ..sessionId = chatId;
      addTearDown(controller.dispose);
      const prompt = '全片15秒，无BGM。\n镜头01：**保留原文**\n角色在雨中等待。';
      final output = <String, Object?>{
        'kind': 'storyboard',
        'title': 'Historical title',
        'payload': prompt,
      };
      await _pump(
        tester,
        ConversationObjectView(
          block: ConversationBlock.fromJson({
            'type': 'object',
            'kind': 'content',
            'data': output,
          }),
          controller: controller,
        ),
        locale: const Locale('zh'),
        textScale: 1.5,
      );
      expect(find.text('分镜视频提示词'), findsOneWidget);
      expect(find.text(prompt), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.text('Historical title'), findsNothing);
      await _pump(
        tester,
        ConversationTaskCard(
          block: ConversationBlock.fromJson({
            'type': 'object',
            'kind': 'task',
            'action': 'home',
            'data': {
              ..._task(home: true).data,
              'steps': [
                {'key': 'storyboard', 'state': 'completed', 'output': output},
              ],
            },
          }),
          controller: controller,
        ),
        locale: const Locale('zh'),
        textScale: 1.5,
      );
      await tester.tap(
        find.byKey(const Key('conversation-task-section-storyboard')),
      );
      await tester.pumpAndSettle();
      expect(find.text('分镜视频提示词'), findsOneWidget);
      expect(find.text(prompt), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long home artifacts scroll and retain reading position through updates and collapse',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ConversationController(_CardRepository(), 'a')
        ..sessionId = chatId;
      addTearDown(controller.dispose);
      final script = List.generate(
        50,
        (i) => 'Scene $i: A quiet afternoon with the character.',
      ).join('\n\n');
      ConversationBlock task(int revision) => ConversationBlock.fromJson({
        'type': 'object',
        'kind': 'task',
        'action': 'home',
        'data': {
          ..._task(home: true).data,
          'revision': revision,
          'steps': [
            {
              'key': 'script',
              'state': 'completed',
              'output': {'kind': 'script', 'body': script},
            },
            {
              'key': 'storyboard',
              'state': 'completed',
              'output': {
                'kind': 'storyboard',
                'body': jsonEncode({
                  'shots': List.generate(
                    30,
                    (i) => {
                      'duration': 5,
                      'description':
                          'Shot $i: The camera moves slowly toward the character.',
                    },
                  ),
                }),
              },
            },
            {'key': 'video', 'state': 'pending'},
            {'key': 'review', 'state': 'pending'},
          ],
        },
      });
      final capture = GlobalKey();
      Future<void> pump(int revision) => _pump(
        tester,
        ConversationTaskCard(block: task(revision), controller: controller),
        capture: capture,
      );
      await pump(1);
      if (const bool.fromEnvironment('CAPTURE_CONVERSATION_CARDS')) {
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final pixels = await boundary.toImage();
          final bytes = await pixels.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/conversation-card-long-content.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          pixels.dispose();
        });
      }
      final content = find.byWidgetPredicate(
        (widget) =>
            widget is ConversationCardContent &&
            widget.storageId == 'home-task:task:script',
      );
      expect(tester.getSize(content).height, 320);
      final position = tester
          .state<ScrollableState>(
            find
                .descendant(of: content, matching: find.byType(Scrollable))
                .first,
          )
          .position;
      await tester.drag(content, const Offset(0, -220));
      await tester.pumpAndSettle();
      final offset = position.pixels;
      expect(offset, greaterThan(0));
      await pump(2);
      expect(position.pixels, offset);
      await tester.tap(
        find.byKey(const Key('conversation-task-section-script')),
      );
      await tester.pumpAndSettle();
      expect(content, findsNothing);
      await tester.tap(
        find.byKey(const Key('conversation-task-section-script')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .state<ScrollableState>(
              find
                  .descendant(of: content, matching: find.byType(Scrollable))
                  .first,
            )
            .position
            .pixels,
        offset,
      );
      await tester.tap(
        find.byKey(const Key('conversation-task-section-storyboard')),
      );
      await tester.pumpAndSettle();
      final storyboard = find.byWidgetPredicate(
        (widget) =>
            widget is ConversationCardContent &&
            widget.storageId == 'home-task:task:storyboard',
      );
      expect(tester.getSize(storyboard).height, 320);
      await tester.ensureVisible(
        find.byKey(const Key('conversation-task-confirm-video-task')),
      );
      await tester.pumpAndSettle();
      expect(
        find
            .byKey(const Key('conversation-task-confirm-video-task'))
            .hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final kind in ['script', 'storyboard', 'profile_update', 'generation']) {
    testWidgets('long $kind card content is bounded with actions outside', (
      tester,
    ) async {
      final controller = ConversationController(_CardRepository(), 'a')
        ..sessionId = chatId;
      addTearDown(controller.dispose);
      final longText = List.generate(
        80,
        (i) => 'Paragraph $i: Saved content stays readable.',
      ).join('\n\n');
      final block = kind == 'generation'
          ? ConversationBlock.fromJson({
              'type': 'object',
              'kind': 'plan',
              'data': {
                ..._generation().data,
                'presentation': {'requirements': longText},
              },
            })
          : ConversationBlock.fromJson({
              'type': 'object',
              'kind': kind == 'profile_update' ? 'plan' : 'content',
              'data': {
                'id': kind,
                'kind': kind,
                'title': 'Saved content',
                'body': longText,
                'status': 'ready',
                'allowedActions': ['confirm', 'cancel'],
                if (kind == 'profile_update')
                  'profile': {
                    'description': longText,
                    'expressionStyle': longText,
                    'targetAudience': longText,
                    'contentTags': [longText],
                  },
              },
            });
      await _pump(
        tester,
        ConversationObjectView(block: block, controller: controller),
      );
      final content = find.byType(ConversationCardContent).first;
      expect(tester.getSize(content).height, 320);
      if (kind == 'profile_update') {
        await tester.tap(find.text('View full character profile'));
        await tester.pumpAndSettle();
        expect(tester.getSize(content).height, 320);
        expect(find.text('Collapse profile').hitTestable(), findsOneWidget);
      }
      if (['generation', 'profile_update'].contains(kind)) {
        final action = find.byType(FilledButton).first;
        expect(
          find.ancestor(
            of: action,
            matching: find.byType(ConversationCardContent),
          ),
          findsNothing,
        );
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(action.hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final size in [
    const Size(320, 844),
    const Size(390, 844),
    const Size(1280, 900),
  ]) {
    for (final dark in [false, true]) {
      testWidgets(
        'video confirmation keeps read-only parameters and actions fixed at $size dark=$dark',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repository = _CardRepository()
            ..estimatedPoints = 478
            ..generationOverride = ConversationGenerationOptions(
              models: [
                HomeModel.fromJson({
                  'id': 'model',
                  'name': 'seedance-2.5',
                  'available': true,
                  'mediaType': 'video',
                  'parameters': [],
                }),
              ],
              preferences: SessionMediaPreferences.fromJson({
                'revision': 1,
                'video': {
                  'modelId': 'model',
                  'params': {
                    'duration': 15,
                    'ratio': '9:16',
                    'resolution': '480p',
                  },
                },
              }),
            );
          final controller = ConversationController(repository, 'a')
            ..sessionId = chatId;
          addTearDown(controller.dispose);
          final capture = GlobalKey();
          await _pump(
            tester,
            ConversationGenerationCard(
              block: _videoGeneration(),
              controller: controller,
            ),
            capture: capture,
            locale: const Locale('zh'),
            dark: dark,
            textScale: dark ? 1.3 : 1,
          );
          for (final text in [
            '模型配置',
            '模型: seedance-2.5',
            '时长: 15s',
            '比例: 9:16',
            '分辨率: 480p',
            '预计消耗积分',
            '478 积分',
          ]) {
            expect(find.text(text), findsOneWidget);
          }
          final content = find.byWidgetPredicate(
            (widget) =>
                widget is ConversationCardContent &&
                widget.storageId == 'generation:video-plan',
          );
          final parameters = find.byKey(
            const Key('conversation-plan-configuration'),
          );
          final confirm = find.byType(FilledButton);
          final notice = find.text(
            lookupAppLocalizations(const Locale('zh')).generationCreditNotice,
          );
          expect(notice, findsOneWidget);
          expect(
            tester.getBottomLeft(notice).dy,
            lessThanOrEqualTo(tester.getTopLeft(confirm).dy),
          );
          expect(find.byTooltip('模型/参数'), findsNothing);
          expect(
            find.descendant(of: content, matching: parameters),
            findsNothing,
          );
          expect(find.descendant(of: content, matching: confirm), findsNothing);
          expect(
            find.descendant(of: parameters, matching: find.byType(IconButton)),
            findsNothing,
          );
          final parameterPosition = tester.getTopLeft(parameters);
          final confirmPosition = tester.getTopLeft(confirm);
          final scroll = tester
              .state<ScrollableState>(
                find
                    .descendant(of: content, matching: find.byType(Scrollable))
                    .first,
              )
              .position;
          await tester.drag(content, const Offset(0, -250));
          await tester.pumpAndSettle();
          expect(scroll.pixels, greaterThan(0));
          expect(tester.getTopLeft(parameters), parameterPosition);
          expect(tester.getTopLeft(confirm), confirmPosition);
          expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
          expect(tester.takeException(), isNull);
          if (!dark &&
              const bool.fromEnvironment('CAPTURE_CONVERSATION_CARDS')) {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final pixels = await boundary.toImage();
              final bytes = await pixels.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '/tmp/conversation-video-confirmation-${size.width.toInt()}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              pixels.dispose();
            });
          }
        },
      );
    }
  }

  for (final size in [
    const Size(320, 844),
    const Size(390, 844),
    const Size(1280, 900),
  ]) {
    testWidgets('role image editor keeps role and footer fixed at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ConversationController(_CardRepository(), 'a')
        ..sessionId = chatId;
      addTearDown(controller.dispose);
      final capture = GlobalKey();
      Future<void> pump({required bool long}) => _pump(
        tester,
        ConversationGenerationCard(
          block: _roleImageGeneration(long: long),
          controller: controller,
        ),
        capture: capture,
        locale: const Locale('zh'),
        textScale: size.width == 320 ? 1.5 : 1,
        dark: size.width == 320,
      );
      await pump(long: false);
      expect(
        tester.getSize(find.byKey(const Key('conversation-reference-tile'))),
        const Size(80, 80),
      );
      expect(find.text('角色档案已更新'), findsNothing);
      expect(find.text('0/8000'), findsNothing);
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_CONVERSATION_CARDS')) {
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final pixels = await boundary.toImage();
          final bytes = await pixels.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/conversation-role-image-${size.width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          pixels.dispose();
        });
      }
      await pump(long: true);
      final content = find.byWidgetPredicate(
        (widget) =>
            widget is ConversationCardContent &&
            widget.storageId == 'generation:image-plan',
      );
      final role = find.byKey(const Key('conversation-role-card'));
      final footer = find.byKey(const Key('conversation-plan-configuration'));
      final confirm = find.byType(FilledButton);
      expect(find.descendant(of: content, matching: role), findsNothing);
      expect(find.descendant(of: content, matching: footer), findsNothing);
      expect(find.descendant(of: content, matching: confirm), findsNothing);
      final rolePosition = tester.getTopLeft(role);
      final footerPosition = tester.getTopLeft(footer);
      final confirmPosition = tester.getTopLeft(confirm);
      final scroll = find.descendant(
        of: content,
        matching: find.byType(SingleChildScrollView),
      );
      await tester.drag(scroll, const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(role), rolePosition);
      expect(tester.getTopLeft(footer), footerPosition);
      expect(tester.getTopLeft(confirm), confirmPosition);
      expect(
        Scrollable.of(
          tester.element(
            find.descendant(
              of: content,
              matching: find.byType(MarkdownMessage),
            ),
          ),
        ).position.pixels,
        greaterThan(0),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'reference removal and visual style selection update the submitted inputs',
    (tester) async {
      final repository = _CardRepository();
      final controller = ConversationController(repository, 'a')
        ..sessionId = chatId;
      addTearDown(controller.dispose);
      await _pump(
        tester,
        ConversationGenerationCard(
          block: _roleImageGeneration(reference: true),
          controller: controller,
        ),
      );
      expect(
        tester
            .widget<ConversationMediaView>(find.byType(ConversationMediaView))
            .thumbnailSize,
        80,
      );
      await tester.tap(find.byTooltip('Remove image'));
      await tester.pumpAndSettle();
      expect(find.byType(ConversationMediaView), findsNothing);
      await tester.tap(find.byKey(const Key('conversation-role-style-select')));
      await tester.pumpAndSettle();
      expect(find.byType(SliverGrid), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('role-template:watercolor')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('conversation-style-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Watercolor'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Keep the silhouette');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.text('Generate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate').last);
      await tester.pumpAndSettle();
      expect(repository.submitted!.referenceMediaId, isNull);
      expect(repository.submitted!.roleTemplateId, 'watercolor');
      expect(repository.submitted!.roleTemplateMediaId, 'style-image');
      expect(repository.submitted!.requirements, 'Keep the silhouette');
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(390, 844), const Size(1280, 900)]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('generation card fits $size at text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _CardRepository();
        final controller = ConversationController(repository, 'a')
          ..sessionId = chatId;
        addTearDown(controller.dispose);
        final capture = GlobalKey();
        await _pump(
          tester,
          ConversationGenerationCard(
            block: _generation(),
            controller: controller,
          ),
          capture: capture,
          textScale: scale,
        );
        expect(find.text('10 points'), findsOneWidget);
        expect(find.byTooltip('Model / settings'), findsNothing);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
        if (scale == 1 &&
            const bool.fromEnvironment('CAPTURE_CONVERSATION_CARDS')) {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final pixels = await boundary.toImage();
            final bytes = await pixels.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/tmp/conversation-generation-${size.width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            pixels.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets(
    'generation estimates debounce and confirmation uses current input',
    (tester) async {
      final repository = _CardRepository();
      final controller = ConversationController(repository, 'a')
        ..sessionId = chatId;
      addTearDown(controller.dispose);
      await _pump(
        tester,
        ConversationGenerationCard(
          block: _generation(),
          controller: controller,
        ),
      );
      expect(repository.estimates, 1);
      final notice = lookupAppLocalizations(
        const Locale('en'),
      ).generationCreditNotice;
      expect(find.text(notice), findsOneWidget);
      final field = find.byType(TextField);
      await tester.enterText(field, 'First requirement');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(field, 'Final requirement');
      await tester.pump(const Duration(milliseconds: 200));
      expect(repository.estimates, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(repository.estimates, 2);
      await tester.ensureVisible(find.text('Generate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate'));
      await tester.pumpAndSettle();
      expect(repository.submitted, isNull);
      expect(find.textContaining(notice), findsNWidgets(2));
      await tester.tap(find.text('Generate').last);
      await tester.pumpAndSettle();
      expect(repository.submitted!.requirements, 'Final requirement');
      expect(repository.submitted!.estimatedPoints, 10);
      expect(repository.submitted!.mediaPreferencesRevision, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('workflow controls use capabilities and step content expands', (
    tester,
  ) async {
    final repository = _CardRepository();
    final controller = ConversationController(repository, 'a')
      ..sessionId = chatId;
    addTearDown(controller.dispose);
    await _pump(
      tester,
      ConversationTaskCard(block: _task(), controller: controller),
    );
    expect(
      find.byKey(const Key('conversation-task-pause-task')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('conversation-task-resume-task')),
      findsNothing,
    );
    expect(find.text('Scene 1: A letter arrives.'), findsNothing);
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pumpAndSettle();
    expect(find.text('Scene 1: A letter arrives.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('conversation-task-pause-task')));
    await tester.pumpAndSettle();
    expect(repository.controls, ['pause']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('home video confirmation and profile diff have actual actions', (
    tester,
  ) async {
    final repository = _CardRepository();
    final controller = ConversationController(repository, 'a')
      ..sessionId = chatId;
    addTearDown(controller.dispose);
    final profile = ConversationBlock.fromJson({
      'type': 'object',
      'kind': 'plan',
      'data': {
        'id': 'profile',
        'kind': 'profile_update',
        'title': 'Character profile',
        'before': {'description': 'Before description'},
        'changes': {'description': 'After description'},
        'status': 'ready',
        'allowedActions': ['confirm', 'cancel'],
      },
    });
    await _pump(
      tester,
      Column(
        children: [
          ConversationTaskCard(
            block: _task(home: true),
            controller: controller,
          ),
          ConversationObjectView(block: profile, controller: controller),
        ],
      ),
    );
    expect(find.text('Before description'), findsOneWidget);
    expect(find.text('After description'), findsOneWidget);
    expect(
      find.text(
        lookupAppLocalizations(const Locale('en')).generationCreditNotice,
      ),
      findsOneWidget,
    );
    final confirm = find.widgetWithText(
      FilledButton,
      'Confirm video generation',
    );
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(repository.controls, ['confirm-video']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'home video failure shows Chinese guidance and keeps task retry',
    (tester) async {
      final repository = _CardRepository();
      final controller = ConversationController(repository, 'a')
        ..sessionId = chatId;
      addTearDown(controller.dispose);
      await _pump(
        tester,
        ConversationTaskCard(
          controller: controller,
          block: ConversationBlock.fromJson({
            'type': 'object',
            'kind': 'task',
            'action': 'home',
            'data': {
              ..._task(home: true).data,
              'state': 'failed',
              'error': 'VIDEO_GENERATION_FAILED',
              'allowedActions': ['retry'],
            },
          }),
        ),
        locale: const Locale('zh'),
      );
      expect(find.text('视频生成失败'), findsOneWidget);
      expect(find.text('VIDEO_GENERATION_FAILED'), findsNothing);
      final retry = find.byKey(const Key('conversation-task-retry-task'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(repository.controls, ['retry']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'home controls preserve busy, cancellation and task retry rules',
    (tester) async {
      final repository = _CardRepository();
      final controller = ConversationController(repository, 'a')
        ..sessionId = chatId;
      addTearDown(controller.dispose);
      Future<void> pump(Map<String, Object?> data) => _pump(
        tester,
        ConversationTaskCard(
          controller: controller,
          block: ConversationBlock.fromJson({
            'type': 'object',
            'kind': 'task',
            'action': 'home',
            'data': {..._task(home: true).data, ...data},
          }),
        ),
      );
      controller.pending = true;
      await pump({});
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byKey(const Key('conversation-task-cancel-task')),
            )
            .onPressed,
        isNull,
      );
      controller.pending = false;
      await pump({'intent': 'cancel', 'allowedActions': []});
      expect(find.text('Stopping'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      await pump({
        'state': 'failed',
        'error': 'INSUFFICIENT_POINTS',
        'allowedActions': ['retry'],
      });
      expect(
        find.text('Not enough points. Top up and try again'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('conversation-task-retry-task')));
      await tester.pumpAndSettle();
      expect(repository.controls, ['retry']);
      await pump({
        'allowedActions': ['cancel'],
      });
      await tester.tap(find.byKey(const Key('conversation-task-cancel-task')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop production'));
      await tester.pumpAndSettle();
      expect(repository.controls, ['retry', 'cancel']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
