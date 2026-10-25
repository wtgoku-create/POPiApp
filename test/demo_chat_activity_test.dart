import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_page.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_activity_indicator.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

Future<DemoRepository> _repository(_ActivityApi api) async {
  SharedPreferences.setMockInitialValues({});
  final storage = PreferencesStorage(await SharedPreferences.getInstance());
  await DemoRepository.prepareHarnessStorage(storage);
  final repository = DemoRepository.harness(
    storage,
    api,
    pollInterval: Duration.zero,
    maxPollAttempts: 0,
  )..restore();
  await repository.refreshSessions();
  return repository;
}

Future<void> _pump(
  WidgetTester tester,
  DemoRepository repository, {
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: ToastificationWrapper(
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: DemoChatPage(
            repository: repository,
            sessionId: 'activity-session',
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

PopiMessageComposer _composer(WidgetTester tester) =>
    tester.widget<PopiMessageComposer>(find.byType(PopiMessageComposer));

void main() {
  late Dio dio;
  late _ActivityApi api;

  setUp(() {
    dio = Dio();
    api = _ActivityApi(dio);
  });
  tearDown(() {
    dio.close(force: true);
    toastification.dismissAll(delayForAnimation: false);
  });

  testWidgets(
    'an activity-only server message survives restore and can expand',
    (tester) async {
      api.messages = [_message(kind: 'search', steps: true)];
      final repository = await _repository(api);
      addTearDown(repository.dispose);
      await _pump(tester, repository);

      expect(find.byType(DemoActivityIndicator), findsOneWidget);
      expect(find.text('POPi · 正在搜索资料'), findsOneWidget);
      expect(find.byKey(const Key('demo-activity-steps')), findsNothing);
      await tester.tap(find.byKey(const Key('demo-activity-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('正在调用模型'), findsOneWidget);

      await repository.resumeHarnessSession('activity-session');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('demo-activity-steps')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending initial snapshot shows loading then cached messages', (
    tester,
  ) async {
    final repository = await _repository(api);
    addTearDown(repository.dispose);
    api.snapshotGate = Completer<Map<String, dynamic>>();

    await _pump(tester, repository, settle: false);

    expect(
      find.byType(CircularProgressIndicator),
      findsNWidgets(2),
      reason: 'the body and composer both reflect the pending first snapshot',
    );
    expect(find.byType(DemoActivityIndicator), findsNothing);

    api.snapshotGate!.complete(
      api.snapshot(messages: [_message(kind: 'search', steps: false)]),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(DemoActivityIndicator), findsOneWidget);
    expect(find.text('POPi · 正在搜索资料'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'send immediately shows thinking and clears draft once accepted',
    (tester) async {
      final repository = await _repository(api);
      addTearDown(repository.dispose);
      await _pump(tester, repository);
      api.sendGate = Completer<Map<String, dynamic>>();
      api.snapshotGate = Completer<Map<String, dynamic>>();
      await _composer(tester).controller.setText('生成一段生日视频');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('popi-send-button')));
      await tester.pump();
      await tester.pump();
      expect(api.sendCalls, 1);
      expect(find.text('POPi · 正在思考你的内容'), findsOneWidget);
      expect(_composer(tester).controller.markdown, '生成一段生日视频');

      api.sendGate!.complete({'runId': 'run-1', 'state': 'queued'});
      await tester.pump();
      await tester.pump();
      expect(_composer(tester).controller.markdown, isEmpty);
      expect(find.text('POPi · 正在思考你的内容'), findsOneWidget);

      api.snapshotGate!.complete(
        api.snapshot(
          messages: [
            {'id': 'user-1', 'role': 'user', 'text': '生成一段生日视频'},
            _message(text: '方案已整理好。', kind: 'reply', status: 'completed'),
          ],
          runState: 'completed',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('POPi · 正在思考你的内容'), findsNothing);
      expect(find.byType(DemoActivityIndicator), findsOneWidget);
      expect(find.text('方案已整理好。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a rejected send preserves the draft and removes provisional progress',
    (tester) async {
      final repository = await _repository(api);
      addTearDown(repository.dispose);
      await _pump(tester, repository);
      api.sendGate = Completer<Map<String, dynamic>>();
      await _composer(tester).controller.setText('保留这份脚本要求');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('popi-send-button')));
      await tester.pump();
      await tester.pump();
      expect(find.byType(DemoActivityIndicator), findsOneWidget);

      api.sendGate!.completeError(
        DioException(
          requestOptions: RequestOptions(path: '/messages'),
          type: DioExceptionType.connectionError,
        ),
      );
      await tester.pumpAndSettle();
      expect(_composer(tester).controller.markdown, '保留这份脚本要求');
      expect(find.byType(DemoActivityIndicator), findsNothing);
      expect(find.byKey(const Key('popi-send-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
      toastification.dismissAll(delayForAnimation: false);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'completed reply keeps displaying a pending video job as generation',
    (tester) async {
      api.messages = [
        _message(text: '视频已提交，完成后会出现在这里。', kind: 'reply', status: 'completed'),
      ];
      api.mediaJobs = [
        {
          'jobId': 'video-job',
          'state': 'pending',
          'operation': 'video',
          'model': 'video-model',
          'runId': 'run-1',
          'memberId': 'popi',
        },
      ];
      final repository = await _repository(api);
      addTearDown(repository.dispose);
      await _pump(tester, repository);

      final indicator = tester.widget<DemoActivityIndicator>(
        find.byType(DemoActivityIndicator),
      );
      expect(indicator.activity.kind, 'video');
      expect(indicator.activity.status, 'running');
      expect(find.text('POPi · 正在生成视频'), findsOneWidget);
      expect(find.text('视频已提交，完成后会出现在这里。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Map<String, Object?> _message({
  String text = '',
  String kind = 'thinking',
  String status = 'running',
  bool steps = false,
}) => {
  'id': 'assistant-1',
  'role': 'assistant',
  'text': text,
  'memberId': 'popi',
  'runId': 'run-1',
  'status': status,
  'createdAt': '2026-10-25T00:00:00.000Z',
  'activity': {
    'kind': kind,
    'status': status,
    if (steps)
      'steps': [
        {'id': 'model', 'kind': 'model', 'status': 'completed'},
        {'id': 'search', 'kind': 'search', 'status': 'running'},
      ],
  },
};

class _ActivityApi extends NetworkAgentApi {
  _ActivityApi(super.dio);

  List<Map<String, Object?>> messages = [];
  List<Map<String, Object?>> mediaJobs = [];
  Completer<Map<String, dynamic>>? sendGate;
  Completer<Map<String, dynamic>>? snapshotGate;
  bool accepted = false;
  int sendCalls = 0;

  Map<String, dynamic> snapshot({
    List<Map<String, Object?>>? messages,
    String? runState,
  }) => {
    'session': _record,
    'lastSeq': accepted ? 2 : 1,
    'messages': messages ?? this.messages,
    'mediaJobs': mediaJobs,
    'runs': [
      if (runState != null) {'id': 'run-1', 'state': runState},
    ],
  };

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
    'list': [_record],
    'pageInfo': {'page': 1, 'pageSize': 20, 'pageCount': 1, 'total': 1},
  };

  @override
  Future<Map<String, dynamic>> sessionSnapshot(
    String id, {
    CancelToken? cancelToken,
  }) async => snapshotGate != null ? snapshotGate!.future : snapshot();

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
    sendCalls++;
    final result = await sendGate!.future;
    accepted = true;
    return result;
  }
}

final _record = <String, Object?>{
  'id': 'activity-session',
  'title': '活动反馈',
  'kind': 'conversation',
  'revision': 1,
  'createdAt': '2026-10-25T00:00:00.000Z',
  'updatedAt': '2026-10-25T00:00:00.000Z',
  'archived': false,
  'bindingStatus': 'ready',
  'configurationStatus': 'configured',
  'configRevision': 1,
  'configuration': {
    'members': ['popi'],
    'roles': <String>[],
    'capabilities': <String>[],
    'memberNames': <String, String>{},
    'memberInstructions': <String, String>{},
    'memberAvatars': <String, String>{},
    'memberColors': <String, int>{},
    'memberCapabilities': <String, Object?>{},
    'workMode': 'onDemand',
    'activeMemberId': 'popi',
  },
};
