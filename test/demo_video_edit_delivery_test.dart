import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PreferencesStorage storage;
  late Dio dio;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = PreferencesStorage(await SharedPreferences.getInstance());
    await DemoRepository.prepareHarnessStorage(storage);
    dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3084'));
  });

  tearDown(() => dio.close(force: true));

  test(
    'background video edit stays observed and delivers its owned asset',
    () async {
      final api = _VideoEditApi(dio, [
        _snapshot('queued'),
        _snapshot('rendering'),
        _snapshot('completed', deliver: true),
      ]);
      final repository = DemoRepository.harness(
        storage,
        api,
        pollInterval: Duration.zero,
        maxPollAttempts: 5,
      )..restore();
      addTearDown(repository.dispose);

      await repository.refreshSessions();
      await _eventually(
        () => repository
            .session(_sessionId)
            .messages
            .any((message) => message.assetIds.contains(_assetId)),
      );

      final session = repository.session(_sessionId);
      final job = session.mediaJobs.single;
      expect(api.snapshotCalls, 3);
      expect(job.operation, 'video-edit');
      expect(job.model, 'ffmpeg');
      expect(job.state, 'completed');
      expect(job.ingestionState, 'completed');
      expect(job.assetIds, [_assetId]);
      expect(repository.assets.single.id, _assetId);
    },
  );

  test(
    'a restored pending edit resumes observation without another POST',
    () async {
      final api = _VideoEditApi(dio, [
        _snapshot('queued'),
        _snapshot('rendering'),
        _snapshot('completed', deliver: true),
      ]);
      final first = DemoRepository.harness(
        storage,
        api,
        pollInterval: Duration.zero,
        maxPollAttempts: 0,
      )..restore();
      await first.refreshSessions();
      await _eventually(() => api.snapshotCalls >= 2);
      expect(first.session(_sessionId).mediaJobs.single.isPending, isTrue);
      first.dispose();

      final restored = DemoRepository.harness(
        storage,
        api,
        pollInterval: Duration.zero,
        maxPollAttempts: 5,
      )..restore();
      addTearDown(restored.dispose);
      expect(restored.session(_sessionId).mediaJobs.single.isPending, isTrue);

      await restored.refreshSessions();
      await _eventually(
        () =>
            restored.session(_sessionId).mediaJobs.single.state == 'completed',
      );
      expect(restored.session(_sessionId).messages.single.assetIds, [_assetId]);
      expect(api.writeCalls, 0);
    },
  );

  for (final terminal in ['failed', 'cancelled']) {
    test(
      '$terminal edit is terminal and does not start background polling',
      () async {
        final api = _VideoEditApi(dio, [_snapshot(terminal)]);
        final repository = DemoRepository.harness(
          storage,
          api,
          pollInterval: Duration.zero,
          maxPollAttempts: 5,
        )..restore();
        addTearDown(repository.dispose);

        await repository.refreshSessions();
        await Future<void>.delayed(Duration.zero);

        expect(
          repository.session(_sessionId).mediaJobs.single.isPending,
          isFalse,
        );
        expect(api.snapshotCalls, 1);
      },
    );
  }
}

const _sessionId = '11111111-1111-4111-8111-111111111111';
const _runId = '22222222-2222-4222-8222-222222222222';
const _jobId = '33333333-3333-4333-8333-333333333333';
const _assetId = '44444444-4444-4444-8444-444444444444';

Future<void> _eventually(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('condition did not settle');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

class _VideoEditApi extends NetworkAgentApi {
  _VideoEditApi(super.dio, this.snapshots);

  final List<Map<String, Object?>> snapshots;
  var snapshotCalls = 0;
  var writeCalls = 0;

  @override
  Future<Map<String, dynamic>> sessionsPage({
    int page = 1,
    int pageSize = 20,
    bool archived = false,
    String? accountId,
    CancelToken? cancelToken,
  }) async => {
    'list': [_sessionRecord()],
    'pageInfo': {'page': 1, 'pageSize': pageSize, 'pageCount': 1, 'total': 1},
  };

  @override
  Future<Map<String, dynamic>> sessionSnapshot(
    String id, {
    CancelToken? cancelToken,
  }) async {
    snapshotCalls += 1;
    if (snapshots.length == 1) {
      return Map<String, dynamic>.from(snapshots.single);
    }
    return Map<String, dynamic>.from(snapshots.removeAt(0));
  }

  @override
  Future<Map<String, dynamic>> assets({
    String? sessionId,
    CancelToken? cancelToken,
  }) async => {'list': <Object?>[]};

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
    writeCalls += 1;
    throw StateError('background observation must stay read-only');
  }
}

