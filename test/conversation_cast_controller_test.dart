import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/session/presentation/conversation_controller.dart';

import 'conversation_controller_test.dart'
    show StreamingSessionRepository, flushConversation;
import 'conversation_events_test.dart' show chatId;

class _CastRepository extends StreamingSessionRepository {
  int casts = 0;
  CancelToken? castToken;
  final completion = Completer<void>();

  _CastRepository() {
    data['session'] = {...data['session'] as Map, 'bindingStatus': 'ready'};
  }

  @override
  Future<void> updateCast(
    String userId,
    String id,
    List<String> roleIds, {
    CancelToken? cancelToken,
  }) {
    casts++;
    castToken = cancelToken;
    return completion.future;
  }
}

void main() {
  late _CastRepository repository;
  late ConversationController controller;
  setUp(() {
    repository = _CastRepository();
    controller = ConversationController(repository, 'user');
  });
  tearDown(() async {
    controller.dispose();
    await repository.close();
    await flushConversation();
  });

  test(
    'cast edit requires a connected ready idle session and prevents duplicate submits',
    () async {
      expect(await controller.updateCast([]), isFalse);
      controller.open(chatId);
      expect(await controller.updateCast([]), isFalse);
      await flushConversation();
      for (final session in [
        {'bindingStatus': 'pending'},
        {'archived': true},
      ]) {
        controller.snapshot = ConversationSnapshot.fromJson({
          ...repository.data,
          'session': {...repository.data['session'] as Map, ...session},
        });
        expect(await controller.updateCast([]), isFalse);
      }
      controller.snapshot = ConversationSnapshot.fromJson(repository.data);
      controller.connection = ConversationConnection.reconnecting;
      expect(await controller.updateCast([]), isFalse);
      controller.connection = ConversationConnection.connected;
      final action = controller.updateCast(['1']);
      expect(controller.pending, isTrue);
      expect(await controller.updateCast(['2']), isFalse);
      expect(repository.casts, 1);
      repository.completion.complete();
      expect(await action, isTrue);
      await flushConversation();
      expect(repository.snapshots, 2);
      expect(controller.pending, isFalse);
      expect(await controller.send('hello', [], 'New', 'Media'), isTrue);
      expect(controller.running, isTrue);
      expect(await controller.updateCast([]), isFalse);
      expect(repository.casts, 1);
    },
  );

  test(
    'switching session cancels cast command and ignores its late failure',
    () async {
      controller.dispose();
      final errors = <Object>[];
      controller = ConversationController(
        repository,
        'user',
        onError: errors.add,
      );
      controller.open(chatId);
      await flushConversation();
      final action = controller.updateCast(['1']);
      controller.open('another-session');
      await flushConversation();
      expect(repository.castToken!.isCancelled, isTrue);
      final snapshots = repository.snapshots;
      repository.completion.completeError(StateError('late failure'));
      expect(await action, isFalse);
      expect(errors, isEmpty);
      expect(controller.sessionId, 'another-session');
      expect(repository.snapshots, snapshots);
      expect(controller.pending, isFalse);
    },
  );
}
