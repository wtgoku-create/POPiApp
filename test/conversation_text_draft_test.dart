import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/session/data/conversation_events.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/session/presentation/conversation_controller.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_card_content.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_timeline.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_role_card.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';

import 'conversation_events_test.dart'
    show chatEvent, chatMessageJson, chatSnapshotJson;
import 'support/session_fixtures.dart';

Map<String, Object?> _draft(
  String id, {
  int seq = 43,
  String run = 'run',
  int? attempt,
  String? content,
}) => {
  ...chatMessageJson(seq: seq),
  'id': 'draft-$run-$id-$seq',
  'runId': run,
  if (attempt != null) 'attempt': attempt,
  'blocks': [
    {
      'type': 'object',
      'kind': 'text_draft',
      'action': 'created',
      'data': {
        'id': id,
        'kind': 'topic',
        'title': 'Candidate $id',
        'content':
            content ?? 'Story $id\n\nCharacter fit $id\n\nHighlights $id',
        'delivery': 'reply',
        'durationSeconds': 15,
      },
    },
  ],
};

Map<String, Object?> _reply({
  String run = 'run',
  int seq = 44,
  int? attempt,
  String text =
      'Introduction\n\n[[text_draft:1]]\n\n[[text_draft:2]]\n\n'
      '[[text_draft:3]]\n\nChoose a direction.',
}) => {
  ...chatMessageJson(seq: seq, text: text),
  'id': 'reply-$run-$seq',
  'runId': run,
  if (attempt != null) 'attempt': attempt,
  'presentation': 'reply',
};

ConversationSnapshot _snapshot(List<Map<String, Object?>> messages) =>
    ConversationSnapshot.fromJson(
      chatSnapshotJson(seq: 44, messages: messages),
    );

ConversationSnapshot _example() =>
    _snapshot([_draft('2'), _draft('1'), _draft('3'), _reply()]);

class _Controller extends ConversationController {
  _Controller() : super(FixtureSessionRepository(), 'user');

