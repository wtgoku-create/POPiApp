import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_controller.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_page.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_timeline.dart'
    show MarkdownMessage;
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

void main() {
  late Dio dio;
  late _HarnessApi api;
  late PreferencesStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = PreferencesStorage(await SharedPreferences.getInstance());
    await DemoRepository.prepareHarnessStorage(storage);
    dio = Dio();
    api = _HarnessApi(dio);
  });

  tearDown(() => dio.close(force: true));

  test(
    'backs up offline demo once and initializes an empty Harness store',
    () async {
      SharedPreferences.setMockInitialValues({
        DemoRepository.storageKey: '{"offline":"snapshot"}',
      });
      final preferences = await SharedPreferences.getInstance();
      final firstStorage = PreferencesStorage(preferences);

      await DemoRepository.prepareHarnessStorage(firstStorage);
      expect(
        firstStorage.getString(DemoRepository.backupStorageKey),
        '{"offline":"snapshot"}',
      );
      expect(
        firstStorage.getString(DemoRepository.harnessStorageKey),
        '{"sessions":[],"assets":[]}',
      );

      await firstStorage.setString(DemoRepository.storageKey, 'new offline');
      await DemoRepository.prepareHarnessStorage(firstStorage);
      expect(
        firstStorage.getString(DemoRepository.backupStorageKey),
        '{"offline":"snapshot"}',
      );
    },
  );

  test('empty state and refresh restore real server history', () async {
    api.records = [_record('s1', title: 'DeepSeek session')];
    api.snapshots['s1'] = [
      _snapshot(
        's1',
        title: 'DeepSeek session',
        messages: [
          _message('u1', 'user', 'Hello'),
          _message('a1', 'assistant', 'Hi from DeepSeek'),
        ],
      ),
    ];
    final repository = DemoRepository.harness(storage, api)..restore();
    addTearDown(repository.dispose);
    expect(repository.sessions, isEmpty);
    expect(repository.assets, isEmpty);

    await repository.refreshSessions();
    expect(repository.sessions.single.title, 'DeepSeek session');
    expect(repository.sessions.single.messages.map((message) => message.text), [
      'Hello',
      'Hi from DeepSeek',
    ]);
    expect(repository.sessions.single.updatedAt, DateTime.utc(2026, 10, 23));
    expect(
      repository.sessions.single.messages.last.createdAt,
      DateTime.utc(2026, 10, 23),
    );

    final restored = DemoRepository.harness(storage, api)..restore();
    addTearDown(restored.dispose);
    expect(restored.sessions.single.messages, hasLength(2));
    expect(restored.sessions.single.updatedAt, DateTime.utc(2026, 10, 23));
    expect(
      restored.sessions.single.messages.last.createdAt,
      DateTime.utc(2026, 10, 23),
    );
  });

  test(
    'invalid or omitted server timestamps retain cached valid values',
    () async {
      api.records = [_record('s1')];
      api.snapshots['s1'] = [
        _snapshot('s1', messages: [_message('a1', 'assistant', 'First')]),
        _snapshot(
          's1',
          sessionRecord: _record('s1', includeTimestamps: false),
          messages: [
            _message('a1', 'assistant', 'Updated', createdAt: 'not-a-date'),
          ],
        ),
      ];
      final repository = DemoRepository.harness(storage, api)..restore();
      addTearDown(repository.dispose);

      await repository.refreshSessions();
      final original = repository.session('s1');
      api.records = [_record('s1', includeTimestamps: false)];
      await repository.refreshSessions();

      final refreshed = repository.session('s1');
      expect(refreshed.updatedAt, original.updatedAt);
      expect(refreshed.messages.single.text, 'Updated');
      expect(
        refreshed.messages.single.createdAt,
        original.messages.single.createdAt,
      );
    },
  );

  test('server timestamp offsets map to UTC instants', () async {
    final record = _record('s1', updatedAt: '2026-10-25T11:10:00+08:00');
    api.records = [record];
    api.snapshots['s1'] = [
      _snapshot(
        's1',
        sessionRecord: record,
        messages: [
          _message(
            'a1',
            'assistant',
            'Ready',
            createdAt: '2026-10-25T10:48:00+08:00',
          ),
        ],
      ),
    ];
    final repository = DemoRepository.harness(storage, api)..restore();
    addTearDown(repository.dispose);

    await repository.refreshSessions();

    expect(
      repository.session('s1').updatedAt,
      DateTime.utc(2026, 10, 25, 3, 10),
    );
    expect(
      repository.session('s1').messages.single.createdAt,
      DateTime.utc(2026, 10, 25, 2, 48),
    );
  });

  test('server snapshots preserve assistant member identity', () async {
    api.records = [_record('s1')];
    api.snapshots['s1'] = [
      _snapshot(
        's1',
        messages: [
          _message(
            'a1',
            'assistant',
            '我来补充镜头节奏。',
            memberId: 'director',
            memberName: '镜头导演',
            runId: 'run-group-1',
            configRevision: 7,
          ),
        ],
      ),
    ];
    final repository = DemoRepository.harness(storage, api)..restore();
    addTearDown(repository.dispose);

    await repository.refreshSessions();

    final message = repository.session('s1').messages.single;
    expect(message.memberId, 'director');
    expect(message.memberName, '镜头导演');
    expect(message.runId, 'run-group-1');
    expect(message.configRevision, 7);
  });

  test('create, rename and delete use server identities and archive', () async {
    final repository = DemoRepository.harness(storage, api)..restore();
    addTearDown(repository.dispose);

    final id = await repository.createSession(
      'New workflow',
      DemoSessionKind.workflow,
    );
    expect(id, 'server-created');
    expect(repository.session(id).kind, DemoSessionKind.workflow);
    expect(api.createdKinds, ['workflow']);

    await repository.updateSession(
      id,
      (session) => session.copyWith(title: 'Renamed'),
    );
    expect(api.renamedTitles, ['Renamed']);
    expect(repository.session(id).title, 'Renamed');
    expect(repository.session(id).memberNames['popi'], 'Renamed');
    expect(api.updatedConfigurations.last['memberNames'], {'popi': 'Renamed'});

    await repository.deleteSession(id);
    expect(api.archivedIds, [id]);
    expect(repository.sessions, isEmpty);
  });

  test(
    'single assistant member rename also updates its conversation title',
    () async {
      api.records = [
        _record(
          's1',
          title: '旧名字',
          configuration: {
            ..._configuration(),
            'memberNames': <String, String>{'popi': '旧名字'},
          },
        ),
      ];
      api.snapshots['s1'] = [
        _snapshot(
          's1',
          title: '旧名字',
          sessionRecord: _record(
            's1',
            title: '旧名字',
            configuration: {
              ..._configuration(),
              'memberNames': <String, String>{'popi': '旧名字'},
            },
          ),
        ),
      ];
      final repository = DemoRepository.harness(storage, api)..restore();
      addTearDown(repository.dispose);
      await repository.refreshSessions();

      await repository.updateSession(
        's1',
        (session) => session.copyWith(
          memberNames: {...session.memberNames, 'popi': '哈哈'},
        ),
      );

      expect(repository.session('s1').title, '哈哈');
      expect(repository.session('s1').memberNames['popi'], '哈哈');
      expect(api.renamedTitles.last, '哈哈');
      expect(api.updatedConfigurations.last['memberNames'], {'popi': '哈哈'});
    },
  );

  test(
    'legacy sole title is persisted before the next accepted message',
    () async {
      final wattConfiguration = {
        ..._configuration(),
        'memberNames': <String, String>{},
      };
      final namedConfiguration = {
        ..._configuration(),
        'memberNames': <String, String>{'popi': 'Watt'},
      };
      api.records = [
        _record('s1', title: 'Watt', configuration: wattConfiguration),
      ];
      api.snapshots['s1'] = [
        _snapshot(
          's1',
          title: 'Watt',
          sessionRecord: _record(
            's1',
            title: 'Watt',
            configuration: wattConfiguration,
          ),
        ),
        _snapshot(
          's1',
          title: 'Watt',
          sessionRecord: _record(
            's1',
            title: 'Watt',
            configuration: namedConfiguration,
          ),
          messages: [_message('u1', 'user', 'Hello')],
          runState: 'completed',
        ),
      ];
      final repository = DemoRepository.harness(
        storage,
        api,
        pollInterval: Duration.zero,
        maxPollAttempts: 1,
      )..restore();
      addTearDown(repository.dispose);
      await repository.refreshSessions();

      await repository.sendHarnessMessage(
        's1',
        clientRequestId: 'send-watt',
        text: 'Hello',
      );

      expect(api.updatedConfigurations, hasLength(1));
      expect(api.updatedConfigurations.single['memberNames'], {'popi': 'Watt'});
      expect(api.sendRequestIds, ['send-watt']);
      expect(repository.session('s1').memberNames['popi'], 'Watt');
    },
  );

  test('invalid role context cannot persist a legacy alias', () async {
    final configuration = {
      ..._configuration(),
      'memberNames': <String, String>{},
    };
    api.records = [_record('s1', title: 'Watt', configuration: configuration)];
    api.snapshots['s1'] = [
      _snapshot(
        's1',
        title: 'Watt',
        sessionRecord: _record(
          's1',
          title: 'Watt',
          configuration: configuration,
        ),
      ),
    ];
    final repository = DemoRepository.harness(storage, api)..restore();
    addTearDown(repository.dispose);
    await repository.refreshSessions();

    await expectLater(
      repository.sendHarnessMessage(
        's1',
        clientRequestId: 'invalid-context',
        text: 'Hello',
        contextRoleIds: const ['not-selected'],
      ),
      throwsArgumentError,
    );

    expect(api.updatedConfigurations, isEmpty);
    expect(api.sendRequestIds, isEmpty);
    expect(repository.session('s1').memberNames, isEmpty);
  });

  test('group title and member names remain independent', () async {
    final group = {
      ..._configuration(),
      'members': <String>['writer', 'designer'],
      'memberNames': <String, String>{'writer': '编剧', 'designer': '设计师'},
      'activeMemberId': 'writer',
    };
    api.records = [_record('s1', title: '创作组', configuration: group)];
    api.snapshots['s1'] = [
      _snapshot(
        's1',
        title: '创作组',
        sessionRecord: _record('s1', title: '创作组', configuration: group),
      ),
    ];
    final repository = DemoRepository.harness(storage, api)..restore();
    addTearDown(repository.dispose);
    await repository.refreshSessions();

    await repository.updateSession(
      's1',
      (session) => session.copyWith(title: '新群名'),
    );

    expect(repository.session('s1').title, '新群名');
    expect(repository.session('s1').memberNames, {
      'writer': '编剧',
      'designer': '设计师',
    });
  });

  test(
    'unknown send outcome retries one request ID without duplicates',
    () async {
      api.records = [_record('s1')];
      api.snapshots['s1'] = [
        _snapshot('s1'),
        _snapshot(
          's1',
          messages: [_message('u1', 'user', 'Hello')],
          runState: 'running',
        ),
        _snapshot(
          's1',
          messages: [
            _message('u1', 'user', 'Hello'),
            _message('a1', 'assistant', 'Real answer'),
          ],
          runState: 'completed',
        ),
      ];
      api.failFirstSend = true;
      final repository = DemoRepository.harness(
        storage,
        api,
        pollInterval: Duration.zero,
        maxPollAttempts: 3,
      )..restore();
      addTearDown(repository.dispose);
      await repository.refreshSessions();
      final controller = DemoChatController(repository, 's1');
      addTearDown(controller.dispose);
      final localizations = lookupAppLocalizations(const Locale('zh'));

      await expectLater(
        controller.send('Hello', const [], localizations),
        throwsA(isA<DioException>()),
      );
      expect(repository.session('s1').messages, isEmpty);

      expect(await controller.send('Hello', const [], localizations), isTrue);
      expect(api.sendRequestIds, hasLength(2));
      expect(api.sendRequestIds.toSet(), hasLength(1));
      expect(repository.session('s1').messages.map((message) => message.id), [
        'u1',
        'a1',
      ]);
    },
  );

  test(
    'refresh resumes polling a server run after a browser restart',
    () async {
      api.records = [_record('s1')];
      api.snapshots['s1'] = [
        _snapshot('s1'),
        _snapshot(
          's1',
          messages: [_message('u1', 'user', 'Continue')],
          runState: 'running',
        ),
        _snapshot(
          's1',
          messages: [
            _message('u1', 'user', 'Continue'),
            _message('a1', 'assistant', 'Recovered answer'),
          ],
          runState: 'completed',
        ),
      ];
      final repository = DemoRepository.harness(
        storage,
        api,
        pollInterval: Duration.zero,
        maxPollAttempts: 3,
      )..restore();
      addTearDown(repository.dispose);
      await repository.refreshSessions();

      await repository.resumeHarnessSession('s1');
      expect(repository.session('s1').messages.last.text, 'Recovered answer');
    },
  );

  test('known failed run gives the next send a fresh request key', () async {
    api.records = [_record('s1')];
    api.snapshots['s1'] = [
      _snapshot('s1'),
      _snapshot('s1', runState: 'failed'),
      _snapshot(
        's1',
        messages: [_message('a1', 'assistant', 'Retry worked')],
        runState: 'completed',
      ),
    ];
    final repository = DemoRepository.harness(
      storage,
      api,
      pollInterval: Duration.zero,
      maxPollAttempts: 1,
    )..restore();
    addTearDown(repository.dispose);
    await repository.refreshSessions();
    final controller = DemoChatController(repository, 's1');
    addTearDown(controller.dispose);
    final localizations = lookupAppLocalizations(const Locale('zh'));

    await expectLater(
      controller.send('Retry me', const [], localizations),
      throwsA(isA<HarnessRunTerminalException>()),
    );
    expect(await controller.send('Retry me', const [], localizations), isTrue);
    expect(api.sendRequestIds, hasLength(2));
    expect(api.sendRequestIds.toSet(), hasLength(2));
  });

  test('accepted send switches from submitting to stoppable running', () async {
    api.records = [_record('s1')];
    api.snapshots['s1'] = [
      _snapshot('s1'),
      _snapshot('s1', runState: 'completed'),
    ];
    final repository = DemoRepository.harness(
      storage,
      api,
      pollInterval: Duration.zero,
      maxPollAttempts: 1,
    )..restore();
    addTearDown(repository.dispose);
    await repository.refreshSessions();
    final controller = DemoChatController(repository, 's1');
    addTearDown(controller.dispose);
    api.snapshotGate = Completer<void>();
    api.gateSnapshotCall = 2;

    final sending = controller.send(
      'Hello',
      const [],
      lookupAppLocalizations(const Locale('zh')),
    );
    for (var i = 0; i < 10 && !controller.running; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(controller.sending, isFalse);
    expect(controller.running, isTrue);
    expect(controller.busy, isTrue);

    api.snapshotGate!.complete();
    expect(await sending, isTrue);
    expect(controller.running, isFalse);
  });

  test('stopped run is not reported as a successful send', () async {
    api.records = [_record('s1')];
    api.snapshots['s1'] = [
      _snapshot('s1'),
      _snapshot('s1', runState: 'stopped'),
    ];
    final repository = DemoRepository.harness(
      storage,
      api,
      pollInterval: Duration.zero,
      maxPollAttempts: 1,
    )..restore();
    addTearDown(repository.dispose);
    await repository.refreshSessions();
    final controller = DemoChatController(repository, 's1');
    addTearDown(controller.dispose);

    expect(
      await controller.send(
        'Stop me',
        const [],
        lookupAppLocalizations(const Locale('zh')),
      ),
      isFalse,
    );
  });

  test('stopping a resumed run does not hide the next run failure', () async {
    api.records = [_record('s1')];
    api.snapshots['s1'] = [
      _snapshot('s1'),
      _snapshot('s1', runState: 'running'),
      _snapshot('s1', runState: 'interrupted'),
      _snapshot('s1', runState: 'failed'),
    ];
    final repository = DemoRepository.harness(
      storage,
      api,
      pollInterval: const Duration(milliseconds: 1),
      maxPollAttempts: 3,
    )..restore();
    addTearDown(repository.dispose);
    await repository.refreshSessions();
    final controller = DemoChatController(repository, 's1');
    addTearDown(controller.dispose);

    final resumed = repository.resumeHarnessSession('s1');
    await Future<void>.delayed(Duration.zero);
    expect(controller.running, isTrue);
    await controller.stop();
    await resumed;

    await expectLater(
      controller.send(
        'Next run',
        const [],
        lookupAppLocalizations(const Locale('zh')),
      ),
      throwsA(isA<HarnessRunTerminalException>()),
    );
  });

  test('a new run never reuses an uncertain stop request ID', () async {
    api.records = [_record('s1')];
    api.snapshots['s1'] = [
      _snapshot('s1', runState: 'running'),
      _snapshot('s1', runState: 'stopped'),
      _snapshot('s1', runState: 'stopped', runId: 'run-2'),
    ];
    api.stopFailuresAfterAccept = 3;
    api.sendRunIds.add('run-2');
    final repository = DemoRepository.harness(
      storage,
      api,
      pollInterval: Duration.zero,
      maxPollAttempts: 1,
    )..restore();
    addTearDown(repository.dispose);
    await repository.refreshSessions();

    await expectLater(
      repository.stopHarnessSession('s1'),
      throwsA(isA<DioException>()),
    );
    await expectLater(
      repository.stopHarnessSession('s1'),
      throwsA(isA<DioException>()),
    );
    expect(api.stopRequestIds[1], api.stopRequestIds[0]);

    await repository.refreshSession('s1');
    api.snapshotGate = Completer<void>();
    api.gateSnapshotCall = 3;
    final accepted = Completer<void>();
    final sending = repository.sendHarnessMessage(
      's1',
      clientRequestId: 'send-run-2',
      text: 'Start the next run',
      onAccepted: accepted.complete,
    );
    await accepted.future;

    await expectLater(
      repository.stopHarnessSession('s1'),
      throwsA(isA<DioException>()),
    );
    expect(api.stopRequestIds[2], isNot(api.stopRequestIds[0]));

    api.snapshotGate!.complete();
    await expectLater(sending, throwsA(isA<HarnessRunStoppedException>()));
  });

  testWidgets('same assistant ID paints completed reply after polling', (
    tester,
  ) async {
    api.records = [_record('s1')];
    api.snapshots['s1'] = [
      _snapshot(
        's1',
        messages: [_message('a1', 'assistant', '', status: 'pending')],
        runState: 'running',
      ),
      _snapshot(
        's1',
        messages: [_message('a1', 'assistant', '真实回复')],
        runState: 'completed',
      ),
    ];
    final repository = DemoRepository.harness(
      storage,
      api,
      pollInterval: Duration.zero,
      maxPollAttempts: 2,
    )..restore();
    addTearDown(repository.dispose);
    await repository.refreshSessions();
    api.snapshotGate = Completer<void>();
    api.gateSnapshotCall = 2;

    await _pumpChat(tester, repository);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is MarkdownMessage && widget.text == '真实回复',
      ),
      findsNothing,
    );

    api.snapshotGate!.complete();
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is MarkdownMessage && widget.text == '真实回复',
      ),
      findsOneWidget,
    );
  });

  testWidgets('accepted send replaces loading with enabled stop action', (
    tester,
  ) async {
    api.records = [_record('s1')];
    api.snapshots['s1'] = [
      _snapshot('s1'),
      _snapshot('s1'),
      _snapshot(
        's1',
        messages: [
          _message('u1', 'user', 'Hello'),
          _message('a1', 'assistant', 'Done'),
        ],
        runState: 'completed',
      ),
    ];
    final repository = DemoRepository.harness(
      storage,
      api,
      pollInterval: Duration.zero,
      maxPollAttempts: 2,
    )..restore();
    addTearDown(repository.dispose);
    await repository.refreshSessions();
    await _pumpChat(tester, repository);
    await tester.pumpAndSettle();
    api.sendGate = Completer<void>();
    api.snapshotGate = Completer<void>();
    api.gateSnapshotCall = 3;

    await tester.tap(find.byKey(const Key('popi-message-input')));
    await tester.pumpAndSettle();
    tester.testTextInput.enterText('Hello');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('popi-send-button')));
    await tester.pump();
    var action = tester.widget<IconButton>(
      find.byKey(const Key('popi-send-button')),
    );
    expect(action.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    api.sendGate!.complete();
    await tester.pump();
    await tester.pump();
    action = tester.widget<IconButton>(
      find.byKey(const Key('popi-send-button')),
    );
    expect(action.onPressed, isNotNull);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

    api.snapshotGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Done', findRichText: true), findsOneWidget);
  });

  test(
    'Harness creation transport includes the selected session kind',
    () async {
      final transport = Dio();
      addTearDown(() => transport.close(force: true));
      transport.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, '/api_agent/v2/sessions');
            expect(options.method, 'POST');
            expect(options.data, {
              'clientRequestId': 'request-1',
              'title': 'Workflow',
              'kind': 'workflow',
            });
            handler.resolve(
              Response(requestOptions: options, data: _record('s1')),
            );
          },
        ),
      );

      await NetworkAgentApi(transport).createHarnessSession(
        clientRequestId: 'request-1',
        title: 'Workflow',
        kind: 'workflow',
      );
    },
  );
}

