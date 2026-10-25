import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/agent_api_exception.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/data/demo_website_character_catalog.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late PreferencesStorage storage;
  late Dio dio;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = PreferencesStorage(await SharedPreferences.getInstance());
    await DemoRepository.prepareHarnessStorage(storage);
    dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3084'));
  });

  tearDown(() => dio.close(force: true));

  test('configuration and role metadata survive local JSON round-trip', () {
    const session = DemoSession(
      id: 's1',
      title: 'Configured',
      kind: DemoSessionKind.project,
      members: ['designer', 'popi'],
      roles: ['antarctic'],
      messages: [],
      capabilities: ['image', 'vision'],
      memberCapabilities: {
        'designer': ['image'],
        'popi': ['vision'],
      },
      activeMemberId: 'designer',
      roleProfiles: {
        'antarctic': DemoRoleProfile(
          name: '南极女孩',
          instructions: '保持服装和脸部一致',
          revision: 'role-v1',
        ),
      },
      configRevision: 4,
      configurationStatus: 'configured',
      serverRevision: 8,
      lastSeq: 9,
      mediaJobs: [
        DemoMediaJob(
          jobId: 'job-1',
          state: 'pending',
          operation: 'image',
          model: 'image-model',
          runId: 'run-1',
          memberId: 'designer',
          configRevision: 4,
        ),
      ],
    );

    final restored = DemoSession.fromJson(session.toJson());
    expect(restored.configRevision, 4);
    expect(restored.configurationStatus, 'configured');
    expect(restored.serverRevision, 8);
    expect(restored.lastSeq, 9);
    expect(restored.activeMemberId, 'designer');
    expect(restored.roleProfiles['antarctic']?.revision, 'role-v1');
    expect(restored.rolesReady, isTrue);
    expect(restored.mediaJobs.single.jobId, 'job-1');
    expect(const DemoRoleProfile(name: '只有名字').isReady, isFalse);
    expect(
      const DemoRoleProfile(instructions: '角色约束', revision: 'role-v2').isReady,
      isTrue,
    );
    expect(
      const DemoMediaJob(
        jobId: 'processing',
        state: 'processing',
        operation: 'image',
        model: 'image-model',
        runId: 'run-2',
      ).isPending,
      isTrue,
    );
    expect(
      const DemoMediaJob(
        jobId: 'unknown',
        state: 'unknown',
        operation: 'image',
        model: 'image-model',
        runId: 'run-3',
        ingestionState: 'pending',
      ).isPending,
      isFalse,
    );
  });

  test('new Harness session sends selected-member configuration', () async {
    final api = _ConfigurationApi(dio);
    final repository = DemoRepository.harness(storage, api)..restore();
    addTearDown(repository.dispose);

    await repository.createSession(
      'Two Bots',
      DemoSessionKind.project,
      members: const ['designer', 'popi'],
    );

    final configuration = api.lastCreatedConfiguration!;
    expect(configuration['members'], ['designer', 'popi']);
    expect(configuration['activeMemberId'], 'designer');
    expect((configuration['memberCapabilities'] as Map).keys, [
      'designer',
      'popi',
    ]);
    expect(configuration['memberNames'], isEmpty);
    expect(configuration['memberAvatars'], isEmpty);
    expect(repository.sessions.single.configRevision, 1);
    expect(repository.sessions.single.configurationStatus, 'configured');
  });

  test(
    'member capability update expands the global capability union',
    () async {
      final api = _ConfigurationApi(dio)
        ..record = _configuredRecord(
          configuration: _configuration(),
          configRevision: 2,
        );
      final repository = DemoRepository.harness(storage, api)..restore();
      addTearDown(repository.dispose);
      await repository.refreshSessions();

      await repository.updateSession(
        's1',
        (session) => session.copyWith(
          memberCapabilities: const {
            'popi': ['image', 'video'],
          },
        ),
      );

      final saved = api.lastUpdatedConfiguration!;
      expect(saved['capabilities'], containsAll(['image', 'video']));
      expect(saved['memberCapabilities'], {
        'popi': ['image', 'video'],
      });
      expect(api.lastExpectedConfigRevision, 2);
    },
  );

  test('website character profile is sent as fixed server context', () async {
    final api = _ConfigurationApi(dio)
      ..record = _configuredRecord(
        configuration: _configuration(),
        configRevision: 2,
      );
    final repository = DemoRepository.harness(storage, api)..restore();
    addTearDown(repository.dispose);
    await repository.refreshSessions();
    const roleId = 'popi-character-653';
    final source = DemoWebsiteCharacterCatalog.profile(roleId)!;

    await repository.updateSession(
      's1',
      (session) => session.copyWith(
        roles: const [roleId],
        roleProfiles: {roleId: source},
      ),
    );

    final saved = api.lastUpdatedConfiguration!;
    expect(saved['roles'], [roleId]);
    expect((saved['roleProfiles'] as Map)[roleId], source.toJson());
    expect(api.lastExpectedConfigRevision, 2);
    expect(repository.session('s1').members, ['popi']);
  });

  test(
    'legacy cached configuration migrates once from revision zero',
    () async {
      const cached = DemoSession(
        id: 's1',
        title: 'Cached',
        kind: DemoSessionKind.conversation,
        members: ['popi', 'designer', 'director'],
        roles: ['alice', 'er'],
        messages: [],
        capabilities: ['character', 'script', 'image'],
        memberCapabilities: {
          'popi': ['script', 'image'],
        },
        activeMemberId: 'popi',
        workMode: 'manual',
        pinned: true,
      );
      await storage.setString(
        DemoRepository.harnessStorageKey,
        jsonEncode({
          'sessions': [cached.toJson()],
          'assets': <Object?>[],
        }),
      );
      final api = _ConfigurationApi(dio)..record = _legacyRecord();
      final repository = DemoRepository.harness(storage, api)..restore();
      addTearDown(repository.dispose);

      await repository.refreshSessions();

      expect(api.updateCalls, 1);
      expect(api.lastExpectedConfigRevision, 0);
      expect(api.lastUpdatedConfiguration?['members'], [
        'popi',
        'designer',
        'director',
      ]);
      expect(api.lastUpdatedConfiguration?['roles'], ['alice', 'er']);
      expect(api.lastUpdatedConfiguration?['memberCapabilities'], {
        'popi': ['script', 'image'],
        'designer': ['character', 'script', 'image'],
        'director': ['character', 'script', 'image'],
      });
      expect(api.lastUpdatedConfiguration?['workMode'], 'manual');
      expect(api.lastPinned, isTrue);
      expect(repository.session('s1').configurationStatus, 'configured');
      expect(repository.session('s1').configRevision, 1);
      expect(repository.session('s1').members, [
        'popi',
        'designer',
        'director',
      ]);
      expect(repository.session('s1').roles, ['alice', 'er']);
      expect(repository.session('s1').workMode, 'manual');
      expect(repository.session('s1').pinned, isTrue);

      await repository.refreshSessions();
      expect(api.updateCalls, 1);
    },
  );

  test('legacy server defaults migrate without a cached session', () async {
    final api = _ConfigurationApi(dio)..record = _legacyRecord();
    final repository = DemoRepository.harness(storage, api)..restore();
    addTearDown(repository.dispose);

    await repository.refreshSessions();

    expect(api.updateCalls, 1);
    expect(api.lastExpectedConfigRevision, 0);
    expect(api.lastPinned, isFalse);
    expect(api.lastUpdatedConfiguration, _standardDefaultConfiguration());
    expect(repository.session('s1').configurationStatus, 'configured');
    expect(repository.session('s1').configRevision, 1);
  });

  test(
    'config conflict adopts server metadata without committing draft',
    () async {
      final api = _ConfigurationApi(dio)
        ..record = _configuredRecord(
          configuration: _configuration(workMode: 'onDemand'),
          configRevision: 2,
        );
      final repository = DemoRepository.harness(storage, api)..restore();
      addTearDown(repository.dispose);
      await repository.refreshSessions();

      api
        ..conflictNext = true
        ..record = _configuredRecord(
          configuration: _configuration(workMode: 'automatic'),
          configRevision: 3,
        );
      await expectLater(
        repository.updateSession(
          's1',
          (session) => session.copyWith(workMode: 'manual'),
        ),
        throwsA(
          isA<AgentApiException>().having(
            (error) => error.code,
            'code',
            'config_conflict',
          ),
        ),
      );

      expect(repository.session('s1').workMode, 'automatic');
      expect(repository.session('s1').configRevision, 3);

      await repository.updateSession(
        's1',
        (session) => session.copyWith(workMode: 'manual'),
      );
      expect(api.lastExpectedConfigRevision, 3);
      expect(repository.session('s1').workMode, 'manual');
    },
  );

  test('owned content URL accepts only the Agent asset route', () {
    final api = NetworkAgentApi(dio);
    expect(
      api.resolveAssetContentUrl('/api_agent/v2/assets/image_1/content'),
      'http://127.0.0.1:3084/api_agent/v2/assets/image_1/content',
    );
    expect(
      () => api.resolveAssetContentUrl('https://provider.test/image.png'),
      throwsFormatException,
    );
    expect(
      () => api.resolveAssetContentUrl('/api_agent/v2/assets/../secret'),
      throwsFormatException,
    );
  });

  test('owned poster URL accepts only the Agent poster route', () {
    final api = NetworkAgentApi(dio);
    expect(
      api.resolveAssetPosterUrl('/api_agent/v2/assets/video_1/poster'),
      'http://127.0.0.1:3084/api_agent/v2/assets/video_1/poster',
    );
    expect(
      () => api.resolveAssetPosterUrl('/api_agent/v2/assets/video_1/content'),
      throwsFormatException,
    );
    expect(
      () => api.resolveAssetPosterUrl('https://provider.test/poster.png'),
      throwsFormatException,
    );
    expect(
      () => api.resolveAssetPosterUrl(
        '/api_agent/v2/assets/video_1/poster?token=secret',
      ),
      throwsFormatException,
    );
  });

  test(
    'configuration PATCH keeps revision and idempotency on the wire',
    () async {
      final requests = <Map<String, Object?>>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(Map<String, Object?>.from(options.data as Map));
            handler.resolve(
              Response(
                requestOptions: options,
                data: _configuredRecord(
                  configuration: _configuration(workMode: 'manual'),
                  configRevision: 8,
                ),
              ),
            );
          },
        ),
      );

      await NetworkAgentApi(dio).updateSession(
        's1',
        clientRequestId: 'request-1',
        configuration: _configuration(workMode: 'manual'),
        expectedConfigRevision: 7,
      );

      expect(requests.single, {
        'clientRequestId': 'request-1',
        'configuration': _configuration(workMode: 'manual'),
        'expectedConfigRevision': 7,
      });
    },
  );
}

