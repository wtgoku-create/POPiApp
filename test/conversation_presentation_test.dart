import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/session/presentation/conversation_controller.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_timeline.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';

import 'conversation_events_test.dart' show chatSnapshotJson, chatMessageJson;
import 'support/session_fixtures.dart';

Map<String, Object?> _message(
  String id,
  int seq, {
  String text = '',
  String? presentation,
  int attempt = 1,
  List<Map<String, Object?>>? blocks,
}) => {
  ...chatMessageJson(seq: seq, text: text),
  'id': id,
  'attempt': attempt,
  if (presentation != null) 'presentation': presentation,
  if (blocks != null) 'blocks': blocks,
};

Map<String, Object?> _progress(
  int seq, {
  int attempt = 1,
  String state = 'completed',
}) => _message(
  'progress-$attempt',
  seq,
  attempt: attempt,
  blocks: [
    {
      'type': 'object',
      'kind': 'progress',
      'action': 'updated',
      'data': {'runId': 'run', 'attempt': attempt, 'state': state, 'steps': []},
    },
  ],
);

Map<String, Object?> _draft({int attempt = 1}) => _message(
  'draft-$attempt',
  2,
  attempt: attempt,
  blocks: [
    {
      'type': 'object',
      'kind': 'text_draft',
      'action': 'created',
      'data': {
        'id': 'saved',
        'kind': 'script',
        'content': 'Saved script',
        'delivery': 'reply',
      },
    },
  ],
);

ConversationSnapshot _snapshot(
  List<Map<String, Object?>> messages, {
  String state = 'completed',
  int attempt = 1,
}) => ConversationSnapshot.fromJson({
  ...chatSnapshotJson(seq: 10, messages: messages),
  'runs': [
    {
      'id': 'run',
      'purpose': 'consultation',
      'state': state,
      'attempt': attempt,
    },
  ],
});

class _Controller extends ConversationController {
  _Controller() : super(FixtureSessionRepository(), 'user');
  void publish(ConversationSnapshot value) {
    snapshot = value;
    notifyListeners();
  }

  void beginRefresh() {
    loading = true;
    notifyListeners();
  }
}