  void publish(ConversationSnapshot value) {
    snapshot = value;
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'cast messages retain nonblank text above grouped role cards and explicit clears',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _Controller()
        ..publish(
          _snapshot([
            {
              ...chatMessageJson(seq: 1),
              'id': 'cast',
              'role': 'user',
              'blocks': [
                {'type': 'text', 'text': 'Use these roles'},
                {'type': 'text', 'text': '  \n  '},
                for (final id in [1, 2])
                  {
                    'type': 'object',
                    'kind': 'role',
                    'action': 'cast',
                    'data': {
                      'ref': {'kind': 'character', 'id': id},
                      'title': 'Role $id',
                      'profile': {},
                    },
                  },
              ],
            },
            {
              ...chatMessageJson(seq: 2, text: 'Clear the cast'),
              'id': 'clear',
              'role': 'user',
            },
          ]),
        );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ConversationTimeline(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      final text = find.byWidgetPredicate(
        (w) => w is MarkdownMessage && w.text == 'Use these roles',
      );
      expect(text, findsOneWidget);
      final cast = find.byType(ConversationCastCard);
      expect(
        tester
            .widget<ConversationCastCard>(cast)
            .blocks
            .map((block) => block.title),
        ['Role 1', 'Role 2'],
      );
      expect(
        tester.getBottomLeft(text).dy,
        lessThanOrEqualTo(tester.getTopLeft(cast).dy),
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is MarkdownMessage && w.text.trim().isEmpty,
        ),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is MarkdownMessage && w.text == 'Clear the cast',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  test('draft bodies and references follow reply order without duplicates', () {
    final snapshot = _example();
    final source = snapshot.messages;
    final reply = snapshot.presentationMessages.single;
    expect(source, hasLength(4));
    expect(source.first.blocks.single.id, '2');
    expect(source.last.text, contains('[[text_draft:1]]'));
    expect(reply.id, 'draft-run-2-43');
    expect(reply.seq, 44);
    expect(reply.revision, 1);
    expect(reply.presentation, 'reply');
    expect(reply.blocks.map((block) => block.type), [
      'text',
      'object',
      'object',
      'object',
      'text',
    ]);
    expect(
      reply.blocks
          .where((block) => block.type == 'object')
          .map((block) => (block.id, block.body)),
      [
        for (final id in ['1', '2', '3'])
          (id, 'Story $id\n\nCharacter fit $id\n\nHighlights $id'),
      ],
    );
    expect(reply.blocks.first.text, 'Introduction');
    expect(reply.blocks.last.text, 'Choose a direction.');
  });

  test('unreferenced drafts and user text remain visible', () {
    final user = {
      ..._reply(text: 'Keep [[text_draft:1]] as text'),
      'id': 'user',
      'role': 'user',
    };
    final snapshot = _snapshot([_draft('1'), _draft('2'), user]);
    expect(snapshot.presentationMessages, hasLength(2));
    expect(
      snapshot.presentationMessages.first.blocks.map((block) => block.id),
      ['1', '2'],
    );
    expect(
      snapshot.presentationMessages.last.text,
      'Keep [[text_draft:1]] as text',
    );
    final referenced = _snapshot([
      _draft('1'),
      _draft('2'),
      _reply(text: '[[text_draft:1]]'),
    ]).presentationMessages;
    expect(referenced, hasLength(1));
    expect(referenced.single.blocks.map((block) => block.id), ['1', '2']);
  });

  test('local draft IDs resolve within their run and attempt', () {
    final messages = [
      _draft('1', seq: 1, run: 'old', content: 'Old run'),
      _reply(seq: 2, run: 'old', text: '[[text_draft:1]]'),
      _draft('1', seq: 3, attempt: 1, content: 'Old attempt'),
      _draft('1', seq: 4, attempt: 2, content: 'Current attempt'),
      _reply(seq: 5, attempt: 2, text: '[[text_draft:1]]'),
    ];
    final displayed = _snapshot(messages).presentationMessages;
    expect(displayed.first.blocks.single.body, 'Old run');
    expect(displayed.last.blocks.single.body, 'Current attempt');
    final missing = _snapshot([
      _draft('1', run: 'old'),
      _reply(text: 'Introduction [[text_draft:1]] Closing'),
    ]).presentationMessages;
    expect(missing.first.blocks.single.body, startsWith('Story 1'));
    expect(missing.last.blocks.map((block) => block.text), [
      'Introduction',
      'Closing',
    ]);
  });

  test('draft groups stay separate across attempts and completed replies', () {
    final attempts = _snapshot([
      _draft('1', seq: 1, attempt: 1),
      _draft('2', seq: 2, attempt: 2),
    ]);
    expect(attempts.presentationMessages, hasLength(2));
    final batches = _snapshot([
      _draft('1', seq: 1),
      _reply(seq: 2, text: 'First [[text_draft:1]]'),
      _draft('2', seq: 3),
      _reply(seq: 4, text: 'Second [[text_draft:2]]'),
    ]);
    expect(batches.presentationMessages.map((message) => message.id), [
      'draft-run-1-1',
      'draft-run-2-3',
    ]);
    expect(batches.messages, hasLength(4));
  });

  test('repeated references retain unique presentation message identities', () {
    final displayed = _snapshot([
      _draft('1', seq: 1),
      _reply(seq: 2, text: 'First [[text_draft:1]]'),
      _reply(seq: 3, text: 'Again [[text_draft:1]]'),
    ]).presentationMessages;
    expect(displayed, hasLength(2));
    expect(displayed.map((message) => message.id).toSet(), hasLength(2));
    expect(displayed.map((message) => message.blocks.last.id), ['1', '1']);
  });

  test(
    'streamed references in separate text blocks do not duplicate drafts',
    () {
      final snapshot = _snapshot([
        _draft('1'),
        _draft('2'),
        _draft('3'),
        {
          ..._reply(),
          'transient': true,
          'blocks': [
            {'type': 'text', 'text': 'Introduction'},
            {'type': 'text', 'text': '[[text_draft:1]]'},
            {'type': 'text', 'text': '[[text_draft:2]]'},
          ],
        },
      ]);
      final displayed = snapshot.presentationMessages.single;
      expect(displayed.id, 'draft-run-1-43');
      expect(
        displayed.blocks
            .where((block) => block.type == 'object')
            .map((block) => block.id),
        ['1', '2', '3'],
      );
      expect(displayed.blocks.first.text, 'Introduction');
      expect(snapshot.messages, hasLength(4));
    },
  );

  test('streamed partial references resolve after late timeline updates', () {
    var snapshot = _snapshot([_reply(text: 'Introduction\n\n[[text_draft:1')]);
    expect(snapshot.presentationMessages.single.text, 'Introduction');
    snapshot = applyConversationEvent(
      snapshot,
      chatEvent(45, 'message.delta', {
        'messageId': 'reply-run-44',
        'delta': ']]\n\nClosing',
      }),
    );
    expect(
      snapshot.presentationMessages.single.text,
      'Introduction\n\nClosing',
    );
    snapshot = applyConversationEvent(
      snapshot,
      chatEvent(46, 'message.updated', {
        'timelineUpdates': [
          {..._draft('1', seq: 46), 'revision': 46},
        ],
      }),
    );
    final reply = snapshot.presentationMessages.single;
    expect(reply.id, 'reply-run-44');
    expect(reply.blocks.map((block) => block.type), ['text', 'object', 'text']);
    expect(reply.blocks[1].body, contains('Character fit 1'));
    expect(snapshot.messages, hasLength(2));
  });

  for (final width in [320.0, 390.0, 1024.0]) {
    testWidgets('inline drafts share a switchable card at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = _Controller()..publish(_snapshot([_draft('2')]));
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ConversationTimeline(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ConversationObjectView), findsOneWidget);
      expect(find.byKey(const Key('conversation-topic-next')), findsNothing);
      final cardGroup = find.byKey(
        const ValueKey(('draft-run-2-43', 'topics', 0)),
      );
      final originalCardState = tester.state(cardGroup);
      controller.publish(_snapshot([_draft('2'), _draft('1')]));
      await tester.pumpAndSettle();
      expect(find.text('1/2'), findsOneWidget);
      expect(tester.state(cardGroup), same(originalCardState));
      controller.publish(_snapshot([_draft('2'), _draft('1'), _draft('3')]));
      await tester.pumpAndSettle();
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('Candidate 2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('conversation-topic-next')));
      await tester.pumpAndSettle();
      controller.publish(
        _snapshot([
          _draft('2'),
          _draft('1'),
          _draft('3'),
          {..._reply(text: 'Introduction'), 'transient': true},
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ConversationObjectView), findsOneWidget);
      expect(find.text('Candidate 1'), findsOneWidget);
      expect(tester.state(cardGroup), same(originalCardState));
      final streamingIntro = find.byWidgetPredicate(
        (widget) => widget is MarkdownMessage && widget.text == 'Introduction',
      );
      expect(
        tester.getTopLeft(streamingIntro).dy,
        lessThan(tester.getTopLeft(find.text('Candidate 1')).dy),
      );
      controller.publish(
        _snapshot([
          _draft('2'),
          {
            ..._reply(
              text: 'Introduction\n\n[[text_draft:1]]\n\n[[text_draft:',
            ),
            'transient': true,
          },
          _draft('1', seq: 45),
          _draft('3', seq: 46),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ConversationObjectView), findsOneWidget);
      expect(find.text('Candidate 1'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(tester.state(cardGroup), same(originalCardState));
      controller.publish(_example());
      await tester.pumpAndSettle();
      final cards = tester
          .widgetList<ConversationObjectView>(
            find.byType(ConversationObjectView),
          )
          .toList();
      expect(cards.map((card) => card.block.id), ['1']);
      expect(tester.state(cardGroup), same(originalCardState));
      final text = tester.widgetList<MarkdownMessage>(
        find.byType(MarkdownMessage),
      );
      expect(
        text.map((widget) => widget.text).join(),
        isNot(contains('text_draft:')),
      );
      final intro = find.byWidgetPredicate(
        (widget) => widget is MarkdownMessage && widget.text == 'Introduction',
      );
      expect(
        tester.getTopLeft(intro).dy,
        lessThan(tester.getTopLeft(find.text('Candidate 1')).dy),
      );
      expect(find.byType(ConversationCardContent), findsOneWidget);
      expect(find.byKey(const Key('conversation-topic-select')), findsNothing);
      final previous = find.byKey(const Key('conversation-topic-previous'));
      final next = find.byKey(const Key('conversation-topic-next'));
      expect(find.text('1/3'), findsOneWidget);
      expect(tester.widget<IconButton>(previous).onPressed, isNull);
      final card = tester.getRect(find.byType(ConversationObjectView));
      final button = tester.getRect(next);
      expect(button.top, closeTo(card.top + 20, .01));
      expect(button.right, closeTo(card.right - 20, .01));
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('Candidate 1'), findsNothing);
      expect(find.text('Candidate 2'), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);
      expect(
        tester
            .widgetList<MarkdownMessage>(find.byType(MarkdownMessage))
            .where((widget) => widget.text.startsWith('Story 2')),
        hasLength(1),
      );
      controller.publish(
        _snapshot([
          _draft('2'),
          _draft('1'),
          _draft('3'),
          _reply(
            text:
                'Updated introduction\n\n[[text_draft:3]]\n\n'
                '[[text_draft:1]]\n\n[[text_draft:2]]\n\nChoose a direction.',
          ),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Candidate 2'), findsOneWidget);
      expect(find.text('3/3'), findsOneWidget);
      expect(tester.widget<IconButton>(next).onPressed, isNull);
      await tester.tap(previous);
      await tester.pumpAndSettle();
      expect(find.text('Candidate 1'), findsOneWidget);
      controller.publish(
        _snapshot([_draft('1'), _reply(text: '[[text_draft:1]]')]),
      );
      await tester.pumpAndSettle();
      expect(find.text('Candidate 1'), findsOneWidget);
      expect(next, findsNothing);
      expect(previous, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('long draft body stays bounded and scrolls within its card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final body = List.generate(
      40,
      (index) => 'Story direction $index',
    ).join('\n\n');
    final controller = _Controller()
      ..publish(
        _snapshot([
          _draft('1', content: body),
          _draft('2', content: body),
          _reply(text: '[[text_draft:1]]\n\n[[text_draft:2]]'),
        ]),
      );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(body: ConversationTimeline(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    final content = find.byType(ConversationCardContent);
    expect(tester.getSize(content).height, lessThanOrEqualTo(320));
    expect(
      tester.widget<MarkdownMessage>(find.byType(MarkdownMessage)).text,
      body,
    );
    final scroll = find.descendant(
      of: content,
      matching: find.byType(SingleChildScrollView),
    );
    final scrollController = tester
        .widget<SingleChildScrollView>(scroll)
        .controller!;
    final offsetBefore = scrollController.offset;
    await tester.drag(scroll, const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(scrollController.offset, greaterThan(offsetBefore));
    final savedOffset = scrollController.offset;
    controller.publish(
      _snapshot([
        _draft('1', content: body),
        _draft('2', content: body),
        _reply(
          text:
              'Updated introduction [[text_draft:2]]\n\n[[text_draft:1]] Closing',
        ),
      ]),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<SingleChildScrollView>(scroll).controller,
      same(scrollController),
    );
    expect(scrollController.offset, closeTo(savedOffset, .01));
    expect(tester.takeException(), isNull);
  });
}
