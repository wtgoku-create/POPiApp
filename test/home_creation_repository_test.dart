import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/features/assets/domain/library_role.dart';
import 'package:popi_ai_app/features/role_guide/domain/home_creation.dart';

import 'support/home_creation_fixtures.dart';

void main() {
  test(
    'role edits follow Web home commands and leave library roles unchanged',
    () async {
      final fixture = HomeCreationFixture()..failRoleSaveOnce = true;
      final repository = fixture.repository;
      final home = await repository.open('101');
      final profile = {
        'title': 'Local character',
        'description': 'Local description',
        'contentTags': ['School'],
      };
      await expectLater(
        repository.saveRoleProfile(home, '1', profile),
        throwsA(isA<DioException>()),
      );
      final updated = await repository.saveRoleProfile(home, '1', profile);
      final writes = fixture.requests
          .where((request) => request.path.endsWith('/role-versions'))
          .toList();
      expect(writes, hasLength(2));
      expect(writes[0].data, writes[1].data);
      expect(writes.last.method, 'POST');
      expect(
        writes.last.path,
        '/api_client/agent/v2/creations/301/role-versions',
      );
      expect(writes.last.baseUrl, 'http://business.test');
      expect(writes.last.data['roleId'], 1);
      expect(writes.last.data['profile'], profile);
      expect(writes.last.data.containsKey('expectedRevision'), isFalse);
      expect(writes.last.data.containsKey('profileVersionId'), isFalse);
      expect(updated.cast.single.title, 'Local character');
      expect(updated.version, 2);
      expect(updated.selectedTopic, isNull);
      expect(fixture.role(1)['title'], 'Character 1');
      expect(fixture.requests.last.path, '/api_agent/v2/home/enter');
      expect(
        () => repository.saveRoleProfile(updated, '2', profile),
        throwsA(isA<ApiException>()),
      );
      final locked = HomeCreation.fromJson({
        ...fixture.snapshot(),
        'editable': false,
      });
      expect(
        () => repository.saveRoleProfile(locked, '1', profile),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test(
    'role entry, topics, cast and selection use separate Web transports',
    () async {
      final fixture = HomeCreationFixture();
      final repository = fixture.repository;
      var home = await repository.create([
        LibraryRole.fromJson(fixture.role(1)),
      ]);
      expect(home.cast.single.id, '1');
      home = await repository.recommend(home);
      expect(home.topics.single.title, 'Server story 1');
      home = await repository.selectTopic(home, home.topics.single);
      expect(home.selectedTopic!.id, 'topic-1');
      expect(home.version, 2);
      home = await repository.replaceCast(home, [
        LibraryRole.fromJson(fixture.role(2)),
      ]);
      expect(home.cast.single.id, '2');
      expect(home.selectedTopic, isNull);
      final agent = fixture.requests.where(
        (request) => request.path.startsWith('/api_agent'),
      );
      expect(
        agent.every((request) => request.baseUrl == 'http://agent.test'),
        isTrue,
      );
      final business = fixture.requests.where(
        (request) => request.path.startsWith('/api_client'),
      );
      expect(
        business.every((request) => request.baseUrl == 'http://business.test'),
        isTrue,
      );
      final topic = business.firstWhere(
        (request) => request.path.endsWith('/topic'),
      );
      expect(topic.method, 'PUT');
      expect(topic.data['expectedRevision'], 1);
      final cast = business.firstWhere(
        (request) => request.path.endsWith('/revisions'),
      );
      expect(cast.data['cast'], [
        {'roleId': 2, 'profileVersionId': '21'},
      ]);
      expect(cast.data['topicId'], isNull);
      expect(
        fixture.requests.any((request) => request.path.endsWith('/messages')),
        isFalse,
      );
    },
  );

  test(
    'lost entry and generation responses retain complete idempotent input',
    () async {
      final fixture = HomeCreationFixture()..failEntryOnce = true;
      final repository = fixture.repository;
      final roles = [LibraryRole.fromJson(fixture.role(1))];
      await expectLater(repository.create(roles), throwsA(isA<DioException>()));
      final home = await repository.create(roles);
      final entries = fixture.requests
          .where((request) => request.path.endsWith('/home/enter'))
          .toList();
      expect(entries[0].data, entries[1].data);
      fixture.failGenerateOnce = true;
      const config = HomeConfig(modelId: '501', params: {'duration': 15});
      await expectLater(
        repository.generate(home, config),
        throwsA(isA<DioException>()),
      );
      final task = await repository.generate(home, config);
      expect(task.id, fixture.task!['id']);
      final submissions = fixture.requests
          .where((request) => request.path.endsWith('/home/generate'))
          .toList();
      expect(submissions[0].data, submissions[1].data);
    },
  );

  test(
    'model catalog filters home duration and preserves typed parameter defaults',
    () async {
      final fixture = HomeCreationFixture();
      final models = await fixture.repository.models();
      expect(models.map((model) => model.id), ['501']);
      final model = models.single;
      expect(model.parameters.first.options.map((option) => option.value), [
        15,
        30,
      ]);
      expect(model.defaultConfig.params['duration'], 15);
      expect(model.accepts(model.defaultConfig), isTrue);
      expect(await fixture.repository.estimate(model.defaultConfig), 42);
      final request = fixture.requests.last;
      expect(request.data['modelId'], '501');
      expect(request.data['parameters']['duration'], 15);
      expect(request.data['outputCount'], 1);
    },
  );

  test('restores a chosen story and task; paused tasks stop polling', () async {
    final fixture = HomeCreationFixture()
      ..selected = {
        'id': 'selected',
        'title': 'Saved story',
        'summary': 'Saved body',
      }
      ..task = HomeCreationFixture().taskValue('paused');
    final home = await fixture.repository.open(
      '202',
      sessionId: 'saved-session',
    );
    expect(home.accountId, '202');
    expect(home.topics.single.id, 'selected');
    expect(home.task!.needsPolling, isFalse);
    final resumed = await fixture.repository.control(home.task!, 'resume');
    expect(resumed.state, 'running');
    expect(resumed.needsPolling, isTrue);
    fixture.task = fixture.taskValue('awaiting_confirmation', version: 3);
    final waiting = await fixture.repository.task(resumed.id);
    expect(waiting.canConfirmVideo, isTrue);
    await fixture.repository.control(waiting, 'confirm-video');
    expect(fixture.requests.last.path.endsWith('/confirm-video'), isTrue);
    expect(fixture.requests.last.data.containsKey('action'), isFalse);
  });

  test(
    'unready, duplicate and text-only roles cannot create a project',
    () async {
      final fixture = HomeCreationFixture();
      final repository = fixture.repository;
      final ready = LibraryRole.fromJson(fixture.role(1));
      for (final roles in [
        <LibraryRole>[],
        [ready, ready],
        [
          LibraryRole.fromJson({
            ...fixture.role(1),
            'canUseVideo': false,
            'canUseText': true,
          }),
        ],
        [
          LibraryRole.fromJson({...fixture.role(1), 'profileVersion': null}),
        ],
      ]) {
        expect(() => repository.create(roles), throwsA(isA<ApiException>()));
      }
      expect(fixture.requests, isEmpty);
    },
  );
}
