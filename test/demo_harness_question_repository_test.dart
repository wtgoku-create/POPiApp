import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Dio dio;
  late _QuestionApi api;
  late PreferencesStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = PreferencesStorage(await SharedPreferences.getInstance());
    await DemoRepository.prepareHarnessStorage(storage);
    dio = Dio();
    api = _QuestionApi(dio);
  });

  tearDown(() => dio.close(force: true));

  test(
    'pending DSH question preserves fields, member binding, and cache',
    () async {
      final repository = DemoRepository.harness(storage, api)..restore();
      addTearDown(repository.dispose);

      await repository.refreshSessions();

      final message = repository.session('s1').messages.single;
      expect(message.text, isEmpty);
      expect(message.memberId, 'director');
      expect(message.runId, 'run-1');
      expect(message.configRevision, 7);
      expect(message.question?.status, 'pending');
      expect(message.question?.questions.single.question, '进入声音制作吗？');
      expect(
        message.question?.questions.single.options.first.description,
        '继续',
      );

      final restored = DemoRepository.harness(storage, api)..restore();
      addTearDown(restored.dispose);
      expect(
        restored.session('s1').messages.single.question?.status,
        'pending',
      );
      expect(
        restored
            .session('s1')
            .messages
            .single
            .question
            ?.questions
            .single
            .options
            .last
            .label,
        '先调整',
      );
    },
  );

  test('answer refreshes the card and observes the continued run', () async {
    api.completeAfterAnsweredSnapshots = 2;
    final repository = DemoRepository.harness(
      storage,
      api,
      pollInterval: Duration.zero,
      questionPollInterval: Duration.zero,
      maxPollAttempts: 2,
    )..restore();
    addTearDown(repository.dispose);
    await repository.refreshSessions();
    final controller = DemoChatController(repository, 's1');
    addTearDown(controller.dispose);
    final question = repository.session('s1').messages.single.question!;

    expect(
      await controller.respondQuestion(question, 'submit', {'decision': '继续'}),
      isTrue,
    );
    await _waitUntil(() => api.runState == 'completed');

    final answered = repository.session('s1').messages.single.question!;
    expect(answered.status, 'answered');
    expect(answered.answer, {'decision': '继续'});
    expect(api.answers.single, {'decision': '继续'});
    expect(api.requestIds.single, isNotEmpty);
    expect(repository.isSessionRunning('s1'), isFalse);
  });

  test(
    'duplicate taps join one request and failed retries keep one key',
    () async {
      api.completeAfterAnsweredSnapshots = 2;
      final repository = DemoRepository.harness(
        storage,
        api,
        questionPollInterval: Duration.zero,
      )..restore();
      addTearDown(repository.dispose);
      await repository.refreshSessions();
      final controller = DemoChatController(repository, 's1');
      addTearDown(controller.dispose);
      var question = repository.session('s1').messages.single.question!;

      api.respondGate = Completer<void>();
      final first = controller.respondQuestion(question, 'submit', {
        'decision': '继续',
      });
      expect(
        await controller.respondQuestion(question, 'submit', {
          'decision': '继续',
        }),
        isFalse,
      );
      expect(api.respondCalls, 1);
      api.respondGate!.complete();
      expect(await first, isTrue);
      await _waitUntil(() => api.runState == 'completed');
      await _waitUntil(
        () =>
            !repository.isSessionRunning('s1') &&
            !repository.isSessionLoading('s1'),
      );

      api.resetPending();
      await repository.refreshSession('s1');
      question = repository.session('s1').messages.single.question!;
      api.failNextResponse = true;
      await expectLater(
        controller.respondQuestion(question, 'submit', {'decision': '先调整'}),
        throwsA(isA<DioException>()),
      );
      expect(
        repository.session('s1').messages.single.question?.status,
        'pending',
      );
      expect(controller.questionBusy('question-1'), isFalse);

      expect(
        await controller.respondQuestion(question, 'submit', {
          'decision': '先调整',
        }),
        isTrue,
      );
      expect(api.requestIds[1], api.requestIds[2]);
    },
  );

  test('two controllers reject different concurrent answers', () async {
    api.completeAfterAnsweredSnapshots = 2;
    final repository = DemoRepository.harness(
      storage,
      api,
      questionPollInterval: Duration.zero,
    )..restore();
    addTearDown(repository.dispose);
    await repository.refreshSessions();
    final firstController = DemoChatController(repository, 's1');
    final secondController = DemoChatController(repository, 's1');
    addTearDown(firstController.dispose);
    addTearDown(secondController.dispose);
    final question = repository.session('s1').messages.single.question!;
    api.respondGate = Completer<void>();

    final first = firstController.respondQuestion(question, 'submit', {
      'decision': '继续',
    });
    await expectLater(
      secondController.respondQuestion(question, 'submit', {'decision': '先调整'}),
      throwsA(isA<StateError>()),
    );
    expect(api.respondCalls, 1);
    expect(api.answers, [
      {'decision': '继续'},
    ]);

    api.respondGate!.complete();
    expect(await first, isTrue);
  });

  test('waiting questions do not time out and stop closes the card', () async {
    final repository = DemoRepository.harness(
      storage,
      api,
      pollInterval: Duration.zero,
      questionPollInterval: const Duration(milliseconds: 1),
      maxPollAttempts: 0,
    )..restore();
    addTearDown(repository.dispose);
    await repository.refreshSessions();
    final controller = DemoChatController(repository, 's1');
    addTearDown(controller.dispose);

    final observing = repository.resumeHarnessSession('s1');
    await _waitUntil(() => controller.running);
    await controller.stop();
    await observing;

    expect(api.stopCalls, 1);
    expect(repository.isSessionRunning('s1'), isFalse);
    expect(
      repository.session('s1').messages.single.question?.status,
      'cancelled',
    );
  });

  test(
    'waiting poll discovers an answer submitted by another client',
    () async {
      final repository = DemoRepository.harness(
        storage,
        api,
        questionPollInterval: const Duration(milliseconds: 1),
        maxPollAttempts: 0,
      )..restore();
      addTearDown(repository.dispose);
      await repository.refreshSessions();

      final observing = repository.resumeHarnessSession('s1');
      await _waitUntil(() => repository.isSessionRunning('s1'));
      api.questionAnswers = const [
        {
          'id': 'decision',
          'selected': ['继续'],
        },
      ];
      api.questionStatus = 'answered';
      api.runState = 'completed';
      await observing;

      expect(repository.session('s1').messages.single.question?.answer, {
        'decision': '继续',
      });
      expect(repository.isSessionRunning('s1'), isFalse);
    },
  );

  test(
    'accepted send returns at a question while observation continues',
    () async {
      final repository = DemoRepository.harness(
        storage,
        api,
        questionPollInterval: const Duration(milliseconds: 1),
        maxPollAttempts: 0,
      )..restore();
      addTearDown(repository.dispose);
      await repository.refreshSessions();
      var accepted = false;

      await repository
          .sendHarnessMessage(
            's1',
            clientRequestId: 'send-1',
            text: '继续制作',
            onAccepted: () => accepted = true,
          )
          .timeout(const Duration(seconds: 1));

      expect(accepted, isTrue);
      expect(repository.isSessionRunning('s1'), isTrue);
      await repository.stopHarnessSession('s1');
      await _waitUntil(() => !repository.isSessionRunning('s1'));
    },
  );

  test('question transport includes the idempotency key', () async {
    final transport = Dio();
    addTearDown(() => transport.close(force: true));
    transport.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(
            options.path,
            '/api_agent/v2/sessions/s1/questions/question-1/respond',
          );
          expect(options.method, 'POST');
          expect(options.data, {
            'clientRequestId': 'request-1',
            'revision': 3,
            'action': 'submit',
            'answer': {'decision': '继续'},
          });
          handler.resolve(
            Response(requestOptions: options, data: <String, dynamic>{}),
          );
        },
      ),
    );

    await NetworkAgentApi(transport).respondQuestion(
      's1',
      'question-1',
      clientRequestId: 'request-1',
      revision: 3,
      action: 'submit',
      answer: {'decision': '继续'},
    );
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue);
}

