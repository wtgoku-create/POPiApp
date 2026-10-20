import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/session/data/conversation_events.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/session/presentation/conversation_controller.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_card_content.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_timeline.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_progress.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_svg_icon.dart';

import 'conversation_events_test.dart'
    show chatEvent, chatMessageJson, chatSnapshotJson, chatId;
import 'support/session_fixtures.dart';

const processing = 'script.run.processing';
const reading = 'pages.studio.progress.readRole';
Map<String, Object?> step(String id, String label, String state) => {
  'id': id,
  'labelKey': label,
  'status': state,
};
ConversationBlock progress(
  List<Map<String, Object?>> steps, {
  String state = 'running',
  int attempt = 1,
}) => ConversationBlock.fromJson({
  'type': 'object',
  'kind': 'progress',
  'action': 'updated',
  'data': {'runId': 'run', 'attempt': attempt, 'state': state, 'steps': steps},
});
Map<String, Object?> message(List<Map<String, Object?>> steps, int revision) =>
    {
      ...chatMessageJson(revision: revision),
      'blocks': [
        {'type': 'object', 'kind': 'progress', 'data': progress(steps).data},
      ],
    };

final scriptRetrySteps = [
  step('prepare', 'pages.studio.progress.prepare', 'completed'),
  step('model:1', 'pages.studio.progress.analyze', 'completed'),
  step('reply:1', 'pages.studio.progress.reply', 'completed'),
  step('write:1', 'pages.studio.progress.writeScript', 'failed'),
  {
    ...step(
      'write:1:materials',
      'pages.studio.progress.readTextSources',
      'failed',
    ),
    'parentId': 'write:1',
  },
  step('model:2', 'pages.studio.progress.analyze', 'completed'),
  step('write:2', 'pages.studio.progress.writeScript', 'completed'),
  {
    ...step(
      'write:2:materials',
      'pages.studio.progress.readTextSources',
      'completed',
    ),
    'parentId': 'write:2',
  },
  {
    ...step('write:2:skill', 'pages.studio.progress.skillScript', 'completed'),
    'parentId': 'write:2',
  },
  {
    ...step(
      'write:2:model:1',
      'pages.studio.progress.writeScript',
      'completed',
    ),
    'parentId': 'write:2',
  },
  {
    ...step(
      'write:2:validate',
      'pages.studio.progress.validateText',
      'completed',
    ),
    'parentId': 'write:2',
  },
  {
    ...step('write:2:save', 'pages.studio.progress.saveText', 'completed'),
    'parentId': 'write:2',
  },
  step('model:3', 'pages.studio.progress.analyze', 'completed'),
  step('reply:2', 'pages.studio.progress.reply', 'completed'),
];

