import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Dio dio;
  late PreferencesStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = PreferencesStorage(await SharedPreferences.getInstance());
    await DemoRepository.prepareHarnessStorage(storage);
    dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3084'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              error: StateError('Owned asset tests must use the fake API'),
            ),
          );
        },
      ),
    );
  });

  tearDown(() => dio.close(force: true));

  test(
    'refresh replaces assets only for sessions present in snapshots',
    () async {
      final api = _AssetApi(dio)
        ..records = [_record('s1'), _record('s2')]
        ..snapshots = {
          's1': [
            _snapshot('s1', assets: [_asset('asset-1', 's1')]),
          ],
          's2': [
            _snapshot('s2', assets: [_asset('asset-2', 's2')]),
          ],
        };
      final repository = DemoRepository.harness(storage, api)..restore();
      addTearDown(repository.dispose);

      await repository.refreshSessions();
      expect(repository.assets.map((asset) => asset.id).toSet(), {
        'asset-1',
        'asset-2',
      });

      api
        ..records = [_record('s1')]
        ..snapshots = {
          's1': [_snapshot('s1', assets: const [])],
        };
      await repository.refreshSessions();

      expect(repository.assets.map((asset) => asset.id), ['asset-2']);
      expect(repository.assets.single.sessionId, 's2');
    },
  );

  test(
    'repeated session refresh keeps the visible mixed asset order stable',
    () async {
      final upload = {..._asset('upload-1', ''), 'sessionId': null};
      final api = _AssetApi(dio)
        ..records = [_record('s1'), _record('s2')]
        ..listedAssets = [upload]
        ..snapshots = {
          's1': [
            _snapshot('s1', assets: [_asset('generated-1', 's1')]),
          ],
          's2': [
            _snapshot('s2', assets: [_asset('generated-2', 's2')]),
          ],
        };
      final repository = DemoRepository.harness(storage, api)..restore();
      addTearDown(repository.dispose);

      await repository.refreshSessions();
      const expected = ['upload-1', 'generated-1', 'generated-2'];
      expect(repository.assets.map((asset) => asset.id), expected);

      final visibleOrders = <List<String>>[];
      repository.addListener(
        () => visibleOrders.add(
          repository.assets.map((asset) => asset.id).toList(),
        ),
      );
      await repository.refreshSessions();

      expect(visibleOrders, isNotEmpty);
      expect(visibleOrders, everyElement(expected));
    },
  );

  test(
    'authoritative asset refresh updates in place and prepends only new IDs',
    () async {
      final upload = {..._asset('upload-1', ''), 'sessionId': null};
      final api = _AssetApi(dio)
        ..records = [_record('s1'), _record('s2')]
        ..listedAssets = [upload]
        ..snapshots = {
          's1': [
            _snapshot('s1', assets: [_asset('generated-1', 's1')]),
          ],
          's2': [
            _snapshot('s2', assets: [_asset('generated-2', 's2')]),
          ],
        };
      final repository = DemoRepository.harness(storage, api)..restore();
      addTearDown(repository.dispose);
      await repository.refreshSessions();

      api
        ..listedAssets = [
          {...upload, 'title': 'Updated upload'},
        ]
        ..snapshots = {
          's1': [
            _snapshot(
              's1',
              assets: [
                {..._asset('generated-1', 's1'), 'title': 'Updated generated'},
                _asset('generated-new', 's1'),
              ],
            ),
          ],
          's2': [_snapshot('s2', assets: const [])],
        };

      await repository.refreshSessions();

      expect(repository.assets.map((asset) => asset.id), [
        'generated-new',
        'upload-1',
        'generated-1',
      ]);
      expect(
        repository.assets.firstWhere((asset) => asset.id == 'upload-1').title,
        'Updated upload',
      );
      expect(
        repository.assets
            .firstWhere((asset) => asset.id == 'generated-1')
            .title,
        'Updated generated',
      );

      final restored = DemoRepository.harness(storage, api)..restore();
      addTearDown(restored.dispose);
      expect(restored.assets.map((asset) => asset.id), [
        'generated-new',
        'upload-1',
        'generated-1',
      ]);
    },
  );

  test(
    'completed owned asset updates the same message without another POST',
    () async {
      final api = _AssetApi(dio)
        ..records = [_record('s1')]
        ..snapshots = {
          's1': [
            _snapshot('s1'),
            _snapshot(
              's1',
              messages: [_message('assistant-1')],
              runs: [_run('completed', configRevision: 5)],
              mediaJobs: [_job('pending')],
            ),
            _snapshot(
              's1',
              messages: [
                _message('assistant-1', assetIds: const ['asset-1']),
              ],
              runs: [_run('completed', configRevision: 5)],
              mediaJobs: [
                _job(
                  'completed',
                  assetIds: const ['asset-1'],
                  ingestionState: 'completed',
                ),
              ],
              assets: [_asset('asset-1', 's1')],
            ),
          ],
        };
      final repository = DemoRepository.harness(
        storage,
        api,
        pollInterval: Duration.zero,
        maxPollAttempts: 3,
      )..restore();
      addTearDown(repository.dispose);
      await repository.refreshSessions();

      var notifications = 0;
      repository.addListener(() => notifications += 1);
      await repository.sendHarnessMessage(
        's1',
        clientRequestId: 'request-1',
        text: '画一张南极角色图',
      );

      expect(repository.isSessionRunning('s1'), isFalse);
      for (
        var attempt = 0;
        attempt < 10 && repository.assets.isEmpty;
        attempt++
      ) {
        await Future<void>.delayed(Duration.zero);
      }

      final message = repository.session('s1').messages.single;
      expect(message.id, 'assistant-1');
      expect(message.assetIds, ['asset-1']);
      expect(repository.assets.single.id, 'asset-1');
      expect(repository.assets.single.isRemote, isTrue);
      expect(repository.assets.single.runId, 'run-1');
      expect(repository.session('s1').mediaJobs.single.configRevision, 5);
      expect(api.sendCalls, 1);
      expect(notifications, greaterThanOrEqualTo(2));

      final restored = DemoRepository.harness(storage, api)..restore();
      addTearDown(restored.dispose);
      expect(restored.assets.single.id, 'asset-1');
      expect(restored.session('s1').messages.single.assetIds, ['asset-1']);
    },
  );

  test('asset metadata remains compatible with offline fixture JSON', () {
    const remote = DemoAsset(
      id: 'asset-1',
      title: '南极角色图',
      kind: DemoAssetKind.image,
      cover: 'http://127.0.0.1:3084/api_agent/v2/assets/asset-1/content',
      contentUrl: 'http://127.0.0.1:3084/api_agent/v2/assets/asset-1/content',
      sessionId: 's1',
      jobId: 'job-1',
      runId: 'run-1',
      memberId: 'designer',
      configRevision: 5,
      mimeType: 'image/png',
      sha256: 'abc',
      sizeBytes: 128,
      width: 32,
      height: 32,
      createdAt: '2026-10-23T00:00:00.000Z',
    );
    final decoded = DemoAsset.fromJson(remote.toJson());
    expect(decoded.isRemote, isTrue);
    expect(decoded.jobId, 'job-1');
    expect(decoded.width, 32);

    final legacy = DemoAsset.fromJson({
      'id': 'fixture',
      'title': 'Fixture',
      'kind': 'image',
      'cover': 'assets/images/demo_scene_1.png',
      'sessionId': null,
      'body': '',
      'media': '',
    });
    expect(legacy.isRemote, isFalse);
    expect(legacy.cover, 'assets/images/demo_scene_1.png');
  });

  test('owned video metadata survives JSON round-trip', () {
    const video = DemoAsset(
      id: 'video-1',
      title: '南极咖啡馆',
      kind: DemoAssetKind.video,
      cover: '',
      media: 'http://127.0.0.1:3084/api_agent/v2/assets/video-1/content',
      contentUrl: 'http://127.0.0.1:3084/api_agent/v2/assets/video-1/content',
      posterUrl: 'http://127.0.0.1:3084/api_agent/v2/assets/video-1/poster',
      sessionId: 's1',
      jobId: 'job-video',
      runId: 'run-1',
      memberId: 'designer',
      configRevision: 5,
      mimeType: 'video/mp4',
      sha256: 'video-hash',
      sizeBytes: 4096,
      width: 854,
      height: 480,
      durationSeconds: 30.04,
      hasAudio: true,
      createdAt: '2026-10-24T00:00:00.000Z',
    );

    final restored = DemoAsset.fromJson(video.toJson());
    expect(restored.kind, DemoAssetKind.video);
    expect(restored.cover, isEmpty);
    expect(restored.media, restored.contentUrl);
    expect(restored.posterUrl, video.posterUrl);
    expect(restored.durationSeconds, 30.04);
    expect(restored.hasAudio, isTrue);
  });

  test(
    'completed video shares one asset ID between message and library',
    () async {
      final api = _AssetApi(dio)
        ..records = [_record('s1')]
        ..snapshots = {
          's1': [
            _snapshot('s1'),
            _snapshot(
              's1',
              messages: [_message('assistant-video')],
              runs: [_run('completed', configRevision: 5)],
              mediaJobs: [_job('pending', operation: 'video')],
            ),
            _snapshot(
              's1',
              messages: [
                _message('assistant-video', assetIds: const ['video-1']),
              ],
              runs: [_run('completed', configRevision: 5)],
              mediaJobs: [
                _job(
                  'completed',
                  operation: 'video',
                  assetIds: const ['video-1'],
                  ingestionState: 'completed',
                ),
              ],
              assets: [
                _asset(
                  'video-1',
                  's1',
                  kind: 'video',
                  durationSeconds: 30.04,
                  hasAudio: true,
                  posterUrl: '/api_agent/v2/assets/video-1/poster',
                ),
              ],
            ),
          ],
        };
      final repository = DemoRepository.harness(
        storage,
        api,
        pollInterval: Duration.zero,
        maxPollAttempts: 3,
      )..restore();
      addTearDown(repository.dispose);
      await repository.refreshSessions();

      await repository.sendHarnessMessage(
        's1',
        clientRequestId: 'video-request',
        text: '生成南极咖啡视频',
      );
      for (
        var attempt = 0;
        attempt < 10 && repository.assets.isEmpty;
        attempt++
      ) {
        await Future<void>.delayed(Duration.zero);
      }

      final message = repository.session('s1').messages.single;
      final asset = repository.assets.single;
      expect(message.assetIds, ['video-1']);
      expect(asset.id, message.assetIds.single);
      expect(asset.kind, DemoAssetKind.video);
      expect(asset.cover, isEmpty);
      expect(asset.media, asset.contentUrl);
      expect(
        asset.posterUrl,
        'http://127.0.0.1:3084/api_agent/v2/assets/video-1/poster',
      );
      expect(asset.mimeType, 'video/mp4');
      expect(asset.durationSeconds, 30.04);
      expect(asset.hasAudio, isTrue);
      expect(api.sendCalls, 1);

      final restored = DemoRepository.harness(storage, api)..restore();
      addTearDown(restored.dispose);
      expect(restored.assets.single.posterUrl, asset.posterUrl);
    },
  );

  test('invalid snapshot poster is cleared without dropping video', () async {
    final api = _AssetApi(dio)
      ..records = [_record('s1')]
      ..snapshots = {
        's1': [
          _snapshot(
            's1',
            assets: [
              _asset(
                'video-1',
                's1',
                kind: 'video',
                posterUrl: '/api_agent/v2/assets/another-video/poster',
              ),
            ],
          ),
        ],
      };
    final repository = DemoRepository.harness(storage, api)..restore();
    addTearDown(repository.dispose);

    await repository.refreshSessions();

    expect(repository.assets, hasLength(1));
    expect(repository.assets.single.id, 'video-1');
    expect(repository.assets.single.contentUrl, isNotEmpty);
    expect(repository.assets.single.posterUrl, isEmpty);
  });

  test(
    'a delayed older snapshot cannot replace newer chat or assets',
    () async {
      final api = _AssetApi(dio)
        ..records = [_record('s1')]
        ..snapshots = {
          's1': [_snapshot('s1', lastSeq: 1)],
        };
      final repository = DemoRepository.harness(
        storage,
        api,
        pollInterval: Duration.zero,
        maxPollAttempts: 1,
      )..restore();
      addTearDown(repository.dispose);
      await repository.refreshSessions();

      api.snapshots['s1'] = [
        _snapshot(
          's1',
          lastSeq: 2,
          messages: [_message('assistant-old')],
          assets: [_asset('asset-old', 's1')],
        ),
        _snapshot(
          's1',
          lastSeq: 3,
          messages: [
            _message('assistant-new', assetIds: const ['asset-new']),
          ],
          runs: [_run('completed', configRevision: 5)],
          assets: [_asset('asset-new', 's1')],
        ),
      ];
      final delayedGate = Completer<void>();
      api.nextSnapshotGate = delayedGate;
      api.snapshotStarted = Completer<void>();
      final delayedRefresh = repository.refreshSession('s1');
      await api.snapshotStarted!.future;

      await repository.sendHarnessMessage(
        's1',
        clientRequestId: 'request-new',
        text: 'new request',
      );
      expect(repository.session('s1').lastSeq, 3);

      delayedGate.complete();
      await delayedRefresh;

      expect(repository.session('s1').messages.single.id, 'assistant-new');
      expect(repository.session('s1').lastSeq, 3);
      expect(repository.assets.single.id, 'asset-new');
    },
  );

  test(
    'a delayed PATCH cannot replace a newer snapshot timeline or assets',
    () async {
      final api = _AssetApi(dio)
        ..records = [_record('s1')]
        ..snapshots = {
          's1': [
            _snapshot(
              's1',
              lastSeq: 5,
              messages: [_message('assistant-base')],
              mediaJobs: [_job('completed')],
              assets: [_asset('asset-base', 's1')],
            ),
          ],
        };
      final repository = DemoRepository.harness(storage, api)..restore();
      addTearDown(repository.dispose);
      await repository.refreshSessions();

      final updateGate = Completer<void>();
      api
        ..updateGate = updateGate
        ..updateStarted = Completer<void>();
      final delayedUpdate = repository.updateSession(
        's1',
        (session) => session.copyWith(workMode: 'manual'),
      );
      await api.updateStarted!.future;

      api.snapshots['s1'] = [
        _snapshot(
          's1',
          configuration: _configuration(workMode: 'automatic'),
          configRevision: 7,
          serverRevision: 7,
          lastSeq: 6,
          messages: [
            _message('assistant-new', assetIds: const ['asset-new']),
          ],
          mediaJobs: [
            _job(
              'completed',
              assetIds: const ['asset-new'],
              ingestionState: 'completed',
            ),
          ],
          assets: [_asset('asset-new', 's1')],
        ),
      ];
      await repository.refreshSession('s1');
      updateGate.complete();
      await delayedUpdate;

      final session = repository.session('s1');
      expect(session.serverRevision, 7);
      expect(session.configRevision, 7);
      expect(session.lastSeq, 6);
      expect(session.workMode, 'automatic');
      expect(session.messages.single.id, 'assistant-new');
      expect(session.mediaJobs.single.assetIds, ['asset-new']);
      expect(repository.assets.single.id, 'asset-new');
    },
  );

  test(
    'Harness restore rebuilds remote URLs and drops invalid asset IDs',
    () async {
      await storage.setString(
        DemoRepository.harnessStorageKey,
        jsonEncode({
          'sessions': <Object?>[],
          'assets': [
            const DemoAsset(
              id: 'safe_asset-1',
              title: 'Cached remote',
              kind: DemoAssetKind.image,
              cover: 'https://attacker.invalid/cover.png',
              contentUrl: 'https://attacker.invalid/content.png',
            ).toJson(),
            const DemoAsset(
              id: '../escape',
              title: 'Invalid remote',
              kind: DemoAssetKind.image,
              cover: 'https://attacker.invalid/escape.png',
              contentUrl: 'https://attacker.invalid/escape.png',
            ).toJson(),
            const DemoAsset(
              id: 'safe_video-1',
              title: 'Cached video',
              kind: DemoAssetKind.video,
              cover: 'https://attacker.invalid/poster.png',
              media: 'https://attacker.invalid/video.mp4',
              posterUrl: 'https://attacker.invalid/poster.png',
              mimeType: 'video/mp4',
              durationSeconds: 29.97,
              hasAudio: true,
            ).toJson(),
          ],
        }),
      );

      final repository = DemoRepository.harness(storage, _AssetApi(dio))
        ..restore();
      addTearDown(repository.dispose);

      expect(repository.assets, hasLength(2));
      final image = repository.assets.firstWhere(
        (asset) => asset.id == 'safe_asset-1',
      );
      expect(
        image.contentUrl,
        'http://127.0.0.1:3084/api_agent/v2/assets/safe_asset-1/content',
      );
      expect(image.cover, image.contentUrl);
      final video = repository.assets.firstWhere(
        (asset) => asset.id == 'safe_video-1',
      );
      expect(video.cover, isEmpty);
      expect(
        video.media,
        'http://127.0.0.1:3084/api_agent/v2/assets/safe_video-1/content',
      );
      expect(video.contentUrl, video.media);
      expect(video.posterUrl, isEmpty);
      expect(video.durationSeconds, 29.97);
      expect(video.hasAudio, isTrue);
    },
  );
}