class _ConfigurationApi extends NetworkAgentApi {
  _ConfigurationApi(super.dio);

  Map<String, Object?> record = _configuredRecord(
    configuration: _configuration(),
    configRevision: 1,
  );
  Map<String, Object?>? lastCreatedConfiguration;
  Map<String, Object?>? lastUpdatedConfiguration;
  int? lastExpectedConfigRevision;
  bool? lastPinned;
  int updateCalls = 0;
  bool conflictNext = false;

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
    'pageInfo': {'page': page, 'pageSize': pageSize, 'pageCount': 1},
  };

  @override
  Future<Map<String, dynamic>> sessionSnapshot(
    String id, {
    CancelToken? cancelToken,
  }) async => {
    'session': record,
    'messages': <Object?>[],
    'runs': <Object?>[],
    'assets': <Object?>[],
    'mediaJobs': <Object?>[],
  };

  @override
  Future<Map<String, dynamic>> createHarnessSession({
    required String clientRequestId,
    required String title,
    required String kind,
    Map<String, Object?>? configuration,
    CancelToken? cancelToken,
  }) async {
    lastCreatedConfiguration = configuration;
    record = _configuredRecord(
      title: title,
      kind: kind,
      configuration: configuration!,
      configRevision: 1,
    );
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
    updateCalls += 1;
    lastUpdatedConfiguration = configuration;
    lastExpectedConfigRevision = expectedConfigRevision;
    lastPinned = pinned;
    if (conflictNext) {
      conflictNext = false;
      throw const AgentApiException(
        code: 'config_conflict',
        statusCode: 409,
        message: 'Configuration changed',
      );
    }
    final revision = configuration == null
        ? (record['configRevision'] as int? ?? 0)
        : (expectedConfigRevision ?? 0) + 1;
    record = {
      ...record,
      if (title != null) 'title': title,
      if (pinned != null) 'pinned': pinned,
      if (configuration != null) 'configuration': configuration,
      if (configuration != null) 'configurationStatus': 'configured',
      'configRevision': revision,
    };
    return Map<String, dynamic>.from(record);
  }
}

