import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/session/data/conversation_events.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/session/presentation/conversation_controller.dart';

import 'conversation_events_test.dart'
    show chatId, chatSnapshotJson, chatMessageJson, chatEvent;
import 'support/session_fixtures.dart';

Future<void> flushConversation() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class StreamingSessionRepository extends FixtureSessionRepository {
  int snapshots = 0;
  int sends = 0;
  int stops = 0;
  int retries = 0;
  bool failSend = false;
  Map<String, Object?> data = chatSnapshotJson(
    seq: 1,
    messages: [chatMessageJson()],
  );
  final streams = <StreamController<ConversationEvent>>[];
  final cursors = <int>[];
  final tokens = <CancelToken>[];
  Completer<ConversationSnapshot>? delayedSnapshot;
  List<String>? sentMediaIds;
  List<String>? sentRoleIds;
  @override
  Future<ConversationSnapshot> snapshot(
    String id, {
    CancelToken? cancelToken,
  }) async {
    snapshots++;
    if (delayedSnapshot != null) return delayedSnapshot!.future;
    return ConversationSnapshot.fromJson({
      ...data,
      'session': {...data['session'] as Map, 'id': id},
    });
  }

  @override
  Stream<ConversationEvent> events(
    String id,
    int afterSeq,
    CancelToken cancelToken, {
    void Function()? onConnected,
  }) {
    cursors.add(afterSeq);
    tokens.add(cancelToken);
    final stream = StreamController<ConversationEvent>();
    streams.add(stream);
    onConnected?.call();
    return stream.stream;
  }

  @override
  Future<void> send(
    String userId,
    String id,
    String text,
    List<String> mediaIds, {
    List<String> roleIds = const [],
    CancelToken? cancelToken,
  }) async {
    sends++;
    sentMediaIds = mediaIds;
    sentRoleIds = List.of(roleIds);
    if (failSend) throw StateError('offline');
  }

  @override
  Future<void> stop(
    String userId,
    String id, {
    CancelToken? cancelToken,
  }) async {
    stops++;
  }

  @override
  Future<void> retry(
    String userId,
    String runId, {
    CancelToken? cancelToken,
  }) async {
    retries++;
  }

  Future<void> close() async {
    for (final stream in streams) {
      unawaited(stream.close());
    }
  }
}

void main() {
  late StreamingSessionRepository repository;
  late ConversationController controller;
  setUp(() {
    repository = StreamingSessionRepository();
    controller = ConversationController(
      repository,
      'a',
      reconnectDelay: const Duration(milliseconds: 1),
    );
  });
  tearDown(() async {
    controller.dispose();
    await repository.close();
    await flushConversation();
  });

  test(
    'initial state is empty, snapshot restores and SSE updates the same message',
    () async {
      expect(controller.snapshot, isNull);
      expect(controller.connection, ConversationConnection.offline);
      controller.open(chatId);
      await flushConversation();
      expect(controller.connection, ConversationConnection.connected);
      expect(repository.cursors, [1]);
      repository.streams.single.add(
        chatEvent(2, 'message.delta', {
          'messageId': 'assistant',
          'delta': 'Hello',
        }),
      );
      await flushConversation();
      expect(controller.snapshot!.messages.single.text, 'Hello');
    },
  );

  test('disconnect reconnects from last processed sequence', () async {
    controller.open(chatId);
    await flushConversation();
    repository.streams.first.add(
      chatEvent(2, 'message.delta', {
        'messageId': 'assistant',
        'delta': 'Hello',
      }),
    );
    await flushConversation();
    await repository.streams.first.close();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await flushConversation();
    expect(repository.cursors, [1, 2]);
    expect(repository.snapshots, 1);
    repository.streams.last.add(
      chatEvent(3, 'message.delta', {
        'messageId': 'assistant',
        'delta': ' again',
      }),
    );
    await flushConversation();
    expect(controller.snapshot!.messages.single.text, 'Hello again');
  });

  test('sequence gaps load a new snapshot before reconnecting', () async {
    controller.open(chatId);
    await flushConversation();
    repository.data = chatSnapshotJson(
      seq: 5,
      messages: [chatMessageJson(text: 'Recovered', revision: 5)],
    );
    repository.streams.first.add(
      chatEvent(5, 'message.delta', {
        'messageId': 'assistant',
        'delta': 'missing events',
      }),
    );
    await flushConversation();
    expect(repository.snapshots, 2);
    expect(repository.cursors, [1, 5]);
    expect(controller.snapshot!.messages.single.text, 'Recovered');
  });

  test(
    'switching sessions cancels the old stream and ignores late replies',
    () async {
      controller.open(chatId);
      await flushConversation();
      final lateSnapshot = Completer<ConversationSnapshot>();
      repository.delayedSnapshot = lateSnapshot;
      controller.refresh();
      await flushConversation();
      repository.delayedSnapshot = null;
      repository.data = chatSnapshotJson(seq: 0, timeline: false);
      controller.open('second');
      await flushConversation();
      expect(repository.tokens.first.isCancelled, isTrue);
      lateSnapshot.complete(
        ConversationSnapshot.fromJson(
          chatSnapshotJson(
            seq: 8,
            messages: [chatMessageJson(text: 'Old account')],
          ),
        ),
      );
      await flushConversation();
      expect(controller.sessionId, 'second');
      expect(controller.snapshot!.session.id, 'second');
      expect(controller.snapshot!.messages, isEmpty);
      controller.open(null);
      expect(controller.snapshot, isNull);
      expect(controller.connection, ConversationConnection.offline);
    },
  );

  test(
    'running consultation prevents a second send and stop refreshes history',
    () async {
      controller.open(chatId);
      await flushConversation();
      repository.streams.first.add(
        chatEvent(2, 'run.started', {
          'runId': 'run',
          'purpose': 'consultation',
        }),
      );
      await flushConversation();
      expect(controller.running, isTrue);
      expect(await controller.send('second', [], 'New', 'Images'), isFalse);
      expect(repository.sends, 0);
      expect(await controller.stop(), isTrue);
      await flushConversation();
      expect(repository.stops, 1);
      expect(controller.snapshot, isNotNull);
    },
  );

  test(
    'failed send exposes error, keeps session and releases pending state',
    () async {
      repository.data = chatSnapshotJson(timeline: false);
      repository.failSend = true;
      expect(await controller.send('Hello', [], 'New', 'Images'), isFalse);
      expect(controller.sessionId, isNotNull);
      expect(controller.error, isA<StateError>());
      expect(controller.pending, isFalse);
      repository.failSend = false;
      expect(
        await controller.send(
          'Hello',
          [],
          'New',
          'Images',
          roleIds: ['2', '1'],
        ),
        isTrue,
      );
      expect(repository.sentRoleIds, ['2', '1']);
      await flushConversation();
      expect(repository.sends, 2);
      expect(controller.error, isNull);
    },
  );
}
