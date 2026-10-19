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

void main() {
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
  test(
    'old snapshots merge repeated phases and keep concurrent active calls',
    () {
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
        (reading, 'waiting'),
      ]);
      expect(raw.last['status'], 'waiting');
      expect(
        progress([
          step('call', reading, 'running'),
          step('call', reading, 'completed'),
        ]).progressSteps,
        [(reading, 'completed')],
      );
      expect(
        progress([
          step('first', reading, 'completed'),
          step('second', reading, 'failed'),
        ]).progressSteps,
        [(reading, 'failed')],
      );
    },
  );

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
        [(processing, expected)],
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
        expect(find.text('正在处理你的需求'), findsNWidgets(2));
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
        await tester.drag(content, const Offset(0, -180));
        await tester.pumpAndSettle();
        final offset = position.pixels;
        expect(offset, greaterThan(0));
        current.value = progress([
          ...steps,
          step('duplicate', processing, 'completed'),
        ]);
        await tester.pumpAndSettle();
        expect(position.pixels, offset);
        expect(find.text('正在处理你的需求'), findsNothing);
        expect(find.text('处理需求'), findsOneWidget);
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
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
