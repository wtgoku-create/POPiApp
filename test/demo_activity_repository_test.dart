import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_controller.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Dio dio;
  late PreferencesStorage storage;
  late _ActivityApi api;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = PreferencesStorage(await SharedPreferences.getInstance());
    await DemoRepository.prepareHarnessStorage(storage);
    dio = Dio();
    api = _ActivityApi(dio);
  });

  tearDown(() => dio.close(force: true));

  test('activity JSON keeps only the public bounded progress contract', () {
    final activity = DemoActivity.fromJson({
      'kind': 'search',
      'status': 'running',
      'reasoning': 'private chain of thought',
      'toolInput': {'query': 'secret'},
      'steps': [
        for (var index = 0; index < 15; index++)
          {
            'id': 'step-$index',
            'kind': index == 0 ? 'search' : 'unexpected-provider-kind',
            'status': index == 0 ? 'running' : 'unexpected-status',
            'result': 'private result',
          },
      ],
    });

    expect(activity.kind, 'search');
    expect(activity.status, 'running');
    expect(activity.steps, hasLength(12));
    expect(activity.steps[1].kind, 'tool');
    expect(activity.steps[1].status, 'completed');
    expect(activity.toJson(), isNot(contains('reasoning')));
    expect(jsonEncode(activity.toJson()), isNot(contains('private')));
  });

  test('empty activity messages survive snapshot cache and refresh', () async {
    api.snapshots = [
      _snapshot(
        messages: [
          _message(
            activity: const DemoActivity(
              kind: 'search',
              status: 'running',
              steps: [
                DemoActivityStep(
                  id: 'search-1',
                  kind: 'search',
                  status: 'running',
                ),
              ],
            ),
          ),
        ],
        runState: 'running',
      ),
    ];
    final repository = DemoRepository.harness(storage, api)..restore();
    addTearDown(repository.dispose);

    await repository.refreshSessions();
    final controller = DemoChatController(repository, 's1');
    addTearDown(controller.dispose);
    await _settle();

    final message = repository.session('s1').messages.single;
    expect(message.text, isEmpty);
    expect(message.activity?.kind, 'search');
    expect(controller.chatController.messages, hasLength(1));

    final restored = DemoRepository.harness(storage, api)..restore();
    addTearDown(restored.dispose);
    expect(restored.session('s1').messages.single.activity?.kind, 'search');
  });

  test('initial cached messages notify after asynchronous chat sync', () async {
    api.snapshots = [
      _snapshot(messages: [_message(text: '缓存中的回复')]),
    ];
    final repository = DemoRepository.harness(storage, api)..restore();
    addTearDown(repository.dispose);
    await repository.refreshSessions();

    final controller = DemoChatController(repository, 's1');
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    await _settle();

    expect(controller.hasVisibleMessages, isTrue);
    expect(notifications, greaterThan(0));
  });

  test('same message id publishes updated real activity stages', () async {
    api.snapshots = [
      _snapshot(
        messages: [
          _message(
            activity: const DemoActivity(kind: 'thinking', status: 'running'),
          ),
        ],
        runState: 'running',
      ),
      _snapshot(
        messages: [
          _message(
            activity: const DemoActivity(kind: 'image', status: 'running'),
          ),
        ],
        runState: 'running',
        lastSeq: 2,
      ),
    ];
    final repository = DemoRepository.harness(storage, api)..restore();
    addTearDown(repository.dispose);
    await repository.refreshSessions();
    final controller = DemoChatController(repository, 's1');
    addTearDown(controller.dispose);
    await _settle();

    await repository.refreshSession('s1');
    await _settle();

    expect(controller.chatController.messages, hasLength(1));
    final demo = controller.chatController.messages.single.metadata?['demo'];
    expect(demo, isA<DemoMessage>());
    expect((demo as DemoMessage).activity?.kind, 'image');
  });

  test(
    'send exposes thinking before acceptance and accepts draft once',
    () async {
      api.snapshots = [
        _snapshot(),
        _snapshot(
          messages: [
            _userMessage('u1', '画一张海报'),
            _message(
              activity: const DemoActivity(kind: 'thinking', status: 'running'),
            ),
          ],
          runState: 'running',
          lastSeq: 2,
        ),
        _snapshot(
          messages: [
            _userMessage('u1', '画一张海报'),
            _message(
              text: '已经提交图片生成。',
              activity: const DemoActivity(kind: 'image', status: 'completed'),
            ),
          ],
          runState: 'completed',
          lastSeq: 3,
        ),
      ];
      api.sendGate = Completer<void>();
      final repository = DemoRepository.harness(
        storage,
        api,
        pollInterval: Duration.zero,
        maxPollAttempts: 2,
      )..restore();
      addTearDown(repository.dispose);
      await repository.refreshSessions();
      final controller = DemoChatController(repository, 's1');
      addTearDown(controller.dispose);
      await _settle();
      var accepted = 0;

      final sending = controller.send(
        '画一张海报',
        const [],
        lookupAppLocalizations(const Locale('zh')),
        onAccepted: () => accepted += 1,
      );
      await _settle();

      expect(controller.waitingForResponse, isTrue);
      expect(controller.hasVisibleMessages, isTrue);
      var demo = controller.chatController.messages.single.metadata?['demo'];
      expect((demo as DemoMessage).id, startsWith('local-activity:'));
      expect(demo.activity?.kind, 'thinking');
      expect(repository.session('s1').messages, isEmpty);
      expect(accepted, 0);

      api.sendGate!.complete();
      expect(await sending, isTrue);
      await _settle();

      expect(accepted, 1);
      expect(
        controller.chatController.messages.where(
          (message) => message.id.startsWith('local-activity:'),
        ),
        isEmpty,
      );
      demo = controller.chatController.messages.last.metadata?['demo'];
      expect((demo as DemoMessage).activity?.kind, 'image');
      expect(controller.waitingForResponse, isFalse);
    },
  );

  test(
    'unaccepted failure and stopped run clear provisional activity',
    () async {
      api.snapshots = [_snapshot()];
      api.sendError = StateError('offline');
      final repository = DemoRepository.harness(storage, api)..restore();
      addTearDown(repository.dispose);
      await repository.refreshSessions();
      final controller = DemoChatController(repository, 's1');
      addTearDown(controller.dispose);
      await _settle();
      var accepted = 0;

      await expectLater(
        controller.send(
          '保留草稿',
          const [],
          lookupAppLocalizations(const Locale('zh')),
          onAccepted: () => accepted += 1,
        ),
        throwsStateError,
      );
      await _settle();

      expect(accepted, 0);
      expect(controller.chatController.messages, isEmpty);
      expect(controller.waitingForResponse, isFalse);

      api.sendError = null;
      api.snapshots = [_snapshot(runState: 'stopped')];
      api.snapshotIndex = 0;
      expect(
        await controller.send(
          '停止',
          const [],
          lookupAppLocalizations(const Locale('zh')),
        ),
        isFalse,
      );
      await _settle();
      expect(controller.chatController.messages, isEmpty);
      expect(controller.waitingForResponse, isFalse);
    },
  );

  test(
    'pending media job keeps a completed reply visibly generating',
    () async {
      final message = DemoMessage(
        id: 'a1',
        text: '图片任务已提交。',
        runId: 'run-1',
        memberId: 'designer',
        activity: DemoActivity(
          kind: 'reply',
          status: 'completed',
          steps: [
            for (var index = 0; index < 12; index++)
              DemoActivityStep(
                id: 'step-$index',
                kind: 'model',
                status: 'completed',
              ),
          ],
        ),
      );
      final session = DemoSession(
        id: 'media-session',
        title: 'Media',
        kind: DemoSessionKind.conversation,
        members: const ['popi'],
        roles: const [],
        messages: [message],
        mediaJobs: const [
          DemoMediaJob(
            jobId: 'job-1',
            state: 'processing',
            operation: 'image',
            model: 'image-model',
            runId: 'run-1',
            memberId: 'designer',
          ),
          DemoMediaJob(
            jobId: 'other-member-job',
            state: 'processing',
            operation: 'video',
            model: 'video-model',
            runId: 'run-1',
            memberId: 'writer',
          ),
        ],
      );
      await storage.setString(
        DemoRepository.storageKey,
        jsonEncode({
          'sessions': [session.toJson()],
          'assets': <Object?>[],
        }),
      );
      final repository = DemoRepository(storage)..restore();
      addTearDown(repository.dispose);
      final controller = DemoChatController(repository, session.id);
      addTearDown(controller.dispose);

      final effective = controller.activityFor(message)!;
      expect(effective.kind, 'image');
      expect(effective.status, 'running');
      expect(effective.steps, hasLength(12));
      expect(effective.steps.last.id, 'media-job:job-1');
      expect(effective.steps.last.status, 'running');
      expect(
        effective.steps.map((step) => step.id),
        isNot(contains('media-job:other-member-job')),
      );

      const stillRunning = DemoMessage(
        id: 'a2',
        text: '',
        runId: 'run-1',
        memberId: 'designer',
        activity: DemoActivity(kind: 'model', status: 'running'),
      );
      expect(controller.activityFor(stillRunning), same(stillRunning.activity));

      const stopped = DemoMessage(
        id: 'a3',
        text: '',
        runId: 'run-1',
        memberId: 'designer',
        activity: DemoActivity(kind: 'image', status: 'stopped'),
      );
      expect(controller.activityFor(stopped), same(stopped.activity));

      await repository.updateSession(
        session.id,
        (current) => current.copyWith(
          mediaJobs: const [
            DemoMediaJob(
              jobId: 'job-1',
              state: 'completed',
              operation: 'image',
              model: 'image-model',
              runId: 'run-1',
              memberId: 'designer',
              ingestionState: 'failed',
            ),
          ],
        ),
      );
      expect(controller.activityFor(stillRunning), same(stillRunning.activity));
      expect(controller.activityFor(message)?.status, 'failed');
      expect(controller.activityFor(message)?.steps.last.status, 'failed');
    },
  );

  test('pending TTS and music jobs use the audio activity artwork', () async {
    const message = DemoMessage(
      id: 'audio-reply',
      text: '音频任务已提交。',
      runId: 'audio-run',
      memberId: 'sound',
      activity: DemoActivity(kind: 'reply', status: 'completed'),
    );
    for (final operation in const ['tts', 'music', 'speech']) {
      final session = DemoSession(
        id: 'audio-$operation',
        title: 'Audio',
        kind: DemoSessionKind.conversation,
        members: const ['sound'],
        roles: const [],
        messages: const [message],
        mediaJobs: [
          DemoMediaJob(
            jobId: '$operation-job',
            state: 'processing',
            operation: operation,
            model: 'audio-model',
            runId: 'audio-run',
            memberId: 'sound',
          ),
        ],
      );
      await storage.setString(
        DemoRepository.storageKey,
        jsonEncode({
          'sessions': [session.toJson()],
          'assets': <Object?>[],
        }),
      );
      final repository = DemoRepository(storage)..restore();
      final controller = DemoChatController(repository, session.id);

      final effective = controller.activityFor(message)!;
      expect(effective.kind, 'audio', reason: operation);
      expect(effective.status, 'running', reason: operation);
      expect(effective.steps.single.kind, 'audio', reason: operation);

      controller.dispose();
      repository.dispose();
    }
  });

  test(
    'only the latest non-question activity receives pending media',
    () async {
      const preamble = DemoMessage(
        id: 'preamble',
        text: '我先确认你的选择。',
        runId: 'question-run',
        memberId: 'popi',
        activity: DemoActivity(kind: 'thinking', status: 'completed'),
      );
      const answeredQuestion = DemoMessage(
        id: 'question-card',
        text: '',
        runId: 'question-run',
        memberId: 'popi',
        question: DemoQuestion(
          id: 'question-1',
          revision: 2,
          status: 'submitted',
          questions: [
            DemoQuestionField(
              id: 'decision',
              question: '继续生成吗？',
              options: [DemoQuestionOption(label: '继续')],
            ),
          ],
          answers: [
            DemoQuestionAnswer(id: 'decision', selected: ['继续']),
          ],
        ),
        activity: DemoActivity(kind: 'tool', status: 'completed'),
      );
      const latestReply = DemoMessage(
        id: 'latest-reply',
        text: '图片任务已提交。',
        runId: 'question-run',
        memberId: 'popi',
        activity: DemoActivity(kind: 'reply', status: 'completed'),
      );
      const delivery = DemoMessage(
        id: 'delivery',
        text: '任务会在完成后自动交付。',
        runId: 'question-run',
        memberId: 'popi',
      );
      const session = DemoSession(
        id: 'question-media',
        title: 'Question',
        kind: DemoSessionKind.conversation,
        members: ['popi'],
        roles: [],
        messages: [preamble, answeredQuestion, latestReply, delivery],
        mediaJobs: [
          DemoMediaJob(
            jobId: 'image-job',
            state: 'processing',
            operation: 'image',
            model: 'image-model',
            runId: 'question-run',
            memberId: 'popi',
          ),
        ],
      );
      await storage.setString(
        DemoRepository.storageKey,
        jsonEncode({
          'sessions': [session.toJson()],
          'assets': <Object?>[],
        }),
      );
      final repository = DemoRepository(storage)..restore();
      addTearDown(repository.dispose);
      final controller = DemoChatController(repository, session.id);
      addTearDown(controller.dispose);

      expect(controller.activityFor(preamble), same(preamble.activity));
      expect(
        controller.activityFor(answeredQuestion),
        same(answeredQuestion.activity),
      );
      final effectiveReply = controller.activityFor(latestReply)!;
      expect(effectiveReply.kind, 'image');
      expect(effectiveReply.status, 'running');
      expect(controller.activityFor(delivery), isNull);
    },
  );
}

