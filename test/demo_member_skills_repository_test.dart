import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/agent_api_exception.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_controller.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PreferencesStorage storage;
  late Dio dio;
  late _SkillApi api;
  late DemoRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      DemoRepository.storageKey: '{"sessions":[],"assets":[]}',
      DemoRepository.harnessStorageKey: '{"sessions":[],"assets":[]}',
    });
    storage = PreferencesStorage(await SharedPreferences.getInstance());
    dio = Dio(BaseOptions(baseUrl: 'http://127.0.0.1:3084'));
    api = _SkillApi(dio);
    repository = DemoRepository.harness(
      storage,
      api,
      pollInterval: Duration.zero,
      maxPollAttempts: 0,
    )..restore();
  });
  tearDown(() {
    repository.dispose();
    dio.close(force: true);
  });

  test(
    'skill IDs have bounded syntax and every default Bot starts with no skills',
    () async {
      expect(isValidDemoSkillId(demoStyleFilmSkillId), isTrue);
      expect(isValidDemoSkillId(demoSeedanceReferenceRemixSkillId), isTrue);
      expect(isValidDemoSkillId('future-installed-skill'), isTrue);
      for (final id in [
        '',
        'invalid/skill',
        'UpperCase',
        'a--b',
        '-leading',
        'trailing-',
        'a' * 65,
      ]) {
        expect(isValidDemoSkillId(id), isFalse);
      }
      final local = DemoRepository(storage)..restore();
      addTearDown(local.dispose);
      final id = await local.createSession(
        'Default',
        DemoSessionKind.conversation,
      );
      expect(local.session(id).skillsFor('popi'), isEmpty);
      expect(
        () => local.setMemberSkillEnabled(
          id,
          memberId: 'popi',
          skillId: 'invalid/skill',
          enabled: true,
        ),
        throwsArgumentError,
      );
      expect(
        () => local.setMemberSkillEnabled(
          id,
          memberId: 'unknown',
          skillId: demoSeedanceReferenceRemixSkillId,
          enabled: true,
        ),
        throwsArgumentError,
      );
      await expectLater(
        local.createSession(
          'Unknown',
          DemoSessionKind.conversation,
          assistant: const DemoAssistantProfile(
            id: 'draft',
            memberId: 'popi',
            skillIds: ['invalid/skill'],
          ),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'installed catalog status stays separate from per-Bot grant and legacy responses remain compatible',
    () {
      final catalog = DemoCapabilityCatalog.fromResponse({
        'catalog': {
          'skills': [
            {
              'id': demoSeedanceReferenceRemixSkillId,
              'name': '参考案例仿写短片',
              'source': 'installed',
              'installed': true,
              'bound': true,
              'granted': false,
              'available': false,
            },
            {
              'id': demoStyleFilmSkillId,
              'name': 'Style film',
              'bound': true,
              'granted': true,
              'available': true,
            },
          ],
        },
      });
      expect(catalog.skills.first.installed, isTrue);
      expect(catalog.skills.first.bound, isTrue);
      expect(catalog.skills.first.granted, isFalse);
      expect(catalog.skills.first.available, isFalse);
      expect(catalog.skills.last.installed, isTrue);
      final missing = DemoRuntimeCapability.fromJson({
        'id': 'missing',
        'source': 'installed',
        'installed': false,
        'bound': false,
        'available': false,
      });
      expect(missing.installed, isFalse);
      expect(missing.bound, isFalse);
      final legacy = DemoRuntimeCapability.fromJson({
        'id': 'legacy',
        'available': true,
      });
      expect(legacy.installed, isTrue);
      expect(legacy.bound, isTrue);
      final installedButUnbound = DemoRuntimeCapability.fromJson({
        'id': 'unbound',
        'source': 'installed',
        'bound': false,
      });
      expect(installedButUnbound.installed, isTrue);
      expect(installedButUnbound.bound, isFalse);
    },
  );

  test(
    'toggle persists only selected member skills with config revision and preserves other grants and identity',
    () async {
      await repository.refreshSessions();
      expect(repository.session('s1').skillsFor('popi'), isEmpty);
      await repository.setMemberSkillEnabled(
        's1',
        memberId: 'popi',
        skillId: demoSeedanceReferenceRemixSkillId,
        enabled: true,
      );
      expect(api.lastExpectedRevision, 1);
      expect(api.lastConfiguration?['memberSkills'], {
        'popi': [demoSeedanceReferenceRemixSkillId],
        'writer': [demoStyleFilmSkillId],
      });
      expect(api.lastConfiguration?['memberBotIds'], {
        'popi': 'bot:popi-test',
        'writer': 'builtin:writer',
      });
      expect(
        api.lastConfiguration?['capabilities'],
        DemoSession.defaultCapabilities,
      );
      expect(
        (api.lastConfiguration?['memberInstructions'] as Map)['popi'],
        'Keep the original Bot instructions.',
      );
      expect(jsonEncode(api.lastConfiguration), isNot(contains('基于内置完整案例')));
      await repository.setMemberSkillEnabled(
        's1',
        memberId: 'popi',
        skillId: demoStyleFilmSkillId,
        enabled: true,
      );
      await repository.setMemberSkillEnabled(
        's1',
        memberId: 'popi',
        skillId: demoSeedanceReferenceRemixSkillId,
        enabled: false,
      );
      expect(repository.session('s1').skillsFor('popi'), [
        demoStyleFilmSkillId,
      ]);
      expect(repository.session('s1').skillsFor('writer'), [
        demoStyleFilmSkillId,
      ]);
      final restored = DemoRepository.harness(storage, api)..restore();
      addTearDown(restored.dispose);
      expect(restored.session('s1').skillsFor('popi'), [demoStyleFilmSkillId]);
      expect(restored.session('s1').botIdFor('popi'), 'bot:popi-test');
    },
  );

  test(
    'unchanged selections do not duplicate PATCH and failed saves do not enable the skill locally',
    () async {
      await repository.refreshSessions();
      api.failUpdate = true;
      await expectLater(
        repository.setMemberSkillEnabled(
          's1',
          memberId: 'popi',
          skillId: demoSeedanceReferenceRemixSkillId,
          enabled: true,
        ),
        throwsA(isA<DioException>()),
      );
      expect(repository.session('s1').skillsFor('popi'), isEmpty);
      api.failUpdate = false;
      await repository.setMemberSkillEnabled(
        's1',
        memberId: 'popi',
        skillId: demoSeedanceReferenceRemixSkillId,
        enabled: true,
      );
      expect(api.requestIds[0], api.requestIds[1]);
      await repository.setMemberSkillEnabled(
        's1',
        memberId: 'popi',
        skillId: demoSeedanceReferenceRemixSkillId,
        enabled: true,
      );
      expect(api.updateCalls, 2);
      expect(repository.session('s1').skillsFor('popi'), [
        demoSeedanceReferenceRemixSkillId,
      ]);
    },
  );

  test(
    'a revision conflict refreshes authoritative grants without dropping the film skill',
    () async {
      await repository.refreshSessions();
      api.configuration['memberSkills'] = {
        'popi': [demoStyleFilmSkillId],
        'writer': [demoStyleFilmSkillId],
      };
      api.conflictUpdate = true;
      await expectLater(
        repository.setMemberSkillEnabled(
          's1',
          memberId: 'popi',
          skillId: demoSeedanceReferenceRemixSkillId,
          enabled: true,
        ),
        throwsA(
          isA<AgentApiException>().having(
            (e) => e.code,
            'code',
            'config_conflict',
          ),
        ),
      );
      expect(repository.session('s1').skillsFor('popi'), [
        demoStyleFilmSkillId,
      ]);
      expect(repository.session('s1').botIdFor('popi'), 'bot:popi-test');
    },
  );

  test(
    'saved profiles round-trip and copy both grants into a fresh isolated session',
    () async {
      final local = DemoRepository(storage)..restore();
      addTearDown(local.dispose);
      const profile = DemoAssistantProfile(
        id: 'bot:reference-director',
        memberId: 'director',
        name: '案例导演',
        skillIds: [demoStyleFilmSkillId, demoSeedanceReferenceRemixSkillId],
      );
      expect(
        DemoAssistantProfile.fromJson(profile.toJson()).skillIds,
        profile.skillIds,
      );
      final id = await local.createSession(
        'Source',
        DemoSessionKind.conversation,
        assistant: profile,
      );
      final saved = local.assistantProfiles.singleWhere(
        (p) => p.id == profile.id,
      );
      final copy = await local.createSession(
        'Copy',
        DemoSessionKind.conversation,
        assistant: saved,
      );
      expect(local.session(copy).skillsFor('director'), profile.skillIds);
      expect(local.session(copy).botIdFor('director'), profile.id);
      expect(local.session(copy).messages, isEmpty);
      expect(local.session(copy).filmJobs, isEmpty);
      await local.setMemberSkillEnabled(
        id,
        memberId: 'director',
        skillId: demoSeedanceReferenceRemixSkillId,
        enabled: false,
      );
      expect(local.session(id).skillsFor('director'), [demoStyleFilmSkillId]);
      expect(local.session(copy).skillsFor('director'), profile.skillIds);
      final restored = DemoRepository(storage)..restore();
      addTearDown(restored.dispose);
      expect(restored.session(copy).skillsFor('director'), profile.skillIds);
    },
  );

  test(
    'ordinary instruction skill messages remain normal text and never acquire style film invocation',
    () async {
      api.configuration['memberSkills'] = {
        'popi': [demoSeedanceReferenceRemixSkillId],
        'writer': [demoStyleFilmSkillId],
      };
      await repository.refreshSessions();
      await repository.updateStyleFilmDraft(
        's1',
        'bot:popi-test',
        const DemoStyleFilmSelection(styleId: 'impasto'),
      );
      final controller = DemoChatController(repository, 's1');
      addTearDown(controller.dispose);
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(
        await controller.send(
          'Write from the installed reference case.',
          [],
          l,
          skillInvocation: const DemoStyleFilmInvocation(
            selection: DemoStyleFilmSelection(styleId: 'impasto'),
          ),
        ),
        isTrue,
      );
      expect(api.lastSentText, 'Write from the installed reference case.');
      expect(api.lastInvocation, isNull);
      expect(
        repository.styleFilmDraft('s1', 'bot:popi-test')?.styleId,
        'impasto',
      );
    },
  );

  test(
    'a future installed catalog skill uses the same toggle helper without a client registry',
    () async {
      await repository.refreshSessions();
      final catalog = await repository.loadCapabilityCatalog(sessionId: 's1');
      final installed = catalog.skills.singleWhere(
        (row) => row.id == 'future-case-skill',
      );
      expect(installed.installed, isTrue);
      expect(installed.bound, isTrue);
      await repository.setMemberSkillEnabled(
        's1',
        memberId: 'popi',
        skillId: installed.id,
        enabled: true,
      );
      expect(repository.session('s1').skillsFor('popi'), ['future-case-skill']);
      expect(api.lastConfiguration?['memberSkills'], {
        'popi': ['future-case-skill'],
        'writer': [demoStyleFilmSkillId],
      });
      expect(
        api.catalogCalls,
        1,
      ); // No implicit catalog discovery on each toggle.
      final restored = DemoRepository.harness(storage, api)..restore();
      addTearDown(restored.dispose);
      expect(restored.session('s1').skillsFor('popi'), ['future-case-skill']);
    },
  );

  test(
    'server rejection of an unregistered valid ID preserves grants and reaches both PATCH and POST',
    () async {
      await repository.refreshSessions();
      await expectLater(
        repository.setMemberSkillEnabled(
          's1',
          memberId: 'popi',
          skillId: 'not-installed',
          enabled: true,
        ),
        throwsA(
          isA<AgentApiException>().having(
            (error) => error.code,
            'code',
            'invalid_session_configuration',
          ),
        ),
      );
      expect(api.updateCalls, 1);
      expect(repository.session('s1').skillsFor('popi'), isEmpty);
      const profile = DemoAssistantProfile(
        id: 'draft:new',
        memberId: 'popi',
        name: 'Draft Bot',
        skillIds: ['not-installed'],
      );
      for (var i = 0; i < 2; i++) {
        await expectLater(
          repository.createSession(
            'Draft',
            DemoSessionKind.conversation,
            assistant: profile,
          ),
          throwsA(
            isA<AgentApiException>().having(
              (error) => error.code,
              'code',
              'invalid_session_configuration',
            ),
          ),
        );
      }
      expect(api.createRequestIds, hasLength(2));
      expect(api.createRequestIds[0], api.createRequestIds[1]);
      expect(repository.sessions, hasLength(1));
      expect(profile.skillIds, ['not-installed']);
    },
  );
}

class _SkillApi extends NetworkAgentApi {
  _SkillApi(super.dio);
  final configuration = <String, Object?>{
    'members': ['popi', 'writer'],
    'roles': <String>[],
    'activeMemberId': 'popi',
    'workMode': 'manual',
    'capabilities': DemoSession.defaultCapabilities,
    'memberCapabilities': {
      'popi': DemoSession.defaultCapabilities,
      'writer': DemoSession.defaultCapabilities,
    },
    'memberNames': {'popi': 'POPi'},
    'memberInstructions': {'popi': 'Keep the original Bot instructions.'},
    'memberBotIds': {'popi': 'bot:popi-test', 'writer': 'builtin:writer'},
    'memberSkills': {
      'popi': <String>[],
      'writer': [demoStyleFilmSkillId],
    },
  };
  int revision = 1, updateCalls = 0;
  bool failUpdate = false, conflictUpdate = false;
  int? lastExpectedRevision;
  Map<String, Object?>? lastConfiguration, lastInvocation;
  String? lastSentText;
  final requestIds = <String?>[];
  final createRequestIds = <String>[];
  int catalogCalls = 0;
  final allowedSkillIds = {
    demoStyleFilmSkillId,
    demoSeedanceReferenceRemixSkillId,
    'future-case-skill',
  };
  Map<String, dynamic> get record => {
    'id': 's1',
    'title': 'Skill chat',
    'kind': 'conversation',
    'configuration': configuration,
    'configurationStatus': 'configured',
    'configRevision': revision,
    'revision': revision,
  };
  @override
  Future<Map<String, dynamic>> sessionsPage({
    int page = 1,
    int pageSize = 20,
    bool archived = false,
    String? accountId,
    CancelToken? cancelToken,
  }) async => {
    'list': [record],
    'pageInfo': {'pageCount': 1},
  };
  @override
  Future<Map<String, dynamic>> assets({
    String? sessionId,
    CancelToken? cancelToken,
  }) async => {'list': <Object?>[]};

  @override
  Future<Map<String, dynamic>> harnessCapabilities({
    String? sessionId,
    CancelToken? cancelToken,
  }) async {
    catalogCalls++;
    return {
      'catalog': {
        'skills': [
          {
            'id': 'future-case-skill',
            'name': 'Future case',
            'source': 'installed',
            'installed': true,
            'bound': true,
            'granted': false,
            'available': false,
          },
        ],
      },
    };
  }

  void validateServerSkills(Map<String, Object?>? value) {
    final skills = value?['memberSkills'] as Map? ?? {};
    if (skills.values
        .expand((value) => (value as List).cast<String>())
        .any((id) => !allowedSkillIds.contains(id))) {
      throw const AgentApiException(
        code: 'invalid_session_configuration',
        statusCode: 400,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> createHarnessSession({
    required String clientRequestId,
    required String title,
    required String kind,
    Map<String, Object?>? configuration,
    CancelToken? cancelToken,
  }) async {
    createRequestIds.add(clientRequestId);
    validateServerSkills(configuration);
    return {
      ...record,
      'id': 'created-session',
      'title': title,
      'kind': kind,
      'configuration': configuration,
    };
  }

  @override
  Future<Map<String, dynamic>> sessionSnapshot(
    String id, {
    CancelToken? cancelToken,
  }) async => {
    'session': record,
    'lastSeq': revision,
    'messages': <Object?>[],
    'assets': <Object?>[],
    'runs': [
      {'id': 'run-1', 'state': 'completed'},
    ],
    'mediaJobs': <Object?>[],
    'filmJobs': <Object?>[],
  };
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
    requestIds.add(clientRequestId);
    lastExpectedRevision = expectedConfigRevision;
    lastConfiguration = configuration;
    validateServerSkills(configuration);
    if (failUpdate) {
      throw DioException(
        requestOptions: RequestOptions(path: '/session'),
        type: DioExceptionType.connectionError,
      );
    }
    if (conflictUpdate) {
      conflictUpdate = false;
      revision++;
      throw const AgentApiException(code: 'config_conflict', statusCode: 409);
    }
    if (configuration != null) {
      this.configuration
        ..clear()
        ..addAll(configuration);
      revision++;
    }
    return record;
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
    lastSentText = text;
    lastInvocation = skillInvocation;
    return {'runId': 'run-1', 'state': 'completed'};
  }
}