class _HarnessApi extends NetworkAgentApi {
  _HarnessApi(super.dio);

  List<Map<String, Object?>> records = [];
  final Map<String, List<Map<String, Object?>>> snapshots = {};
  final List<String> createdKinds = [];
  final List<String> renamedTitles = [];
  final List<Map<String, Object?>> updatedConfigurations = [];
  final List<String> archivedIds = [];
  final List<String> sendRequestIds = [];
  final List<String> sendRunIds = [];
  final List<String> stopRequestIds = [];
  bool failFirstSend = false;
  int stopFailuresAfterAccept = 0;
  int snapshotCalls = 0;
  int? gateSnapshotCall;
  Completer<void>? snapshotGate;
  Completer<void>? sendGate;

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
    'list': records,
    'pageInfo': {
      'page': page,
      'pageSize': pageSize,
      'pageCount': 1,
      'total': records.length,
    },
  };

  @override
  Future<Map<String, dynamic>> sessionSnapshot(
    String id, {
    CancelToken? cancelToken,
  }) async {
    snapshotCalls += 1;
    if (snapshotCalls == gateSnapshotCall) await snapshotGate?.future;
    final queue = snapshots[id]!;
    if (queue.length == 1) return Map<String, dynamic>.from(queue.single);
    return Map<String, dynamic>.from(queue.removeAt(0));
  }

  @override
  Future<Map<String, dynamic>> createHarnessSession({
    required String clientRequestId,
    required String title,
    required String kind,
    Map<String, Object?>? configuration,
    CancelToken? cancelToken,
  }) async {
    createdKinds.add(kind);
    final record = _record(
      'server-created',
      title: title,
      kind: kind,
      configuration: configuration,
    );
    records.insert(0, record);
    snapshots['server-created'] = [_snapshot('server-created')];
    return Map<String, dynamic>.from(record);
  }

  @override
  Future<Map<String, dynamic>> updateSession(
    String id, {
    String? clientRequestId,
    String? title,
    bool? archived,
    bool? pinned,
    Map<String, Object?>? configuration,
    int? expectedConfigRevision,
    CancelToken? cancelToken,
  }) async {
    if (title != null) renamedTitles.add(title);
    if (configuration != null) {
      updatedConfigurations.add(Map<String, Object?>.from(configuration));
    }
    return {
      'id': id,
      if (title != null) 'title': title,
      if (configuration != null) 'configuration': configuration,
      if (configuration != null)
        'configRevision': (expectedConfigRevision ?? 0) + 1,
      if (configuration != null) 'configurationStatus': 'configured',
    };
  }

  @override
  Future<Map<String, dynamic>> archiveSession(
    String id, {
    String? clientRequestId,
    CancelToken? cancelToken,
  }) async {
    archivedIds.add(id);
    return {'id': id, 'archived': true};
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
  }) async {
    sendRequestIds.add(clientRequestId);
    await sendGate?.future;
    if (failFirstSend) {
      failFirstSend = false;
      throw DioException(
        requestOptions: RequestOptions(path: '/messages'),
        type: DioExceptionType.connectionError,
      );
    }
    return {
      'sessionId': id,
      'runId': sendRunIds.isEmpty ? 'run-1' : sendRunIds.removeAt(0),
      'messageId': 'u1',
      'state': 'queued',
    };
  }

  @override
  Future<Map<String, dynamic>> stopSession(
    String id, {
    required String clientRequestId,
    CancelToken? cancelToken,
  }) async {
    stopRequestIds.add(clientRequestId);
    if (stopFailuresAfterAccept > 0) {
      stopFailuresAfterAccept -= 1;
      throw DioException(
        requestOptions: RequestOptions(path: '/stop'),
        type: DioExceptionType.connectionError,
      );
    }
    return {'sessionId': id, 'runId': 'run-1', 'state': 'stopping'};
  }
}