void main() {
  for (final (language, index) in [('zh', 1), ('en', 2)]) {
    test('progress labels and outcome titles match Web in $language', () {
      final l10n = lookupAppLocalizations(Locale(language));
      for (final labels in [
        ['pages.studio.progress.prepare', '准备创作上下文', 'Preparing context'],
        ['pages.studio.progress.reply', '整理回复', 'Composing reply'],
        ['pages.studio.progress.saveText', '保存创作稿件', 'Saving written content'],
        ['pages.studio.progress.topics', '创作选题故事', 'Writing story ideas'],
        [
          'pages.studio.progress.readRole',
          '读取角色资料',
          'Reading character profiles',
        ],
        ['pages.studio.progress.updateRole', '更新角色资料', 'Updating character'],
        [
          'pages.studio.progress.saveRole',
          '保存角色档案',
          'Saving character profile',
        ],
        [
          'pages.studio.progress.readContext',
          '读取创作上下文',
          'Reading creation context',
        ],
        ['pages.studio.progress.askUser', '整理待确认信息', 'Preparing questions'],
        ['script.run.preparing', '正在准备…', 'Preparing…'],
        ['script.run.processing', '正在处理…', 'Processing…'],
      ]) {
        expect(conversationProgressLabel(labels.first, l10n), labels[index]);
      }
      expect(
        conversationProgressTitle(
          progress([
            step('old-failure', reading, 'failed'),
          ], state: 'completed'),
          l10n,
        ),
        language == 'zh' ? '已完成' : 'Completed',
      );
      expect(
        conversationProgressTitle(progress([], state: 'failed'), l10n),
        language == 'zh' ? '执行失败' : 'Failed',
      );
      expect(
        conversationProgressTitle(progress([], state: 'canceled'), l10n),
        language == 'zh' ? '已停止回复' : 'Reply stopped',
      );
      expect(
        conversationProgressTitle(progress([]), l10n),
        language == 'zh' ? '正在分析创作要求' : 'Analyzing your request',
      );
    });

    testWidgets('step status never changes its Web label in $language', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: ConversationProgressSteps(
              steps: [
                for (final state in [
                  'pending',
                  'running',
                  'waiting',
                  'completed',
                  'failed',
                  'skipped',
                ])
                  ConversationProgressStep(
                    id: state,
                    labelKey: reading,
                    status: state,
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(language == 'zh' ? '读取角色资料' : 'Reading character profiles'),
        findsNWidgets(6),
      );
      expect(find.text(language == 'zh' ? '已完成' : 'Done'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('running steps use Web rotation and respect reduced motion', (
    tester,
  ) async {
    Future<void> pumpProgress({
      bool reducedMotion = false,
      String status = 'running',
    }) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reducedMotion),
          child: child!,
        ),
        home: Scaffold(
          body: ConversationProgressSteps(
            steps: [
              ConversationProgressStep(
                id: 'execute',
                labelKey: processing,
                status: status,
              ),
            ],
          ),
        ),
      ),
    );

    await pumpProgress();
    await tester.pump();
    final glyph = find.byWidgetPredicate(
      (widget) =>
          widget is AppSvgIcon && widget.assetName == 'chat_progress_running',
    );
    expect(glyph, findsOneWidget);
    expect(tester.getSize(glyph), const Size(16, 16));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final rotation = tester.widget<RotationTransition>(
      find.ancestor(of: glyph, matching: find.byType(RotationTransition)),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(rotation.turns.value, closeTo(.25, .01));
    await tester.pump(const Duration(milliseconds: 250));
    expect(rotation.turns.value, closeTo(.5, .01));

    await pumpProgress(reducedMotion: true);
    await tester.pumpAndSettle();
    expect(rotation.turns.value, 0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(rotation.turns.value, 0);

    await pumpProgress();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(rotation.turns.value, closeTo(.25, .01));
    await pumpProgress(status: 'completed');
    await tester.pumpAndSettle();
    expect(glyph, findsNothing);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('script retry retains all 14 steps in chronological order', () {
    final block = progress(scriptRetrySteps, state: 'completed');
    final details = block.progressDetails;
    expect(details.map((s) => s.id), [
      'prepare',
      'model:1',
      'reply:1',
      'write:1',
      'write:1:materials',
      'model:2',
      'write:2',
      'write:2:materials',
      'write:2:skill',
      'write:2:model:1',
      'write:2:validate',
      'write:2:save',
      'model:3',
      'reply:2',
    ]);
    expect(details.where((s) => s.status == 'failed').map((s) => s.id), [
      'write:1',
      'write:1:materials',
    ]);
    expect(details.where((s) => s.status == 'completed'), hasLength(12));
    expect(details[4].parentId, 'write:1');
    expect(details[7].parentId, 'write:2');
    expect(scriptRetrySteps, hasLength(14));
  });

  test('generation task progress retains separate same-label executions', () {
    final block = ConversationBlock.fromJson({
      'type': 'object',
      'kind': 'task',
      'action': 'generation',
      'data': {'state': 'completed', 'progress': scriptRetrySteps},
    });
    expect(block.progressDetails, hasLength(14));
    expect(block.progressDetails[3].status, 'failed');
    expect(block.progressDetails[6].status, 'completed');
    expect(block.progressDetails.last.id, 'reply:2');
  });

  for (final width in [320.0, 390.0, 1024.0]) {
    testWidgets('all 14 retry steps remain ordered and reachable at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ConversationController(
        FixtureSessionRepository(),
        'u',
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ConversationObjectView(
              block: progress(scriptRetrySteps, state: 'completed'),
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('展开进度'));
      await tester.pumpAndSettle();
      var previousTop = double.negativeInfinity;
      for (final step in scriptRetrySteps) {
        final row = find.byKey(ValueKey((step['id'] as String, 0)));
        expect(row, findsOneWidget);
        final top = tester.getTopLeft(row).dy;
        expect(top, greaterThan(previousTop));
        previousTop = top;
      }
      expect(find.byIcon(Icons.error_outline), findsNWidgets(2));
      expect(find.byIcon(Icons.check), findsNWidgets(12));
      await tester.drag(
        find.byType(ConversationCardContent),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey(('reply:2', 0))).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  test('completed progress reads server waiting confirmation IDs', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    for (final waiting in [
      <String>[],
      ['confirmation'],
    ]) {
      final block = ConversationBlock.fromJson({
        'type': 'object',
        'kind': 'progress',
        'data': {
          'state': 'completed',
          'waitingConfirmations': waiting,
          'steps': [],
        },
      });
      expect(
        conversationProgressTitle(block, l10n),
        waiting.isEmpty ? l10n.chatCompleted : l10n.chatAwaitingConfirmation,
      );
    }
  });

  test(
    'nested actions keep their parent and terminal runs settle their states',
    () {
      final block = progress([
        step('root', 'pages.studio.progress.writeScript', 'running'),
        {
          ...step('child', 'pages.studio.progress.validateText', 'waiting'),
          'parentId': 'root',
        },
        {
          ...step('other', 'pages.studio.progress.validateText', 'completed'),
          'parentId': 'another-root',
        },
      ]);
      expect(
        block.progressDetails.map((s) => (s.labelKey, s.parentId, s.status)),
        [
          ('pages.studio.progress.writeScript', null, 'running'),
          ('pages.studio.progress.validateText', 'root', 'waiting'),
          ('pages.studio.progress.validateText', 'another-root', 'completed'),
        ],
      );
      expect(
        progress([
          step('root', reading, 'running'),
        ], state: 'cancelled').progressSteps,
        [(reading, 'skipped')],
      );
    },
  );

  testWidgets(
    'specific actions, waiting states and nested details fit narrow large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final block = progress([
        step('root', 'pages.studio.progress.writeScript', 'completed'),
        {
          ...step('child', 'pages.studio.progress.validateText', 'waiting'),
          'parentId': 'root',
        },
      ]);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Builder(
                builder: (context) {
                  final l10n = AppLocalizations.of(context)!;
                  expect(conversationProgressTitle(block, l10n), '校验正文、时长与结构');
                  return ConversationProgressSteps(
                    steps: block.progressDetails,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('编写剧本'), findsOneWidget);
      expect(find.text('校验正文、时长与结构'), findsOneWidget);
      expect(find.text('等待中'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  test('same-label steps retain server order and their individual states', () {
    final raw = [
      step('prepare', 'script.run.preparing', 'completed'),
      step('execute', processing, 'running'),
      step('tool-1', processing, 'completed'),
      step('read-1', reading, 'completed'),
      step('read-2', reading, 'waiting'),
    ];
    final block = progress(raw);
    expect(block.progressSteps, [
      ('script.run.preparing', 'completed'),
      (processing, 'running'),
      (processing, 'completed'),
      (reading, 'completed'),
      (reading, 'waiting'),
    ]);
    expect(raw.last['status'], 'waiting');
    expect(
      progress([
        step('call', reading, 'running'),
        step('call', reading, 'completed'),
      ]).progressSteps,
      [(reading, 'running'), (reading, 'completed')],
    );
    expect(
      progress([
        step('first', reading, 'completed'),
        step('second', reading, 'failed'),
      ]).progressSteps,
      [(reading, 'completed'), (reading, 'failed')],
    );
  });

  for (final state in [
    'completed',
    'failed',
    'interrupted',
    'canceled',
    'aborted',
  ]) {
    test('$state run ends stale active progress', () {
      final expected = state == 'completed'
          ? 'completed'
          : ['canceled', 'aborted'].contains(state)
          ? 'skipped'
          : 'failed';
      expect(
        progress([
          step('execute', processing, 'running'),
          step('tool', processing, 'waiting'),
        ], state: state).progressSteps,
        [(processing, expected), (processing, expected)],
      );
    });
  }

  test(
    'cumulative SSE updates replace phases in place and replays are idempotent',
    () {
      final initial = ConversationSnapshot.fromJson(
        chatSnapshotJson(
          seq: 1,
          messages: [
            message([
              step('execute', processing, 'running'),
              step('read', reading, 'running'),
            ], 1),
          ],
        ),
      );
      final event = chatEvent(2, 'tool.completed', {
        'timelineUpdates': [
          message([
            step('execute', processing, 'running'),
            step('read', reading, 'completed'),
            step('other', processing, 'completed'),
          ], 2),
        ],
      });
      final updated = applyConversationEvent(initial, event);
      expect(updated.messages, hasLength(1));
      expect(updated.messages.single.seq, initial.messages.single.seq);
      expect(updated.messages.single.blocks.single.progressSteps, [
        (processing, 'running'),
        (reading, 'completed'),
        (processing, 'completed'),
      ]);
      expect(applyConversationEvent(updated, event), same(updated));
      expect(
        progress([step('retry', reading, 'running')], attempt: 2).progressSteps,
        [(reading, 'running')],
      );
      expect(initial.messages.single.blocks.single.progressSteps, [
        (processing, 'running'),
        (reading, 'running'),
      ]);
    },
  );

  const labels = [
    'script.run.preparing',
    processing,
    'script.run.generatingReply',
    'script.run.savingArtifact',
    'script.run.planningGeneration',
    reading,
    'pages.studio.progress.readContext',
    'pages.studio.progress.topics',
    'pages.studio.progress.prepareRole',
    'pages.studio.progress.askUser',
    'pages.studio.progress.saveRole',
    'pages.studio.progress.publishRole',
    'pages.studio.progress.retryPrompt',
    'pages.studio.state.completed',
  ];
  for (final (size, dark, scale) in [
    (const Size(390, 844), false, 1.0),
    (const Size(320, 568), true, 1.5),
    (const Size(1280, 900), false, 1.0),
  ]) {
    testWidgets(
      'progress bounds and reading position survive updates and collapse at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final steps = [
          for (final label in labels) step(label, label, 'completed'),
        ];
        final current = ValueNotifier(
          progress([...steps, step('duplicate', processing, 'running')]),
        );
        addTearDown(current.dispose);
        final controller = ConversationController(
          FixtureSessionRepository(),
          'u',
        )..sessionId = chatId;
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: TextScaler.linear(scale),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: ListView(
                children: [
                  ValueListenableBuilder<ConversationBlock>(
                    valueListenable: current,
                    builder: (_, block, _) => ConversationObjectView(
                      key: const ValueKey('current-progress'),
                      block: block,
                      controller: controller,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('正在处理…'), findsNWidgets(3));
        final longLabel = tester.renderObject<RenderParagraph>(
          find.text('提示词编译中断，等待重试'),
        );
        expect(longLabel.maxLines, 1);
        expect(longLabel.overflow, TextOverflow.ellipsis);
        expect(longLabel.didExceedMaxLines, isTrue);
        final content = find.byType(ConversationCardContent);
        expect(
          tester.getSize(content).height,
          (size.height * .45).clamp(160.0, 360.0),
        );
        final scrollable = find.descendant(
          of: content,
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(scrollable).position;
        expect(position.extentAfter, lessThanOrEqualTo(1));
        current.value = progress([
          ...steps,
          step('duplicate', processing, 'completed'),
          step('latest', reading, 'running'),
        ]);
        await tester.pumpAndSettle();
        expect(position.extentAfter, lessThanOrEqualTo(1));
        expect(
          find.byKey(const ValueKey(('latest', 0))).hitTestable(),
          findsOneWidget,
        );
        await tester.drag(content, const Offset(0, 40));
        await tester.pumpAndSettle();
        final offset = position.pixels;
        expect(offset, greaterThan(0));
        expect(position.extentAfter, greaterThan(1));
        current.value = progress([
          ...steps,
          step('duplicate', processing, 'completed'),
          step('latest', reading, 'completed'),
          step('next', reading, 'completed'),
        ]);
        await tester.pumpAndSettle();
        expect(position.pixels, offset);
        expect(find.text('正在处理…'), findsNWidgets(2));
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.tap(find.byTooltip('收起进度'));
        await tester.pumpAndSettle();
        expect(content, findsNothing);
        await tester.tap(find.byTooltip('展开进度'));
        await tester.pumpAndSettle();
        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          offset,
        );
        await tester.drag(content, const Offset(0, -2000));
        await tester.pumpAndSettle();
        final restored = tester.state<ScrollableState>(scrollable).position;
        expect(restored.extentAfter, lessThanOrEqualTo(1));
        current.value = progress([
          ...steps,
          step('duplicate', processing, 'completed'),
          step('latest', reading, 'completed'),
          step('next', reading, 'completed'),
          step('resumed', reading, 'running'),
        ]);
        await tester.pumpAndSettle();
        expect(restored.extentAfter, lessThanOrEqualTo(1));
        current.value = progress([
          for (var index = 0; index < 30; index++)
            step('retry-$index', reading, 'completed'),
        ], attempt: 2);
        await tester.pumpAndSettle();
        expect(
          tester.state<ScrollableState>(scrollable).position.extentAfter,
          lessThanOrEqualTo(1),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