class _AssetApi extends NetworkAgentApi {
  _AssetApi(super.dio);

  List<Map<String, Object?>> records = [];
  List<Map<String, Object?>> listedAssets = [];
  Map<String, List<Map<String, Object?>>> snapshots = {};
  int sendCalls = 0;
  Completer<void>? nextSnapshotGate;
  Completer<void>? snapshotStarted;
  Completer<void>? updateGate;
  Completer<void>? updateStarted;

  @override
  Future<Map<String, dynamic>> assets({
    String? sessionId,
    CancelToken? cancelToken,
  }) async => {'list': listedAssets};

  @override
  Future<Map<String, dynamic>> sessionsPage({
    int page = 1,
    int pageSize = 20,
    bool archived = false,
    String? accountId,
    CancelToken? cancelToken,
  }) async => {
    'list': records,
    'pageInfo': {'page': page, 'pageSize': pageSize, 'pageCount': 1},
  };

  @override
  Future<Map<String, dynamic>> sessionSnapshot(
    String id, {
    CancelToken? cancelToken,
  }) async {
    final queue = snapshots[id]!;
    final value = queue.length == 1 ? queue.single : queue.removeAt(0);
    final gate = nextSnapshotGate;
    if (gate != null) {
      nextSnapshotGate = null;
      snapshotStarted?.complete();
      await gate.future;
    }
    return Map<String, dynamic>.from(value);
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
    sendCalls += 1;
    return {
      'sessionId': id,
      'runId': 'run-1',
      'messageId': 'user-1',
      'state': 'queued',
    };
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
    final response = {
      ..._record(id),
      if (title != null) 'title': title,
      if (pinned != null) 'pinned': pinned,
      if (configuration != null) 'configuration': configuration,
      if (configuration != null)
        'configRevision': (expectedConfigRevision ?? 5) + 1,
      'revision': 6,
    };
    updateStarted?.complete();
    await updateGate?.future;
    return Map<String, dynamic>.from(response);
  }
}