Map<String, Object?> _sessionRecord() => {
  'id': _sessionId,
  'title': '剪辑会话',
  'kind': 'conversation',
  'revision': 1,
  'createdAt': '2026-10-26T00:00:00.000Z',
  'updatedAt': '2026-10-26T00:00:00.000Z',
  'archived': false,
  'bindingStatus': 'ready',
  'configuration': _configuration(),
  'configurationStatus': 'configured',
  'configRevision': 0,
};

Map<String, Object?> _configuration() => {
  'members': ['popi'],
  'roles': <String>[],
  'capabilities': ['video'],
  'memberCapabilities': {
    'popi': ['video'],
  },
  'memberNames': {'popi': 'POPi'},
  'memberInstructions': <String, String>{},
  'memberAvatars': <String, String>{},
  'memberColors': <String, int>{},
  'memberSkills': {
    'popi': ['ffmpeg-video-edit'],
  },
  'memberBotIds': {'popi': 'builtin:popi'},
  'workMode': 'onDemand',
  'activeMemberId': 'popi',
  'direction': '',
  'positioning': '',
  'roleProfiles': <String, Object?>{},
  'accountPreferences': <String, String>{},
  'creativeMemory': {'text': '', 'source': 'ai'},
};

Map<String, Object?> _snapshot(String state, {bool deliver = false}) => {
  'session': _sessionRecord(),
  'lastSeq': deliver ? 1 : 0,
  'messages': deliver
      ? [
          {
            'id': '55555555-5555-4555-8555-555555555555',
            'role': 'assistant',
            'text': '',
            'status': 'completed',
            'runId': _runId,
            'memberId': 'popi',
            'memberName': 'POPi',
            'assetIds': [_assetId],
            'createdAt': '2026-10-26T00:00:01.000Z',
          },
        ]
      : <Object?>[],
  'runs': [
    {'id': _runId, 'state': 'completed'},
  ],
  'mediaJobs': <Object?>[],
  'filmJobs': <Object?>[],
  'videoEditJobs': [
    {
      'jobId': _jobId,
      'sessionId': _sessionId,
      'runId': _runId,
      'memberId': 'popi',
      'memberName': 'POPi',
      'configRevision': 0,
      'title': '剪辑成片',
      'state': state,
      'stage': state,
      'assetIds': deliver ? [_assetId] : <Object?>[],
      if (state == 'failed')
        'error': {'code': 'video_edit_failed', 'message': '剪辑失败'},
      'createdAt': '2026-10-26T00:00:00.000Z',
      'updatedAt': '2026-10-26T00:00:01.000Z',
    },
  ],
  'assets': deliver ? [_assetRecord()] : <Object?>[],
};

Map<String, Object?> _assetRecord() => {
  'id': _assetId,
  'title': '剪辑成片',
  'kind': 'video',
  'mimeType': 'video/mp4',
  'sizeBytes': 1024,
  'sha256': 'a' * 64,
  'contentUrl': '/api_agent/v2/assets/$_assetId/content',
  'posterUrl': '/api_agent/v2/assets/$_assetId/poster',
  'sessionId': _sessionId,
  'jobId': _jobId,
  'runId': _runId,
  'memberId': 'popi',
  'configRevision': 0,
  'width': 720,
  'height': 1280,
  'durationSeconds': 3,
  'hasAudio': true,
  'createdAt': '2026-10-26T00:00:01.000Z',
};