Map<String, Object?> _record(
  String id, {
  String title = 'Session',
  String kind = 'conversation',
  Map<String, Object?>? configuration,
  bool includeTimestamps = true,
  Object? updatedAt = '2026-10-23T00:00:00.000Z',
}) => {
  'id': id,
  'title': title,
  'kind': kind,
  'revision': 1,
  if (includeTimestamps) 'createdAt': '2026-10-23T00:00:00.000Z',
  if (includeTimestamps) 'updatedAt': updatedAt,
  'archived': false,
  'bindingStatus': 'ready',
  'configuration': configuration ?? _configuration(),
  'configurationStatus': 'configured',
  'configRevision': 1,
};

Map<String, Object?> _configuration() => {
  'members': ['popi'],
  'roles': <String>[],
  'capabilities': ['character', 'script', 'image'],
  'memberCapabilities': {
    'popi': ['character', 'script', 'image'],
  },
  'memberNames': <String, String>{},
  'memberInstructions': <String, String>{},
  'memberAvatars': <String, String>{},
  'memberColors': <String, int>{},
  'workMode': 'onDemand',
  'activeMemberId': 'popi',
  'direction': '',
  'positioning': '',
  'roleProfiles': <String, Object?>{},
};

Map<String, Object?> _message(
  String id,
  String role,
  String text, {
  String status = 'completed',
  String memberId = '',
  String memberName = '',
  String runId = '',
  int configRevision = 0,
  Object? createdAt = '2026-10-23T00:00:00.000Z',
}) => {
  'id': id,
  'role': role,
  'text': text,
  'status': status,
  if (memberId.isNotEmpty) 'memberId': memberId,
  if (memberName.isNotEmpty) 'memberName': memberName,
  if (runId.isNotEmpty) 'runId': runId,
  if (configRevision != 0) 'configRevision': configRevision,
  if (createdAt != null) 'createdAt': createdAt,
};

Future<void> _pumpChat(WidgetTester tester, DemoRepository repository) async {
  await tester.pumpWidget(
    ProviderScope(
      child: ToastificationWrapper(
        child: MaterialApp(
          theme: AppTheme.light,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: DemoChatPage(repository: repository, sessionId: 's1'),
        ),
      ),
    ),
  );
  await tester.pump();
}

Map<String, Object?> _snapshot(
  String id, {
  String title = 'Session',
  List<Map<String, Object?>> messages = const [],
  Map<String, Object?>? sessionRecord,
  String? runState,
  String runId = 'run-1',
}) => {
  'session': sessionRecord ?? _record(id, title: title),
  'lastSeq': messages.length,
  'messages': messages,
  'runs': runState == null
      ? <Object?>[]
      : [
          {'id': runId, 'state': runState},
        ],
};
