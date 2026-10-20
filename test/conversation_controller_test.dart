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
  bool failSnapshot = false;
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
    if (failSnapshot) throw StateError('offline');
    if (delayedSnapshot != null) return delayedSnapshot!.future;
    return ConversationSnapshot.fromJson({
      ...data,
      'session': {...data['session'] as Map, 'id': id},
      if (data['timelineVersion'] == 1)
        'timelineMessages': [
          for (final message in data['timelineMessages'] as List)
            {...message as Map, 'sessionId': id},
        ],
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
    'assistant deltas, progress and failed send do not update list activity',
    () async {
      controller.dispose();
      final changes = <DateTime?>[];
      controller = ConversationController(
        repository,
        'a',
        onSessionChanged: (session) => changes.add(session.lastMessageAt),
      );
      controller.open(chatId);
      await flushConversation();
      expect(changes, [null]);
      repository.streams.single.add(
        chatEvent(2, 'message.delta', {
          'messageId': 'assistant',
          'delta': 'Hello',
        }),
      );
      repository.streams.single.add(
        chatEvent(3, 'home.task.progress', {'progress': 10}),
      );
      await flushConversation();
      expect(changes, [null]);
      repository.failSend = true;
      await controller.send('Failed message', [], 'New', 'Media');
      expect(changes, [null]);
      repository.streams.single.add(
        chatEvent(4, 'topic.adopted', {
          'lastMessageAt': '2026-10-16T12:00:00Z',
        }),
      );
      await flushConversation();
      expect(changes, [null, DateTime.parse('2026-10-16T12:00:00Z')]);
      expect(repository.snapshots, 1);
    },
  );

  test(
    'reconnecting reports a request failure once until connection recovers',
    () async {
      controller.dispose();
      final errors = <Object>[];
      controller = ConversationController(
        repository,
        'a',
        onError: errors.add,
        reconnectDelay: const Duration(milliseconds: 1),
      );
      repository.failSnapshot = true;
      controller.open(chatId);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(repository.snapshots, greaterThan(1));
      expect(errors, hasLength(1));
      repository.failSnapshot = false;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(controller.connection, ConversationConnection.connected);
      repository.streams.single.addError(StateError('disconnected'));
      await flushConversation();
      expect(errors, hasLength(2));
    },
  );

  test(
    'commands report failure once and obsolete requests remain silent',
    () async {
      controller.dispose();
      final errors = <Object>[];
      controller = ConversationController(repository, 'a', onError: errors.add);
      expect(
        await controller.act((_) async => throw StateError('failed')),
        isFalse,
      );
      expect(errors, hasLength(1));
      final command = Completer<void>();
      final result = controller.act((_) => command.future);
      controller.open(null);
      command.completeError(StateError('obsolete'));
      expect(await result, isFalse);
      expect(errors, hasLength(1));
    },
  );

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

  test('an empty draft creates its conversation only when sending', () async {
    controller.open(null);
    expect(controller.sessionId, isNull);
    expect(repository.sends, 0);
    final previous = (await repository.list('a')).items.length;
    expect(
      await controller.send('Create a video', [], 'New conversation', 'Media'),
      isTrue,
    );
    expect(controller.sessionId, isNotNull);
    expect((await repository.list('a')).items, hasLength(previous + 1));
    expect(repository.sends, 1);
  });

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
    'refresh retains history until an authoritative replacement arrives',
    () async {
      controller.open(chatId);
      await flushConversation();
      final previous = controller.snapshot;
      final result = Completer<ConversationSnapshot>();
      repository.delayedSnapshot = result;
      controller.refresh();
      expect(controller.snapshot, same(previous));
      expect(controller.loading, isTrue);
      result.complete(
        ConversationSnapshot.fromJson(chatSnapshotJson(seq: 2, messages: [])),
      );
      await flushConversation();
      expect(controller.snapshot!.messages, isEmpty);
      expect(controller.snapshot!.lastSeq, 2);
      expect(controller.loading, isFalse);
      expect(repository.cursors, [1, 2]);
    },
  );

  test(
    'failed and stale refreshes retain newer text and cursor until recovery',
    () async {
      controller.open(chatId);
      await flushConversation();
      repository.streams.first.add(
        chatEvent(2, 'message.delta', {
          'messageId': 'assistant',
          'delta': 'Keep this output',
        }),
      );
      await flushConversation();
      repository.failSnapshot = true;
      controller.refresh();
      await flushConversation();
      expect(controller.snapshot!.messages.single.text, 'Keep this output');
      repository.failSnapshot = false;
      await Future<void>.delayed(const Duration(milliseconds: 15));
      expect(controller.snapshot!.lastSeq, 2);
      expect(repository.cursors, [1]);
      repository.data = chatSnapshotJson(
        seq: 3,
        messages: [chatMessageJson(text: 'Authoritative', revision: 3)],
      );
      await Future<void>.delayed(const Duration(milliseconds: 45));
      expect(controller.snapshot!.messages.single.text, 'Authoritative');
      expect(repository.cursors.last, 3);
      expect(controller.loading, isFalse);
    },
  );

  test(
    'a newer refresh supersedes an older response within the same session',
    () async {
      controller.open(chatId);
      await flushConversation();
      final first = Completer<ConversationSnapshot>();
      repository.delayedSnapshot = first;
      controller.refresh();
      await flushConversation();
      final second = Completer<ConversationSnapshot>();
      repository.delayedSnapshot = second;
      controller.refresh();
      second.complete(
        ConversationSnapshot.fromJson(
          chatSnapshotJson(
            seq: 3,
            messages: [chatMessageJson(text: 'Newer', revision: 3)],
          ),
        ),
      );
      await flushConversation();
      first.complete(
        ConversationSnapshot.fromJson(
          chatSnapshotJson(
            seq: 2,
            messages: [chatMessageJson(text: 'Older', revision: 2)],
          ),
        ),
      );
      await flushConversation();
      expect(controller.snapshot!.lastSeq, 3);
      expect(controller.snapshot!.messages.single.text, 'Newer');
    },
  );

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
      repository.data = chatSnapshotJson(seq: 3, messages: [chatMessageJson()]);
      expect(await controller.stop(), isTrue);
      await flushConversation();
      expect(repository.stops, 1);
      expect(controller.snapshot, isNotNull);
      expect(controller.loading, isFalse);
      expect(controller.running, isFalse);
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