Map<String, Object?> _configuration({String workMode = 'onDemand'}) => {
  'members': ['designer'],
  'roles': <String>[],
  'capabilities': ['image'],
  'memberCapabilities': {
    'designer': ['image'],
  },
  'memberNames': <String, String>{'designer': 'Harness assistant'},
  'memberInstructions': <String, String>{},
  'memberAvatars': <String, String>{},
  'memberColors': <String, int>{},
  'workMode': workMode,
  'activeMemberId': 'designer',
  'direction': '',
  'positioning': '',
  'roleProfiles': <String, Object?>{},
};

Map<String, Object?> _record(String id) => {
  'id': id,
  'title': 'Session $id',
  'kind': 'conversation',
  'configuration': _configuration(),
  'configurationStatus': 'configured',
  'configRevision': 5,
  'revision': 5,
};

Map<String, Object?> _snapshot(
  String id, {
  List<Map<String, Object?>> messages = const [],
  List<Map<String, Object?>> runs = const [],
  List<Map<String, Object?>> mediaJobs = const [],
  List<Map<String, Object?>> assets = const [],
  Map<String, Object?>? configuration,
  int configRevision = 5,
  int serverRevision = 5,
  int lastSeq = 0,
}) => {
  'session': {
    ..._record(id),
    if (configuration != null) 'configuration': configuration,
    'configRevision': configRevision,
    'revision': serverRevision,
  },
  'lastSeq': lastSeq,
  'messages': messages,
  'runs': runs,
  'mediaJobs': mediaJobs,
  'assets': assets,
};