void main() {
  test(
    'process text, intro, reply and attachments keep their timeline positions',
    () {
      final snapshot = _snapshot([
        _progress(1),
        _message(
          'process',
          2,
          presentation: 'process',
          blocks: [
            {'type': 'text', 'text': 'Checking the character'},
            {'type': 'media', 'mediaId': 'image'},
          ],
        ),
        _message('intro', 3, presentation: 'intro', text: 'Please confirm'),
        _message('reply', 4, presentation: 'reply', text: 'Final answer'),
      ]);
      final original = jsonEncode(snapshot.source);
      expect(snapshot.presentationMessages.map((m) => m.id), [
        'progress-1',
        'process',
        'intro',
        'reply',
      ]);
      expect(snapshot.presentationMessages[1].blocks.map((b) => b.type), [
        'text',
        'media',
      ]);
      expect(snapshot.presentationMessages[1].text, 'Checking the character');
      expect(snapshot.presentationMessages.last.text, 'Final answer');
      expect(jsonEncode(snapshot.source), original);
    },
  );

  test('retry process text and orphan text stay visible in sequence', () {
    final snapshot = _snapshot([
      _progress(1),
      _message('first', 2, presentation: 'process', text: 'First attempt'),
      _progress(3, attempt: 2),
      _message(
        'second',
        4,
        attempt: 2,
        presentation: 'process',
        text: 'Second attempt',
      ),
      _message(
        'orphan',
        5,
        attempt: 3,
        presentation: 'process',
        text: 'No owner',
      ),
      _message('legacy', 6, text: 'Legacy reply'),
    ], attempt: 2);
    expect(snapshot.presentationMessages.map((m) => m.id), [
      'progress-1',
      'first',
      'progress-2',
      'second',
      'orphan',
      'legacy',
    ]);
  });

  test(
    'streaming and message classification keep acknowledgment standalone',
    () {
      for (final presentation in ['process', 'intro', 'reply']) {
        for (final state in ['running', 'completed']) {
          final snapshot = _snapshot([
            _progress(1, state: state),
            _message(
              'acknowledgment',
              2,
              presentation: presentation,
              text: '好，已选定《金牌压秤》，接着写剧本。',
            ),
          ], state: state);
          expect(snapshot.presentationMessages.map((m) => m.id), [
            'progress-1',
            'acknowledgment',
          ]);
          expect(snapshot.presentationMessages.last.text, '好，已选定《金牌压秤》，接着写剧本。');
        }
      }
    },
  );

  test('reply delivery waits for references and expands each draft once', () {
    final draft = _draft();
    expect(_snapshot([draft], state: 'running').presentationMessages, isEmpty);
    final snapshot = _snapshot([
      draft,
      _message(
        'reply',
        3,
        presentation: 'reply',
        text: 'Start\n\n[[text_draft:saved]]\n\n[[text_draft:saved]]\n\nEnd',
      ),
    ], state: 'running');
    final reply = snapshot.presentationMessages.single;
    expect(reply.id, 'reply');
    expect(reply.blocks.where((b) => b.kind == 'text_draft'), hasLength(1));
    expect(reply.blocks.first.text, 'Start');
    expect(reply.blocks.last.text, 'End');
    expect(snapshot.messages, hasLength(2));
  });

  test('every incomplete reference prefix stays hidden while streaming', () {
    const marker = '[[text_draft:saved]]';
    for (var end = 2; end < marker.length; end++) {
      final snapshot = _snapshot([
        _message(
          'reply',
          3,
          presentation: 'reply',
          text: 'Start\n\n${marker.substring(0, end)}',
        ),
      ], state: 'running');
      expect(
        snapshot.presentationMessages.single.text,
        'Start',
        reason: 'prefix $end',
      );
    }
    final snapshot = _snapshot([
      _message(
        'reply',
        3,
        presentation: 'reply',
        text: 'Start [[ordinary text',
      ),
    ]);
    expect(snapshot.presentationMessages.single.text, 'Start [[ordinary text');
  });

  test(
    'completed delivery appends omitted drafts without duplicating quoted bodies',
    () {
      for (final text in ['Final answer', 'Saved script']) {
        final snapshot = _snapshot([
          _draft(),
          _message('reply', 3, presentation: 'reply', text: text),
        ]);
        final reply = snapshot.presentationMessages.single;
        expect(reply.id, 'reply');
        expect(
          reply.blocks.where((b) => b.kind == 'text_draft'),
          hasLength(text == 'Saved script' ? 0 : 1),
        );
      }
    },
  );

  for (final state in ['failed', 'interrupted', 'canceled']) {
    test(
      '$state preserves saved drafts and partial output without a final reply',
      () {
        final snapshot = _snapshot([
          _progress(1, state: state),
          _draft(),
          _message(
            'partial',
            3,
            presentation: 'process',
            text: 'Partial output',
          ),
        ], state: state);
        expect(snapshot.presentationMessages.map((m) => m.id), [
          'progress-1',
          'draft-1',
          'partial',
        ]);
        expect(
          snapshot.presentationMessages[1].blocks.single.body,
          'Saved script',
        );
        expect(snapshot.presentationMessages.last.text, 'Partial output');
        final restored = ConversationSnapshot.fromJson(
          jsonDecode(jsonEncode(snapshot.source)) as Map<String, Object?>,
        );
        expect(
          restored.presentationMessages.map((m) => (m.id, m.text)),
          snapshot.presentationMessages.map((m) => (m.id, m.text)),
        );
      },
    );
  }

  test('an active retry cannot hide saved drafts from a failed attempt', () {
    final snapshot = _snapshot(
      [_draft(), _draft(attempt: 2)],
      state: 'running',
      attempt: 2,
    );
    expect(snapshot.presentationMessages.single.id, 'draft-1');
  });

  for (final width in [320.0, 390.0, 1024.0]) {
    testWidgets(
      'acknowledgment stays outside progress when toggling and refreshing at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = _Controller()
          ..publish(
            _snapshot([
              _progress(1),
              _message(
                'process',
                2,
                presentation: 'process',
                text: '好，已选定《金牌压秤》，接着写剧本。',
              ),
              _message('reply', 3, presentation: 'reply', text: 'Final answer'),
            ]),
          );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ConversationTimeline(controller: controller)),
          ),
        );
        await tester.pumpAndSettle();
        Finder markdown(String text) => find.byWidgetPredicate(
          (w) => w is MarkdownMessage && w.text == text,
        );
        final acknowledgment = markdown('好，已选定《金牌压秤》，接着写剧本。');
        expect(acknowledgment, findsOneWidget);
        expect(markdown('Final answer'), findsOneWidget);
        await tester.tap(find.byTooltip('展开进度'));
        await tester.pumpAndSettle();
        final details = find.byKey(const Key('conversation-progress-details'));
        expect(
          find.descendant(of: details, matching: acknowledgment),
          findsNothing,
        );
        expect(
          tester.getRect(details).overlaps(tester.getRect(acknowledgment)),
          isFalse,
        );
        await tester.tap(find.byTooltip('收起进度'));
        await tester.pumpAndSettle();
        expect(details, findsNothing);
        expect(acknowledgment, findsOneWidget);
        controller.beginRefresh();
        await tester.pump();
        expect(markdown('Final answer').hitTestable(), findsOneWidget);
        expect(acknowledgment, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
