import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/agent_api_exception.dart';
import 'package:popi_ai_app/features/session/data/conversation_events.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';

const chatId = '00000000-0000-4000-8000-000000000201';
const chatDate = '2026-10-09T00:00:00.000Z';

Map<String, Object?> chatSnapshotJson({
  int seq = 0,
  bool timeline = true,
  List<Map<String, Object?>> messages = const [],
}) => {
  'session': {
    'id': chatId,
    'title': 'Conversation',
    'revision': 1,
    'updatedAt': chatDate,
  },
  'lastSeq': seq,
  if (timeline) 'timelineVersion': 1,
  timeline ? 'timelineMessages' : 'messages': messages,
  'runs': [],
};

Map<String, Object?> chatMessageJson({
  String text = '',
  int revision = 1,
  int seq = 1,
}) => {
  'id': 'assistant',
  'sessionId': chatId,
  'seq': seq,
  'revision': revision,
  'role': 'assistant',
  'runId': 'run',
  'createdAt': chatDate,
  'blocks': [
    {'type': 'text', 'text': text},
  ],
};

ConversationEvent chatEvent(
  int seq,
  String type,
  Map<String, Object?> payload, {
  String sessionId = chatId,
}) => ConversationEvent.fromJson({
  'eventId': 'event-$seq',
  'sessionId': sessionId,
  'seq': seq,
  'type': type,
  'payload': payload,
  'taskId': null,
  'stateVersion': 1,
  'occurredAt': chatDate,
});

void main() {
  test(
    'SSE handles byte-split UTF-8, CRLF, comments, multiline data and a BOM',
    () async {
      final event = jsonEncode(
        chatEvent(1, 'message.delta', {
          'messageId': 'assistant',
          'delta': '你好',
        }).source,
      );
      final text =
          '\uFEFF: ping\r\nid: event-1\r\nevent: message.delta\r\ndata: ${event.substring(0, event.indexOf('"payload"'))}\r\ndata: ${event.substring(event.indexOf('"payload"'))}\r\n\r\n';
      final bytes = utf8.encode(text);
      final events = await decodeConversationEvents(
        Stream.fromIterable(bytes.map((byte) => [byte])),
      ).toList();
      expect(events.length, 1);
      expect(events.single.payload['delta'], '你好');
      expect(events.single.seq, 1);
    },
  );

  test(
    'incomplete frames are replayed after reconnect and never partially applied',
    () async {
      final bytes = utf8.encode(
        'data: ${jsonEncode(chatEvent(1, 'run.started', {'runId': 'run'}).source)}\n',
      );
      expect(
        await decodeConversationEvents(Stream.value(bytes)).toList(),
        isEmpty,
      );
    },
  );

  test(
    'duplicates and foreign events are ignored; gaps require a new snapshot',
    () {
      final initial = ConversationSnapshot.fromJson(
        chatSnapshotJson(seq: 1, messages: [chatMessageJson()]),
      );
      final event = chatEvent(2, 'message.delta', {
        'messageId': 'assistant',
        'delta': 'hello',
      });
      final next = applyConversationEvent(initial, event);
      expect(next.messages.single.text, 'hello');
      expect(applyConversationEvent(next, event), same(next));
      expect(
        applyConversationEvent(
          next,
          chatEvent(3, 'message.delta', const {}, sessionId: 'other'),
        ),
        same(next),
      );
      expect(
        () => applyConversationEvent(
          next,
          chatEvent(4, 'run.completed', {'runId': 'run'}),
        ),
        throwsA(
          isA<AgentApiException>().having(
            (error) => error.code,
            'code',
            'SNAPSHOT_REQUIRED',
          ),
        ),
      );
    },
  );

  test(
    'timeline revisions update contents without moving their original anchor',
    () {
      final initial = ConversationSnapshot.fromJson(
        chatSnapshotJson(seq: 1, messages: [chatMessageJson(text: 'old')]),
      );
      final next = applyConversationEvent(
        initial,
        chatEvent(2, 'message.updated', {
          'timelineUpdates': [
            chatMessageJson(text: 'new', revision: 2, seq: 9),
          ],
        }),
      );
      expect(next.messages.single.text, 'new');
      expect(next.messages.single.seq, 1);
      final stale = applyConversationEvent(
        next,
        chatEvent(3, 'message.updated', {
          'timelineUpdates': [chatMessageJson(text: 'stale', revision: 1)],
        }),
      );
      expect(stale.messages.single.text, 'new');
    },
  );

  test(
    'delta accompanied by the same timeline update is not appended twice',
    () {
      final initial = ConversationSnapshot.fromJson(
        chatSnapshotJson(seq: 1, messages: [chatMessageJson()]),
      );
      final next = applyConversationEvent(
        initial,
        chatEvent(2, 'message.delta', {
          'messageId': 'assistant',
          'delta': 'hello',
          'timelineUpdates': [chatMessageJson(text: 'hello', revision: 2)],
        }),
      );
      expect(next.messages.single.text, 'hello');
    },
  );

  test('missing message anchor requests snapshot recovery', () {
    final initial = ConversationSnapshot.fromJson(chatSnapshotJson());
    expect(
      () => applyConversationEvent(
        initial,
        chatEvent(1, 'message.delta', {
          'messageId': 'missing',
          'delta': 'text',
        }),
      ),
      throwsA(isA<AgentApiException>()),
    );
  });

  test(
    'legacy streams retain partial output on stop and recover from saved snapshots',
    () {
      var snapshot = ConversationSnapshot.fromJson(
        chatSnapshotJson(timeline: false),
      );
      snapshot = applyConversationEvent(
        snapshot,
        chatEvent(1, 'run.started', {
          'runId': 'run',
          'purpose': 'consultation',
        }),
      );
      expect(snapshot.running, isTrue);
      snapshot = applyConversationEvent(
        snapshot,
        chatEvent(2, 'message.delta', {'runId': 'run', 'delta': 'partial'}),
      );
      snapshot = applyConversationEvent(
        snapshot,
        chatEvent(3, 'run.interrupted', {'runId': 'run', 'retryable': true}),
      );
      expect(snapshot.running, isFalse);
      expect(snapshot.messages.single.text, 'partial');
      expect(snapshot.messages.single.transient, isFalse);
      final restored = ConversationSnapshot.fromJson(
        jsonDecode(jsonEncode(snapshot.source)) as Map<String, Object?>,
      );
      expect(restored.messages.single.text, 'partial');
      expect(restored.runs.single.retryable, isTrue);
    },
  );
}
