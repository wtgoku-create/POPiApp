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
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_widgets.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/type/bot_avatar_type.dart';
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
    'an activity-only server message survives restore without exposing steps',
    (tester) async {
      api.messages = [_message(kind: 'search', steps: true)];
      final repository = await _repository(api);
      addTearDown(repository.dispose);
      await _pump(tester, repository);

      expect(find.byType(DemoActivityIndicator), findsOneWidget);
      expect(find.text('正在搜索资料'), findsOneWidget);
      expect(find.byKey(const Key('demo-activity-steps')), findsNothing);
      expect(find.byKey(const Key('demo-activity-toggle')), findsNothing);
      expect(find.text('正在调用模型'), findsNothing);

      await repository.resumeHarnessSession('activity-session');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('demo-activity-steps')), findsNothing);
      expect(find.text('正在搜索资料'), findsOneWidget);
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
    expect(find.text('正在搜索资料'), findsOneWidget);
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
      expect(api.updateCalls, 1);
      expect(api.sendCalls, 1);
      expect(find.text('正在思考你的内容'), findsOneWidget);
      expect(_composer(tester).controller.markdown, '生成一段生日视频');

      api.sendGate!.complete({'runId': 'run-1', 'state': 'queued'});
      await tester.pump();
      await tester.pump();
      expect(_composer(tester).controller.markdown, isEmpty);
      expect(find.text('正在思考你的内容'), findsOneWidget);

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
      expect(find.text('正在思考你的内容'), findsNothing);
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
      expect(find.text('正在生成视频'), findsOneWidget);
      expect(find.text('视频已提交，完成后会出现在这里。'), findsOneWidget);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('demo-activity-assistant-1')))
            .dy,
        greaterThan(tester.getBottomLeft(find.text('视频已提交，完成后会出现在这里。')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('activity uses the current chat assistant avatar and color', (
    tester,
  ) async {
    api.record = _recordWithAssistant(
      memberId: 'writer',
      name: '闪闪',
      avatar: BotAvatarCharacter.rabbit.stillAsset,
      color: 0xFFFFE9B8,
    );
    api.messages = [_message(kind: 'search', memberId: '')];
    final repository = await _repository(api);
    addTearDown(repository.dispose);
    await _pump(tester, repository);

    final activity = find.byKey(const ValueKey('demo-activity-assistant-1'));
    final avatar = tester.widget<DemoAvatar>(
      find.descendant(of: activity, matching: find.byType(DemoAvatar)),
    );
    expect(avatar.members, ['writer']);
    expect(
      avatar.memberAvatars['writer'],
      BotAvatarCharacter.rabbit.stillAsset,
    );
    expect(avatar.memberColors['writer'], 0xFFFFE9B8);
    expect(find.text('正在搜索资料'), findsOneWidget);
    expect(find.textContaining('POPi ·'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Map<String, Object?> _message({
  String text = '',
  String kind = 'thinking',
  String status = 'running',
  bool steps = false,
  String memberId = 'popi',
}) => {
  'id': 'assistant-1',
  'role': 'assistant',
  'text': text,
  'memberId': memberId,
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

  Map<String, Object?> record = _record;
  List<Map<String, Object?>> messages = [];
  List<Map<String, Object?>> mediaJobs = [];
  Completer<Map<String, dynamic>>? sendGate;
  Completer<Map<String, dynamic>>? snapshotGate;
  bool accepted = false;
  int sendCalls = 0;
  int updateCalls = 0;

  Map<String, dynamic> snapshot({
    List<Map<String, Object?>>? messages,
    String? runState,
  }) => {
    'session': record,
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
    'list': [record],
    'pageInfo': {'page': 1, 'pageSize': 20, 'pageCount': 1, 'total': 1},
  };

  @override
  Future<Map<String, dynamic>> sessionSnapshot(
    String id, {
    CancelToken? cancelToken,
  }) async => snapshotGate != null ? snapshotGate!.future : snapshot();

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
    updateCalls++;
    final revision = (record['configRevision'] as num?)?.toInt() ?? 0;
    expect(expectedConfigRevision, revision);
    record = {
      ...record,
      if (title != null) 'title': title,
      if (pinned != null) 'pinned': pinned,
      if (configuration != null) 'configuration': configuration,
      'configurationStatus': 'configured',
      'configRevision': configuration == null ? revision : revision + 1,
      'revision': ((record['revision'] as num?)?.toInt() ?? 0) + 1,
    };
    return Map<String, dynamic>.from(record);
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

Map<String, Object?> _recordWithAssistant({
  required String memberId,
  required String name,
  required String avatar,
  required int color,
}) => {
  ..._record,
  'configuration': {
    ...(_record['configuration']! as Map<String, Object?>),
    'members': [memberId],
    'activeMemberId': memberId,
    'memberNames': {memberId: name},
    'memberAvatars': {memberId: avatar},
    'memberColors': {memberId: color},
  },
};
