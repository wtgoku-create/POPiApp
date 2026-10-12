import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/features/assets/domain/library_role.dart';
import 'package:popi_ai_app/features/role_guide/domain/home_creation.dart';

import 'support/home_creation_fixtures.dart';

void main() {
  test(
    'custom topics reuse uncertain request IDs and consume the returned snapshot',
    () async {
      final fixture = HomeCreationFixture();
      final repository = fixture.repository;
      final home = await repository.open('101');
      fixture.failTopicsOnce = true;
      await expectLater(
        repository.customTopic(home, '  A campus story  '),
        throwsA(isA<DioException>()),
      );
      final updated = await repository.customTopic(home, 'A campus story');
      expect(updated.topics.single.title, 'Custom story: A campus story');
      final writes = fixture.requests
          .where((request) => request.path.endsWith('/topics'))
          .toList();
      expect(writes, hasLength(2));
      expect(writes.first.data, writes.last.data);
      expect(
        writes.last.data.keys,
        unorderedEquals(['clientRequestId', 'mode', 'text']),
      );
      expect(writes.last.data['mode'], 'custom');
      expect(writes.last.data['text'], 'A campus story');
      expect(
        fixture.requests.where(
          (request) => request.path.endsWith('/home/enter'),
        ),
        hasLength(1),
      );
      for (final text in [' ', List.filled(16001, 'a').join()]) {
        expect(() => repository.customTopic(home, text), throwsArgumentError);
      }
    },
  );

  test('clearing the session cast refreshes the existing account', () async {
    final fixture = HomeCreationFixture();
    final repository = fixture.repository;
    final home = await repository.open('101');
    final updated = await repository.replaceCast(home, []);
    expect(updated.cast, isEmpty);
    expect(updated.accountId, home.accountId);
    final write = fixture.requests.firstWhere(
      (request) => request.path.endsWith('/cast'),
    );
    expect(write.data['roleIds'], isEmpty);
    expect(write.data['reply'], isFalse);
    expect(
      fixture.requests.last.data.keys,
      unorderedEquals(['clientRequestId', 'accountId']),
    );
  });

  test(
    'continuation reuses account and cast but resets topic, config and task',
    () async {
      final fixture = HomeCreationFixture();
      final repository = fixture.repository;
      var home = await repository.open('101');
      home = await repository.recommend(home);
      home = await repository.selectTopic(home, home.topics.single);
      await repository.generate(
        home,
        const HomeConfig(modelId: '501', params: {'duration': 15}),
      );
      fixture.task = fixture.taskValue('completed', lock: 'released');
      home = await repository.refresh(home);
      expect(home.editable, isFalse);
      final updated = await repository.continueCreation(home);
      final input = fixture.requests.last.data as Map;
      expect(
        input.keys,
        unorderedEquals(['clientRequestId', 'accountId', 'newCreation']),
      );
      expect(input['newCreation'], isTrue);
      expect(updated.accountId, home.accountId);
      expect(updated.sessionId, home.sessionId);
      expect(updated.id, isNot(home.id));
      expect(
        updated.cast.map((role) => role.id),
        home.cast.map((role) => role.id),
      );
      expect(updated.topics, isEmpty);
      expect(updated.selectedTopic, isNull);
      expect(updated.config, isNull);
      expect(updated.task, isNull);
    },
  );

  test('ten-second models and numeric bounds follow the catalog', () {
    final model = HomeModel.fromJson({
      'id': '8',
      'available': true,
      'mediaType': 'video',
      'parameters': [
        {
          'name': 'duration',
          'type': 'number',
          'required': true,
          'default': 10,
          'options': [10],
        },
      ],
    });
    expect(model.available, isTrue);
    expect(model.defaultConfig.params['duration'], 10);
    expect(model.accepts(model.defaultConfig), isTrue);
    final parameter = HomeParameter.fromJson({
      'name': 'strength',
      'type': 'number',
      'required': true,
      'min': 0.5,
      'max': 2,
      'step': 0.5,
    });
    expect(parameter.accepts(1), isTrue);
    for (final value in [null, -1, 3, 0.7, double.infinity]) {
      expect(parameter.accepts(value), isFalse);
    }
  });

  test(
    'video confirmation requires pending confirmation and an available action',
    () {
      final fixture = HomeCreationFixture();
      final waiting = fixture.taskValue('awaiting_confirmation');
      expect(HomeTask.fromJson(waiting).canConfirmVideo, isTrue);
      expect(
        HomeTask.fromJson({
          ...waiting,
          'confirmationPending': false,
        }).canConfirmVideo,
        isFalse,
      );
      expect(
        HomeTask.fromJson({...waiting, 'allowedActions': []}).canConfirmVideo,
        isFalse,
      );
      expect(
        HomeTask.fromJson(
          fixture.taskValue('completed', lock: 'held'),
        ).canContinue,
        isFalse,
      );
      expect(
        HomeTask.fromJson(
          fixture.taskValue('completed', lock: 'released'),
        ).canContinue,
        isTrue,
      );
    },
  );

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
      final topic = agent.firstWhere(
        (request) => request.path.endsWith('/topic'),
      );
      expect(topic.method, 'PUT');
      expect(topic.path, '/api_agent/v2/sessions/${home.sessionId}/topic');
      expect(topic.data.keys, unorderedEquals(['clientRequestId', 'topicId']));
      final cast = agent.firstWhere(
        (request) => request.path.endsWith('/cast'),
      );
      expect(cast.method, 'PUT');
      expect(cast.data['roleIds'], [2]);
      expect(cast.data['reply'], isFalse);
      expect(
        cast.data.keys,
        unorderedEquals(['clientRequestId', 'roleIds', 'reply']),
      );
      final recommendation = agent.firstWhere(
        (request) => request.path.endsWith('/topics'),
      );
      expect(
        recommendation.data.keys,
        unorderedEquals(['clientRequestId', 'mode']),
      );
      expect(recommendation.data['mode'], 'recommend');
      expect(
        fixture.requests.where(
          (request) => request.path.endsWith('/home/enter'),
        ),
        hasLength(2),
      );
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
    'model catalog preserves server duration options and typed defaults',
    () async {
      final fixture = HomeCreationFixture();
      final models = await fixture.repository.models();
      expect(models.map((model) => model.id), ['501']);
      final model = models.single;
      expect(model.parameters.first.options.map((option) => option.value), [
        5,
        15,
        30,
      ]);
      expect(model.defaultConfig.params['duration'], 5);
      expect(model.accepts(model.defaultConfig), isTrue);
      expect(await fixture.repository.estimate(model.defaultConfig), 42);
      final request = fixture.requests.last;
      expect(request.data['modelId'], '501');
      expect(request.data['parameters']['duration'], 5);
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
    final home = await fixture.repository.open('202');
    expect(
      fixture.requests.single.data.keys,
      unorderedEquals(['clientRequestId', 'accountId']),
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
        [
          LibraryRole.fromJson({...fixture.role(1), 'canRead': false}),
        ],
      ]) {
        expect(() => repository.create(roles), throwsA(isA<ApiException>()));
      }
      expect(fixture.requests, isEmpty);
    },
  );
}