Map<String, Object?> _configuration({String workMode = 'onDemand'}) => {
  'members': ['popi'],
  'roles': <String>[],
  'capabilities': ['image'],
  'memberCapabilities': {
    'popi': ['image'],
  },
  'memberNames': <String, String>{},
  'memberInstructions': <String, String>{},
  'memberAvatars': <String, String>{},
  'memberColors': <String, int>{},
  'workMode': workMode,
  'activeMemberId': 'popi',
  'direction': '',
  'positioning': '',
  'roleProfiles': <String, Object?>{},
};

Map<String, Object?> _standardDefaultConfiguration() => {
  'members': ['popi'],
  'roles': <String>[],
  'capabilities': DemoSession.defaultCapabilities,
  'memberCapabilities': {'popi': DemoSession.defaultCapabilities},
  'memberNames': <String, String>{},
  'memberInstructions': <String, String>{},
  'memberAvatars': <String, String>{},
  'memberColors': <String, int>{},
  'workMode': 'onDemand',
  'activeMemberId': 'popi',
  'direction': '',
  'positioning': '',
  'accountPreferences': <String, String>{},
  'roleProfiles': <String, Object?>{},
};

Map<String, Object?> _configuredRecord({
  String title = 'Server session',
  String kind = 'conversation',
  required Map<String, Object?> configuration,
  required int configRevision,
}) => {
  'id': 's1',
  'title': title,
  'kind': kind,
  'pinned': false,
  'configuration': configuration,
  'configurationStatus': 'configured',
  'configRevision': configRevision,
  'revision': configRevision,
};

Map<String, Object?> _legacyRecord() => {
  'id': 's1',
  'title': 'Legacy session',
  'kind': 'conversation',
  'configuration': _standardDefaultConfiguration(),
  'configurationStatus': 'legacy',
  'configRevision': 0,
  'revision': 1,
};
