import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/ip_guide/data/ip_guide_repository.dart';
import 'package:popi_ai_app/features/ip_guide/domain/ip_guide_draft.dart';

import 'support/ip_guide_fixtures.dart';

void main() {
  late MemoryGuideStorage storage;
  late FixtureIpGuideApi api;
  late IpGuideRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = MemoryGuideStorage(await SharedPreferences.getInstance());
    api = FixtureIpGuideApi();
    repository = IpGuideRepository(storage, api, userId: '1');
  });

  test(
    'starts without a draft and restores all fields with selection order',
    () async {
      expect(repository.load(), isNull);
      final draft = IpGuideDraft()
        ..step = 5
        ..presentation = IpPresentation.ink
        ..format = IpContentFormat.comicDrama
        ..customFormat = '音乐故事'
        ..nickname = '后来才懂';
      draft.directions.toggle(IpContentDirection.emotion);
      draft.directions.toggle(IpContentDirection.campus);
      draft.feelings.customText = '好奇而轻松';
      draft.audience.toggle(IpTargetAudience.workers);
      draft.audience.toggle(IpTargetAudience.students);
      await repository.save(draft);
      final restored = IpGuideRepository(storage, api, userId: '1').load()!;
      expect(restored.step, 5);
      expect(restored.directions.values, [
        IpContentDirection.emotion,
        IpContentDirection.campus,
      ]);
      expect(restored.feelings.customText, '好奇而轻松');
      expect(restored.audience.values, [
        IpTargetAudience.workers,
        IpTargetAudience.students,
      ]);
      expect(restored.presentation, IpPresentation.ink);
      expect(restored.format, IpContentFormat.comicDrama);
      expect(restored.customFormat, '音乐故事');
      expect(restored.nickname, '后来才懂');
      expect(IpGuideRepository(storage, api, userId: '2').load(), isNull);
    },
  );

  test(
    'updates replace one draft and clear follows queued autosaves',
    () async {
      final draft = IpGuideDraft();
      final first = repository.save(draft);
      draft.nickname = '第二份';
      draft.step = 3;
      final second = repository.save(draft);
      await Future.wait([first, second]);
      expect(storage.values.length, 1);
      expect(repository.load()!.nickname, '第二份');
      final third = repository.save(draft);
      final cleared = repository.clear();
      await Future.wait([third, cleared]);
      expect(repository.load(), isNull);
    },
  );

  test('malformed or unsupported drafts are ignored', () {
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

  test('write failure is reported and the write queue can recover', () async {
    storage.failWrites = true;
    await expectLater(repository.save(IpGuideDraft()), throwsStateError);
    storage.failWrites = false;
    await repository.save(IpGuideDraft()..nickname = '恢复');
    expect(repository.load()!.nickname, '恢复');
  });

  test('account failure retains the same request across a restart', () async {
    final draft = IpGuideDraft()..nickname = '账号';
    api.failAccount = true;
    await expectLater(
      repository.create(draft, {'direction': '校园'}),
      throwsStateError,
    );
    final restored = IpGuideRepository(storage, api, userId: '1').load()!;
    expect(restored.submitted, isTrue);
    expect(restored.step, 5);
    api.failAccount = false;
    await repository.create(restored, {'direction': 'Changed locale'});
    expect(api.accountRequests[0], api.accountRequests[1]);
    expect(api.savedProfile, {'direction': '校园'});
    expect(repository.load(), isNull);
  });

  test(
    'profile failure resumes the existing account and clears only on success',
    () async {
      final draft = IpGuideDraft()..nickname = '账号';
      api.failProfile = true;
      await expectLater(
        repository.create(draft, {'targetAudience': '学生'}),
        throwsStateError,
      );
      expect(repository.load()!.accountId, 'created-account');
      expect(api.accountRequests, hasLength(1));
      api.failProfile = false;
      await repository.create(repository.load()!, {
        'targetAudience': 'students',
      });
      expect(api.accountRequests, hasLength(1));
      expect(api.profileRequests[0], api.profileRequests[1]);
      expect(api.savedProfile, {'targetAudience': '学生'});
      expect(repository.load(), isNull);
    },
  );

  test(
    'API sends creation and profile activation using the backend contract',
    () async {
      final dio = Dio();
      final requests = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'status': '0000',
                  'data': options.path.endsWith('profile-versions')
                      ? {'id': 'profile-1'}
                      : {'id': 'account-1', 'revision': 1},
                },
              ),
            );
          },
        ),
      );
      final network = NetworkApi(dio);
      expect(
        await network.createIpAccount(
          title: '账号',
          clientRequestId: 'create-id',
        ),
        ('account-1', 1),
      );
      await network.saveIpAccountProfile(
        'account-1',
        revision: 1,
        clientRequestId: 'profile-id',
        profile: {'contentDirection': '校园'},
      );
      expect(requests[0].method, 'POST');
      expect(requests[0].path, '/api_client/agent/v2/accounts');
      expect(requests[0].data, {
        'clientRequestId': 'create-id',
        'expectedRevision': 0,
        'title': '账号',
        'accountType': 'ip_character',
      });
      expect(
        requests[1].path,
        '/api_client/agent/v2/accounts/account-1/profile-versions',
      );
      expect(requests[1].data, {
        'clientRequestId': 'profile-id',
        'expectedRevision': 1,
        'profile': {'contentDirection': '校园'},
        'activate': true,
      });
    },
  );

  test('disposal prevents creation from a stale login', () async {
    final draft = IpGuideDraft()..nickname = '旧账号草稿';
    await repository.save(draft);
    repository.dispose();
    await expectLater(
      repository.create(draft, {}),
      throwsA(isA<DioException>()),
    );
    expect(api.accountRequests, isEmpty);
    expect(repository.load()!.nickname, '旧账号草稿');
  });

  test(
    'unknown enum choices are ignored and selection limits are retained',
    () {
      storage.values['ip_guide_draft_v1:1'] = jsonEncode({
        'version': 1,
        'directions': {
          'values': ['removed', 'campus', 'campus', 'emotion', 'growth'],
        },
      });
      expect(repository.load()!.directions.values, [
        IpContentDirection.campus,
        IpContentDirection.emotion,
      ]);
    },
  );
}
