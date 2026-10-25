import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

DemoSession _session({
  String id = 'session-1',
  List<String> roles = const ['alice', 'er'],
  List<String>? capabilities,
}) => DemoSession(
  id: id,
  title: 'Context session',
  kind: DemoSessionKind.conversation,
  members: const ['popi'],
  roles: roles,
  messages: const [],
  memberNames: const {'popi': 'Context session'},
  capabilities: capabilities ?? DemoSession.defaultCapabilities,
);

Future<PreferencesStorage> _storage() async {
  SharedPreferences.setMockInitialValues({});
  return PreferencesStorage(await SharedPreferences.getInstance());
}

void main() {
  group('context models', () {
    test('sessions default legacy capability data to the full six', () {
      final defaults = _session();
      expect(defaults.capabilities, DemoSession.defaultCapabilities);
      expect(defaults.capabilities, hasLength(6));

      final legacyJson = defaults.toJson()..remove('capabilities');
      expect(
        DemoSession.fromJson(legacyJson).capabilities,
        DemoSession.defaultCapabilities,
      );

      final manual = _session(capabilities: const ['image', 'video']);
      expect(DemoSession.fromJson(manual.toJson()).capabilities, const [
        'image',
        'video',
      ]);
    });

    test('role references round trip and can define a ready persona', () {
      const profile = DemoRoleProfile(
        name: '爱丽丝',
        revision: 'rev-2',
        referenceAssetIds: ['asset-1'],
        referenceImageUrls: ['https://example.test/alice.png'],
      );

      final restored = DemoRoleProfile.fromJson(profile.toJson());
      expect(restored.referenceAssetIds, ['asset-1']);
      expect(restored.referenceImageUrls, ['https://example.test/alice.png']);
      expect(restored.instructions, isEmpty);
      expect(restored.isReady, isTrue);

      final cleared = restored.copyWith(
        referenceAssetIds: const [],
        referenceImageUrls: const [],
      );
      expect(cleared.referenceAssetIds, isEmpty);
      expect(cleared.referenceImageUrls, isEmpty);
      expect(cleared.isReady, isFalse);
      expect(cleared.toJson()['referenceAssetIds'], isEmpty);
      expect(cleared.toJson()['referenceImageUrls'], isEmpty);
    });

    test('account preferences round trip and clear without stale values', () {
      final configured = _session().copyWith(
        direction: '治愈系图文和短视频',
        positioning: '陪伴年轻创作者',
        accountPreferences: const {
          'feeling': '温暖',
          'format': '图文和短视频',
          'audience': '年轻创作者',
        },
      );

      final restored = DemoSession.fromJson(configured.toJson());
      expect(restored.direction, '治愈系图文和短视频');
      expect(restored.positioning, '陪伴年轻创作者');
      expect(restored.accountPreferences, configured.accountPreferences);

      final cleared = restored.copyWith(
        direction: '',
        positioning: '',
        accountPreferences: const {},
      );
      final clearedJson = cleared.toJson();
      expect(clearedJson['accountPreferences'], isEmpty);
      expect(DemoSession.fromJson(clearedJson).accountPreferences, isEmpty);
    });

    test(
      'offline repository persists and clears account preferences',
      () async {
        final storage = await _storage();
        final repository = DemoRepository(storage)..restore();
        addTearDown(repository.dispose);

        await repository.updateSession(
          'alice',
          (session) => session.copyWith(
            direction: '校园治愈故事',
            positioning: '青春陪伴账号',
            accountPreferences: const {
              'feeling': '温暖',
              'format': '图文',
              'audience': '学生',
            },
          ),
        );
        final restored = DemoRepository(storage)..restore();
        addTearDown(restored.dispose);
        expect(restored.session('alice').direction, '校园治愈故事');
        expect(restored.session('alice').positioning, '青春陪伴账号');
        expect(restored.session('alice').accountPreferences['format'], '图文');

        await restored.updateSession(
          'alice',
          (session) => session.copyWith(
            direction: '',
            positioning: '',
            accountPreferences: const {},
          ),
        );
        final cleared = DemoRepository(storage)..restore();
        addTearDown(cleared.dispose);
        expect(cleared.session('alice').direction, isEmpty);
        expect(cleared.session('alice').positioning, isEmpty);
        expect(cleared.session('alice').accountPreferences, isEmpty);
      },
    );
  });

  group('DSH capability catalog', () {
    test('parses the real catalog without inventing Skill or MCP entries', () {
      final catalog = DemoCapabilityCatalog.fromResponse({
        'catalog': {
          'tools': [
            {
              'id': 'media_generate',
              'name': '生成媒体',
              'description': 'DSH tool',
              'source': 'dsh',
              'available': true,
            },
          ],
          'skills': <Object?>[],
          'mcp': <Object?>[],
        },
      });

      expect(catalog.tools, hasLength(1));
      expect(catalog.tools.single.id, 'media_generate');
      expect(catalog.tools.single.available, isTrue);
      expect(catalog.skills, isEmpty);
      expect(catalog.mcp, isEmpty);
      expect(catalog.isDemo, isFalse);
    });

    test('keeps binding, grant, and runtime availability independent', () {
      final catalog = DemoCapabilityCatalog.fromResponse({
        'catalog': {
          'tools': [
            {
              'id': 'approval-required',
              'name': 'Approval required',
              'bound': true,
              'granted': false,
              'available': false,
            },
            {
              'id': 'service-not-ready',
              'name': 'Service not ready',
              'bound': true,
              'granted': true,
              'available': false,
            },
          ],
          'skills': <Object?>[],
          'mcp': <Object?>[],
        },
      });

      final approvalRequired = catalog.tools.first;
      expect(approvalRequired.bound, isTrue);
      expect(approvalRequired.granted, isFalse);
      expect(approvalRequired.available, isFalse);

      final serviceNotReady = catalog.tools.last;
      expect(serviceNotReady.bound, isTrue);
      expect(serviceNotReady.granted, isTrue);
      expect(serviceNotReady.available, isFalse);
    });

    test(
      'legacy fallback exposes only tools explicitly declared by server',
      () {
        final catalog = DemoCapabilityCatalog.fromResponse({
          'web': {
            'configured': true,
            'dshToolsBound': true,
            'tools': ['web_search'],
          },
          'multimodal': {
            'state': 'ready',
            'dshToolsBound': false,
            'tools': ['media_generate'],
          },
        });

        expect(catalog.tools.map((item) => item.id), [
          'web_search',
          'media_generate',
        ]);
        expect(catalog.tools.map((item) => item.available), [true, false]);
        expect(catalog.skills, isEmpty);
        expect(catalog.mcp, isEmpty);
      },
    );

    test('offline demo catalog has no implied runtime bindings', () {
      expect(DemoCapabilityCatalog.offline.isDemo, isTrue);
      expect(DemoCapabilityCatalog.offline.tools, isEmpty);
      expect(DemoCapabilityCatalog.offline.skills, isEmpty);
      expect(DemoCapabilityCatalog.offline.mcp, isEmpty);
    });
  });

  group('Agent network context contracts', () {
    late Dio dio;
    late NetworkAgentApi api;

    setUp(() {
      dio = Dio();
      api = NetworkAgentApi(dio);
    });
    tearDown(() => dio.close(force: true));

    test(
      'capability catalog supports global and session-scoped requests',
      () async {
        var calls = 0;
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              expect(options.method, 'GET');
              expect(options.path, '/api_agent/v2/capabilities');
              expect(
                options.queryParameters,
                calls++ == 0 ? isEmpty : {'sessionId': 'session-1'},
              );
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'catalog': {
                      'tools': <Object?>[],
                      'skills': <Object?>[],
                      'mcp': <Object?>[],
                    },
                  },
                ),
              );
            },
          ),
        );

        expect((await api.harnessCapabilities())['catalog'], isA<Map>());
        expect(
          (await api.harnessCapabilities(sessionId: 'session-1'))['catalog'],
          isA<Map>(),
        );
        expect(calls, 2);
      },
    );

    test('message payload includes linked context role IDs', () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.method, 'POST');
            expect(options.path, '/api_agent/v2/sessions/session-1/messages');
            expect(options.data, {
              'clientRequestId': 'request-1',
              'text': '让 @爱丽丝 出现在画面中',
              'contextRoleIds': ['alice'],
            });
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 202,
                data: {'runId': 'run-1', 'state': 'queued'},
              ),
            );
          },
        ),
      );

      await api.sendSessionMessage(
        'session-1',
        clientRequestId: 'request-1',
        text: '让 @爱丽丝 出现在画面中',
        contextRoleIds: const ['alice'],
      );
    });
  });

  test(
    'repository rejects invalid role context before network and forwards valid IDs',
    () async {
      final storage = await _storage();
      await storage.setString(
        DemoRepository.harnessStorageKey,
        jsonEncode({
          'sessions': [_session().toJson()],
          'assets': <Object?>[],
        }),
      );
      final dio = Dio();
      addTearDown(() => dio.close(force: true));
      final requests = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
              ),
            );
          },
        ),
      );
      final repository = DemoRepository.harness(
        storage,
        NetworkAgentApi(dio),
        maxPollAttempts: 0,
      )..restore();
      addTearDown(repository.dispose);

      await expectLater(
        repository.sendHarnessMessage(
          'session-1',
          clientRequestId: 'unknown-role',
          text: 'Hello',
          contextRoleIds: const ['unknown-role'],
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.sendHarnessMessage(
          'session-1',
          clientRequestId: 'unlinked-role',
          text: 'Hello',
          contextRoleIds: const ['hua'],
        ),
        throwsArgumentError,
      );
      await expectLater(
        repository.sendHarnessMessage(
          'session-1',
          clientRequestId: 'duplicate-role',
          text: 'Hello',
          contextRoleIds: const ['alice', 'alice'],
        ),
        throwsArgumentError,
      );
      expect(requests, isEmpty);

      await expectLater(
        repository.sendHarnessMessage(
          'session-1',
          clientRequestId: 'valid-role',
          text: 'Use both references',
          contextRoleIds: const ['alice', 'er'],
        ),
        throwsA(isA<DioException>()),
      );
      expect(requests, hasLength(1));
      expect(requests.single.data, {
        'clientRequestId': 'valid-role',
        'text': 'Use both references',
        'contextRoleIds': ['alice', 'er'],
      });
    },
  );
}
