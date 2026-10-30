import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/features/ip_guide/data/ip_guide_repository.dart';
import 'package:popi_ai_app/features/ip_guide/domain/ip_guide_draft.dart';

import 'support/ip_guide_fixtures.dart';

void main() {
  late MemoryGuideStorage storage;
  late FixtureIpGuideAgentApi agent;
  late IpGuideRepository repository;
  const profile = {
    'contentDirections': ['校园', '亲情'],
    'audienceFeelings': ['治愈'],
    'presentationFormats': ['2D 动画'],
    'targetAudience': ['学生'],
  };
  const configuration = {
    'members': ['popi'],
    'capabilities': [
      'character',
      'script',
      'image',
      'video',
      'audio',
      'vision',
    ],
    'direction': '校园 x 亲情',
    'accountPreferences': {
      'feeling': '治愈',
      'format': '2D 动画',
      'audience': '学生',
    },
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = MemoryGuideStorage(await SharedPreferences.getInstance());
    agent = FixtureIpGuideAgentApi();
    repository = IpGuideRepository(storage, agent, userId: '1');
  });

  test(
    'draft restores ordered presets and custom text, isolated by user',
    () async {
      expect(repository.load(), isNull);
      final draft = IpGuideDraft()
        ..step = 3
        ..nickname = '校园故事';
      final selection = IpGuideSelection<String>(combineCustom: true);
      selection.toggle('校园', maxSelections: 20);
      selection.toggle('亲情', maxSelections: 20);
      selection.customText = '城市生活';
      draft.preferences['contentDirections'] = selection;
      await repository.save(draft);
      final restored = IpGuideRepository(storage, agent, userId: '1').load()!;
      expect(restored.step, 3);
      expect(restored.nickname, '校园故事');
      expect(restored.preferences['contentDirections']!.values, ['校园', '亲情']);
      expect(restored.preferences['contentDirections']!.customText, '城市生活');
      expect(IpGuideRepository(storage, agent, userId: '2').load(), isNull);
      await repository.clear();
      expect(repository.load(), isNull);
    },
  );

  test(
    'clear follows queued autosaves and failed writes can recover',
    () async {
      final draft = IpGuideDraft();
      final first = repository.save(draft);
      draft.nickname = '第二份';
      final second = repository.save(draft);
      await Future.wait([first, second]);
      expect(storage.values.length, 1);
      expect(repository.load()!.nickname, '第二份');
      storage.failWrites = true;
      await expectLater(repository.save(draft), throwsStateError);
      storage.failWrites = false;
      await Future.wait([repository.save(draft), repository.clear()]);
      expect(repository.load(), isNull);
    },
  );

  test('malformed and unsupported drafts are ignored', () {
    for (final raw in [
      '{',
      '[]',
      '{"version":2}',
      '{"version":1,"step":"bad"}',
    ]) {
      storage.values['ip_guide_draft_v1:1'] = raw;
      expect(repository.load(), isNull);
    }
  });

  test(
    'legacy account request IDs are not reused for a different session payload',
    () async {
      storage.values['ip_guide_draft_v1:1'] = jsonEncode({
        'version': 1,
        'nickname': '旧草稿',
        'step': 4,
        'creationRequestId': 'old-account-request',
        'sessionRequestId': 'old-session-request',
        'accountId': 'old-account',
        'sessionId': 'old-session',
      });
      final draft = repository.load()!;
      expect(draft.nickname, '旧草稿');
      expect(draft.submitted, isFalse);
      await repository.create(draft, profile);
      expect(
        agent.requests.single['clientRequestId'],
        isNot('old-session-request'),
      );
      expect(agent.requests.single.containsKey('accountId'), isFalse);
    },
  );

  test(
    'reads the Agent catalog and preserves server validation limits',
    () async {
      final steps = await repository.preferenceOptions();
      expect(agent.preferenceRequests, 1);
      expect(steps.map((step) => step.key), [
        'contentDirections',
        'audienceFeelings',
        'presentationFormats',
        'targetAudience',
      ]);
      expect(steps.first.options.first.description, '来自接口的选项描述');
      expect(steps.first.maxSelections, 2);
      expect(steps.last.maxNameBytes, 2000);
      agent.preferenceCatalog['schemaVersion'] = 2;
      await expectLater(repository.preferenceOptions(), throwsFormatException);
    },
  );

  test('creates only a project session with text preferences', () async {
    final draft = IpGuideDraft()..nickname = ' 校园故事 ';
    expect(await repository.create(draft, profile), 'created-session');
    expect(agent.requests.single, {
      'clientRequestId': draft.sessionRequestId,
      'title': '校园故事',
      'kind': 'project',
      'configuration': configuration,
    });
    expect(draft.sessionId, 'created-session');
    expect(repository.load(), isNull);
  });

  test(
    'optional empty preferences submit empty text without legacy extra fields',
    () async {
      await repository.create(IpGuideDraft()..nickname = '新会话', {});
      final config = agent.requests.single['configuration'] as Map;
      expect(config['direction'], '');
      expect(config['accountPreferences'], {
        'feeling': '',
        'format': '',
        'audience': '',
      });
      expect(config.containsKey('creativeConstraints'), isFalse);
    },
  );

  for (final failure in ['network', 'pending']) {
    test(
      '$failure keeps the frozen request across restart and retries',
      () async {
        final draft = IpGuideDraft()..nickname = '校园故事';
        agent.fail = failure == 'network';
        agent.bindingStatus = failure == 'pending' ? 'pending' : 'ready';
        await expectLater(repository.create(draft, profile), throwsA(anything));
        final resumedRepository = IpGuideRepository(
          storage,
          agent,
          userId: '1',
        );
        final resumed = resumedRepository.load()!;
        expect(resumed.submitted, isTrue);
        expect(resumed.step, 5);
        expect(resumed.sessionId, isNull);
        resumed.nickname = 'Changed title';
        agent.fail = false;
        agent.bindingStatus = 'ready';
        await resumedRepository.create(resumed, {});
        expect(agent.requests.first, agent.requests.last);
        expect(resumedRepository.load(), isNull);
      },
    );
  }

  test(
    'clear failure retains the created session without sending again',
    () async {
      storage.failRemoves = true;
      await expectLater(
        repository.create(IpGuideDraft()..nickname = '校园故事', profile),
        throwsStateError,
      );
      final restored = repository.load()!;
      expect(restored.sessionId, 'created-session');
      storage.failRemoves = false;
      await repository.create(restored, {});
      expect(agent.requests, hasLength(1));
      expect(repository.load(), isNull);
    },
  );

  test(
    'validates the UTF-16 text limit and title before freezing a request',
    () async {
      for (final draft in [
        IpGuideDraft(),
        IpGuideDraft()..nickname = List.filled(61, '😀').join(),
      ]) {
        await expectLater(
          repository.create(draft, profile),
          throwsFormatException,
        );
        expect(draft.submitted, isFalse);
      }
      final draft = IpGuideDraft()..nickname = '标题';
      await expectLater(
        repository.create(draft, {
          'targetAudience': [List.filled(2001, '😀').join()],
        }),
        throwsFormatException,
      );
      expect(draft.submitted, isFalse);
      await repository.create(draft, {
        'targetAudience': [List.filled(2000, '😀').join()],
      });
      expect(agent.requests, hasLength(1));
    },
  );

  test('disposal during creation keeps the unfinished draft', () async {
    final pending = Completer<void>();
    agent.wait = pending.future;
    final creation = repository.create(
      IpGuideDraft()..nickname = '校园故事',
      profile,
    );
    final result = expectLater(creation, throwsA(isA<DioException>()));
    while (agent.requests.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    repository.dispose();
    pending.complete();
    await result;
    expect(repository.load()!.sessionId, isNull);
    expect(repository.load()!.submitted, isTrue);
  });

  test(
    'HTTP contract reads direct JSON and sends only the documented session fields',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: options.method == 'GET' ? 200 : 201,
                data: options.method == 'GET'
                    ? agent.preferenceCatalog
                    : {
                        'id': 'session-1',
                        'title': '校园故事',
                        'kind': 'project',
                        'revision': 1,
                        'createdAt': '2026-10-30T08:00:00.000Z',
                        'updatedAt': '2026-10-30T08:00:00.000Z',
                        'archived': false,
                        'pinned': false,
                        'bindingStatus': 'ready',
                        'configRevision': 1,
                        'configurationStatus': 'configured',
                        'configuration': configuration,
                      },
              ),
            );
          },
        ),
      );
      final realRepository = IpGuideRepository(
        storage,
        NetworkAgentApi(dio),
        userId: '1',
      );
      final token = CancelToken();
      await realRepository.preferenceOptions(cancelToken: token);
      expect(requests.first.path, '/api_agent/v2/preference-options');
      expect(requests.first.method, 'GET');
      expect(requests.first.queryParameters, isEmpty);
      expect(requests.first.data, isNull);
      expect(requests.first.cancelToken, same(token));
      final draft = IpGuideDraft()..nickname = '校园故事';
      expect(await realRepository.create(draft, profile), 'session-1');
      expect(requests.last.path, '/api_agent/v2/sessions');
      expect(requests.last.method, 'POST');
      expect(requests.last.contentType, 'application/json');
      expect(requests.last.data, {
        'clientRequestId': draft.sessionRequestId,
        'title': '校园故事',
        'kind': 'project',
        'configuration': configuration,
      });
      expect(requests, hasLength(2));
    },
  );
}