Future<void> _settle() async {
  for (var index = 0; index < 5; index++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _ActivityApi extends NetworkAgentApi {
  _ActivityApi(super.dio);

  List<Map<String, dynamic>> snapshots = [];
  int snapshotIndex = 0;
  Completer<void>? sendGate;
  Object? sendError;

  @override
  Future<Map<String, dynamic>> sessionsPage({
    int page = 1,
    int pageSize = 20,
    bool archived = false,
    String? accountId,
    CancelToken? cancelToken,
  }) async => {
    'list': [_sessionRecord()],
    'pageInfo': {'pageCount': 1},
  };

  @override
  Future<Map<String, dynamic>> sessionSnapshot(
    String id, {
    CancelToken? cancelToken,
  }) async {
    final index = snapshotIndex < snapshots.length
        ? snapshotIndex++
        : snapshots.length - 1;
    return snapshots[index];
  }

  @override
  Future<Map<String, dynamic>> sendSessionMessage(
    String id, {
    required String clientRequestId,
    required String text,
    String? taskId,
    List<String>? mediaIds,
    List<String>? contextRoleIds,
    CancelToken? cancelToken,
  }) async {
    if (sendGate case final gate?) await gate.future;
    if (sendError case final error?) throw error;
    return {'runId': 'run-1', 'state': 'queued'};
  }

  @override
  Future<Map<String, dynamic>> assets({
    String? sessionId,
    CancelToken? cancelToken,
  }) async => {'list': <Object?>[]};
}

Map<String, dynamic> _snapshot({
  List<Map<String, Object?>> messages = const [],
  String? runState,
  int? lastSeq,
}) => {
  'session': _sessionRecord(),
  'lastSeq': lastSeq ?? messages.length,
  'messages': messages,
  'mediaJobs': <Object?>[],
  'assets': <Object?>[],
  'runs': runState == null
      ? <Object?>[]
      : [
          {'id': 'run-1', 'state': runState},
        ],
};

Map<String, Object?> _message({String text = '', DemoActivity? activity}) => {
  'id': 'a1',
  'role': 'assistant',
  'text': text,
  'status': activity?.status ?? 'completed',
  'memberId': 'popi',
  'runId': 'run-1',
  if (activity != null) 'activity': activity.toJson(),
};

Map<String, Object?> _userMessage(String id, String text) => {
  'id': id,
  'role': 'user',
  'text': text,
  'status': 'completed',
};

Map<String, dynamic> _sessionRecord() => {
  'id': 's1',
  'title': 'Activity',
  'kind': 'conversation',
  'revision': 1,
  'configRevision': 1,
  'configurationStatus': 'configured',
  'configuration': {
    'members': ['popi'],
    'roles': <String>[],
    'capabilities': DemoSession.defaultCapabilities,
    'memberCapabilities': {'popi': DemoSession.defaultCapabilities},
    'memberNames': <String, String>{'popi': 'Activity'},
    'memberInstructions': <String, String>{},
    'memberAvatars': <String, String>{},
    'memberColors': <String, int>{},
    'workMode': 'onDemand',
    'activeMemberId': 'popi',
    'direction': '',
    'positioning': '',
    'roleProfiles': <String, Object?>{},
  },
};
