import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/activities/data/activity_repository.dart';
import 'package:popi_ai_app/features/activities/domain/activity.dart';

import 'support/activity_fixtures.dart';

void main() {
  late ActivityFixture fixture;
  late ActivityRepository repository;
  setUp(() {
    fixture = ActivityFixture();
    repository = ActivityRepository(NetworkApi(fixture.dio));
  });
  tearDown(() => fixture.dio.close(force: true));

  test(
    'uses the web list contract, resolves images and parses tags and member levels',
    () async {
      fixture.activities.first['cover'] = '/campaign.png';
      fixture.activities.first['desp'] = r'First\nSecond';
      final catalog = await repository.fetchCatalog();
      final request = fixture.requests.first;
      expect(request.method, 'GET');
      expect(request.path, '/api_client/users/activity/list');
      expect(request.queryParameters, {'name': '', 'type': '', 'status': 1});
      expect(
        catalog.activities.first.coverUrl,
        'https://example.test/campaign.png',
      );
      expect(catalog.activities.first.description, 'First\nSecond');
      expect(catalog.activities.first.tags.single.label, 'NEW');
      expect(catalog.activities.first.tags.single.foreground, 0xFF6F47F5);
      expect(catalog.memberLabels[2], '创作进阶卡');
      expect(catalog.activities.last.allowsMemberLevel(0), isFalse);
      expect(catalog.activities.last.allowsMemberLevel(2), isTrue);
    },
  );

  test(
    'filters inactive, future and expired activities with inclusive boundaries',
    () async {
      final now = DateTime.utc(2026, 10, 10);
      fixture.activities = [
        {'id': 1, 'status': 0},
        {'id': 2, 'status': 1, 'startTime': '2026-10-11T00:00:00Z'},
        {'id': 3, 'status': 1, 'endTime': '2026-10-09T00:00:00Z'},
        {
          'id': 4,
          'status': 1,
          'startTime': now.toIso8601String(),
          'endTime': now.toIso8601String(),
        },
        {'id': 5, 'status': 1, 'startTime': 'invalid', 'tags': 'invalid'},
      ];
      final items = (await repository.fetchCatalog(now: now)).activities;
      expect(items.map((item) => item.id), [4, 5]);
      expect(items.last.tags, isEmpty);
    },
  );

  test(
    'bad list responses fail while missing member labels remain optional',
    () async {
      fixture.listFails = true;
      await expectLater(repository.fetchCatalog(), throwsException);
      fixture.listFails = false;
      fixture.membersFail = true;
      expect((await repository.fetchCatalog()).activities, hasLength(2));
      expect((await repository.fetchCatalog()).memberLabels, isEmpty);
    },
  );

  const ordinary = Activity(id: 1, name: 'Campaign');
  const book = Activity(
    id: 2,
    name: 'Book card',
    type: ' BOOK_CARD ',
    memberLevels: [1],
  );

  test(
    'activation posts only a trimmed code and propagates business errors',
    () async {
      expect(
        await repository.redeem(ordinary, ' CODE ', memberLevel: 0),
        isNull,
      );
      expect(fixture.requests.single.method, 'POST');
      expect(fixture.requests.single.path, '/api_client/users/activeCode/use');
      expect(fixture.requests.single.data, {'code': 'CODE'});
      fixture.activationStatus = '9999';
      await expectLater(
        repository.redeem(ordinary, 'CODE', memberLevel: 0),
        throwsA(isA<ApiException>()),
      );
    },
  );

  test(
    'invalid codes, disallowed memberships and expired activities never submit',
    () async {
      await expectLater(
        repository.redeem(ordinary, ' ', memberLevel: 0),
        throwsArgumentError,
      );
      await expectLater(
        repository.redeem(ordinary, 'x' * 65, memberLevel: 0),
        throwsArgumentError,
      );
      await expectLater(
        repository.redeem(book, 'CODE', memberLevel: 0),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        repository.redeem(
          Activity(id: 3, name: 'Expired', endsAt: DateTime(2020)),
          'CODE',
          memberLevel: 0,
        ),
        throwsA(isA<ApiException>()),
      );
      expect(fixture.requests, isEmpty);
    },
  );

  test(
    'book-card QR accepts HTTP URLs and Markdown links and rejects unsafe schemes',
    () async {
      for (final value in [
        'https://example.test/qr.png',
        '[QR](https://example.test/qr.png)',
      ]) {
        fixture.qrUrl = value;
        expect(
          await repository.redeem(book, 'ORDER', memberLevel: 1),
          'https://example.test/qr.png',
        );
        expect(
          await repository.redeem(ordinary, 'CODE', memberLevel: 0),
          isNull,
        );
      }
      for (final value in [
        'javascript:alert(1)',
        'file:///private/qr.png',
        '/relative.png',
        '',
      ]) {
        fixture.qrUrl = value;
        expect(await repository.redeem(book, 'ORDER', memberLevel: 1), isNull);
      }
    },
  );
}