class _QuestionApi extends NetworkAgentApi {
  _QuestionApi(super.dio);

  String questionStatus = 'pending';
  String runState = 'waiting_user';
  List<Map<String, Object?>> questionAnswers = const [];
  int respondCalls = 0;
  int stopCalls = 0;
  int answeredSnapshots = 0;
  int? completeAfterAnsweredSnapshots;
  bool failNextResponse = false;
  Completer<void>? respondGate;
  final List<String> requestIds = [];
  final List<Map<String, Object?>> answers = [];

  void resetPending() {
    questionStatus = 'pending';
    runState = 'waiting_user';
    questionAnswers = const [];
    answeredSnapshots = 0;
    respondGate = null;
  }

  @override
  Future<Map<String, dynamic>> assets({
    String? sessionId,
    CancelToken? cancelToken,
  }) async => {'list': <Object?>[]};

  @override
  Future<Map<String, dynamic>> sessionsPage({
    int page = 1,
    int pageSize = 20,
    bool archived = false,
    String? accountId,
    CancelToken? cancelToken,
  }) async => {
    'list': [_record()],
    'pageInfo': {'page': 1, 'pageSize': pageSize, 'pageCount': 1, 'total': 1},
  };

  @override
  Future<Map<String, dynamic>> sessionSnapshot(
    String id, {
    CancelToken? cancelToken,
  }) async {
    if (questionStatus == 'answered') {
      answeredSnapshots += 1;
      if (completeAfterAnsweredSnapshots != null &&
          answeredSnapshots >= completeAfterAnsweredSnapshots!) {
        runState = 'completed';
      }
    }
    return {
      'session': _record(),
      'lastSeq': 1,
      'messages': [_message()],
      'runs': [
        {'id': 'run-1', 'state': runState},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> respondQuestion(
    String sessionId,
    String questionId, {
    String? clientRequestId,
    required int revision,
    required String action,
    Map<String, Object?>? answer,
    CancelToken? cancelToken,
  }) async {
    respondCalls += 1;
    requestIds.add(clientRequestId ?? '');
    answers.add(Map<String, Object?>.from(answer ?? const {}));
    await respondGate?.future;
    if (failNextResponse) {
      failNextResponse = false;
      throw DioException(
        requestOptions: RequestOptions(path: '/respond'),
        type: DioExceptionType.connectionError,
      );
    }
    final value = answer?['decision']?.toString() ?? '';
    questionAnswers = [
      {
        'id': 'decision',
        'selected': value == '继续' || value == '先调整' ? [value] : <String>[],
        if (value != '继续' && value != '先调整') 'custom': value,
      },
    ];
    questionStatus = action == 'cancel' ? 'cancelled' : 'answered';
    runState = action == 'cancel' ? 'stopped' : 'running';
    return {'status': questionStatus, 'runId': 'run-1'};
  }

  @override
  Future<Map<String, dynamic>> sendSessionMessage(
    String id, {
    required String clientRequestId,
    required String text,
    String? taskId,
    List<String>? mediaIds,
    List<String>? contextRoleIds,
    Map<String, Object?>? skillInvocation,
    CancelToken? cancelToken,
  }) async => {
    'sessionId': id,
    'runId': 'run-1',
    'messageId': 'user-1',
    'state': 'queued',
  };

  @override
  Future<Map<String, dynamic>> stopSession(
    String id, {
    required String clientRequestId,
    CancelToken? cancelToken,
  }) async {
    stopCalls += 1;
    questionStatus = 'cancelled';
    runState = 'stopped';
    return {'sessionId': id, 'runId': 'run-1', 'state': 'stopping'};
  }

  Map<String, Object?> _message() => {
    'id': 'message-1',
    'role': 'assistant',
    'text': '',
    'status': questionStatus == 'pending' ? 'pending' : 'completed',
    'memberId': 'director',
    'memberName': '动效导演',
    'runId': 'run-1',
    'configRevision': 7,
    'question': {
      'id': 'question-1',
      'revision': 3,
      'status': questionStatus,
      'title': '《留个位置》可以进入声音和成片制作了吗？',
      'questions': [
        {
          'id': 'decision',
          'question': '进入声音制作吗？',
          'header': '下一步',
          'options': [
            {'label': '继续', 'description': '继续'},
            {'label': '先调整', 'description': '继续打磨'},
          ],
          'multiSelect': false,
        },
      ],
      if (questionAnswers.isNotEmpty) 'answers': questionAnswers,
    },
  };
}

Map<String, Object?> _record() => {
  'id': 's1',
  'title': 'Session',
  'kind': 'conversation',
  'revision': 1,
  'createdAt': '2026-10-24T00:00:00.000Z',
  'updatedAt': '2026-10-24T00:00:00.000Z',
  'archived': false,
  'bindingStatus': 'ready',
  'configurationStatus': 'configured',
  'configRevision': 1,
  'configuration': {
    'members': ['director'],
    'roles': <String>[],
    'capabilities': ['audio', 'video'],
    'memberCapabilities': {
      'director': ['audio', 'video'],
    },
    'memberNames': {'director': '动效导演'},
    'memberInstructions': <String, String>{},
    'memberAvatars': <String, String>{},
    'memberColors': <String, int>{},
    'workMode': 'onDemand',
    'activeMemberId': 'director',
    'direction': '',
    'positioning': '',
    'roleProfiles': <String, Object?>{},
  },
};