Map<String, Object?> _message(String id, {List<String> assetIds = const []}) =>
    {
      'id': id,
      'role': 'assistant',
      'text': '图片已生成',
      'status': 'completed',
      'assetIds': assetIds,
    };

Map<String, Object?> _run(String state, {required int configRevision}) => {
  'id': 'run-1',
  'state': state,
  'configRevision': configRevision,
};

Map<String, Object?> _job(
  String state, {
  String operation = 'image',
  List<String> assetIds = const [],
  String ingestionState = '',
}) => {
  'jobId': 'job-1',
  'state': state,
  'operation': operation,
  'model': 'image-model',
  'runId': 'run-1',
  'memberId': 'designer',
  'configRevision': 5,
  if (assetIds.isNotEmpty) 'assetIds': assetIds,
  if (ingestionState.isNotEmpty) 'ingestionState': ingestionState,
};

Map<String, Object?> _asset(
  String id,
  String sessionId, {
  String kind = 'image',
  double durationSeconds = 0,
  bool hasAudio = false,
  String posterUrl = '',
}) => {
  'id': id,
  'title': 'Owned image $id',
  'kind': kind,
  'sessionId': sessionId,
  'jobId': 'job-1',
  'runId': 'run-1',
  'memberId': 'designer',
  'configRevision': 5,
  'mimeType': kind == 'video' ? 'video/mp4' : 'image/png',
  'sha256': 'hash-$id',
  'sizeBytes': 128,
  'width': 32,
  'height': 32,
  if (kind == 'video') 'durationSeconds': durationSeconds,
  if (kind == 'video') 'hasAudio': hasAudio,
  if (posterUrl.isNotEmpty) 'posterUrl': posterUrl,
  'createdAt': '2026-10-23T00:00:00.000Z',
  'contentUrl': '/api_agent/v2/assets/$id/content',
};
