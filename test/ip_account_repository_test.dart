import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/ip_accounts/data/ip_account_repository.dart';
import 'package:popi_ai_app/features/ip_accounts/domain/ip_account_home.dart';

void main() {
  late Dio dio;
  late IpAccountRepository repository;
  late List<RequestOptions> requests;
  late Object Function(RequestOptions) respond;

  Map<String, Object?> page(
    List<Object> items, {
    int number = 1,
    int count = 1,
  }) => {
    'list': items,
    'pageInfo': {'page': number, 'pageCount': count},
  };

  setUp(() {
    requests = [];
    dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response(
              requestOptions: options,
              data: {'status': '0000', 'data': respond(options)},
            ),
          );
        },
      ),
    );
    repository = IpAccountRepository(NetworkApi(dio));
    addTearDown(dio.close);
  });

  test(
    'reads the active profile across pages instead of a newer draft',
    () async {
      respond = (request) {
        if (request.path.endsWith('/42')) {
          return {
            'id': '42',
            'title': 'Account',
            'revision': 7,
            'status': 'active',
            'activeProfileVersionId': 'old-active',
            'residentRoles': [],
          };
        }
        final number = request.queryParameters['page'] as int;
        return page(
          [
            {
              'id': number == 1 ? 'new-draft' : 'old-active',
              'profile': {'positioning': number == 1 ? 'Wrong' : 'Active'},
            },
          ],
          number: number,
          count: 2,
        );
      };
      final account = await repository.detail('42');
      expect(account.text('positioning'), 'Active');
      expect(account.revision, 7);
      expect(requests.map((r) => r.queryParameters['page']), [null, 1, 2]);
    },
  );

  test('a dangling active version is an error, not an empty profile', () async {
    respond = (request) => request.path.endsWith('/42')
        ? {
            'id': '42',
            'title': 'Account',
            'revision': 1,
            'activeProfileVersionId': 'gone',
          }
        : page([]);
    await expectLater(repository.detail('42'), throwsA(isA<ApiException>()));
  });

  test(
    'new accounts without an active profile skip version requests',
    () async {
      respond = (_) => {'id': '42', 'title': 'New', 'revision': 1};
      final account = await repository.detail('42');
      expect(account.profile, isEmpty);
      expect(requests, hasLength(1));
    },
  );

  test('profile saves preserve unknown fields and revision metadata', () async {
    respond = (_) => {'id': 'saved-version'};
    const account = IpAccountHome(
      id: 'account / 42',
      title: 'Account',
      revision: 8,
      profile: {
        'positioning': 'Old',
        'defaultMedia': {'ratio': '9:16'},
        'targetAudience': 'Readers',
      },
    );
    await repository.saveProfile(account, {
      'positioning': 'New',
    }, requestId: 'stable');
    expect(
      requests.single.path,
      '/api_client/agent/v2/accounts/account%20%2F%2042/profile-versions',
    );
    expect(requests.single.data, {
      'clientRequestId': 'stable',
      'expectedRevision': 8,
      'activate': true,
      'profile': {
        'positioning': 'New',
        'defaultMedia': {'ratio': '9:16'},
        'targetAudience': 'Readers',
      },
    });
  });

  test(
    'resident saves retain pinned versions and serialize numeric role IDs',
    () async {
      respond = (_) => {'id': '42', 'revision': 9};
      const account = IpAccountHome(
        id: '42',
        title: 'Account',
        revision: 8,
        residentRoles: [
          {'roleId': 10, 'profileVersionId': '900'},
        ],
      );
      await repository.saveRoles(account, ['10', '20'], requestId: 'stable');
      expect(requests.single.method, 'PUT');
      expect(requests.single.data, {
        'clientRequestId': 'stable',
        'expectedRevision': 8,
        'items': [
          {'roleId': 10, 'profileVersionId': '900'},
          {'roleId': 20},
        ],
      });
    },
  );

  test(
    'resources are scoped to the account and exclude archived creations',
    () async {
      respond = (request) => request.path.endsWith('/creations')
          ? page([
              {
                'id': '1',
                'title': 'Visible',
                'status': 'draft',
                'sessionId': 'session',
              },
              {'id': '2', 'title': 'Hidden', 'status': 'archived'},
            ])
          : {'id': '20', 'title': 'Role', 'canUseText': true};
      const account = IpAccountHome(
        id: '42',
        title: 'Account',
        revision: 1,
        residentRoles: [
          {'roleId': 20},
        ],
      );
      final resources = await repository.resources(account);
      expect(resources.creations.single.title, 'Visible');
      expect(resources.creations.single.sessionId, 'session');
      expect(resources.roles.single.id, '20');
      expect(requests.first.path, '/api_client/agent/v2/accounts/42/creations');
    },
  );

  test('rename retries keep the same revision and request ID', () async {
    respond = (_) => {'id': '42', 'revision': 9};
    for (var attempt = 0; attempt < 2; attempt++) {
      await repository.rename(
        '42',
        ' Renamed ',
        revision: 8,
        requestId: 'stable',
      );
    }
    expect(requests.map((r) => r.method), ['PATCH', 'PATCH']);
    expect(requests.first.data, requests.last.data);
    expect(requests.first.data, {
      'clientRequestId': 'stable',
      'expectedRevision': 8,
      'title': 'Renamed',
    });
  });

  test('backend errors and malformed pagination are surfaced', () async {
    respond = (_) => {
      'list': [],
      'pageInfo': {'page': 1, 'pageCount': 0},
    };
    await expectLater(repository.list(), throwsA(isA<ApiException>()));
    respond = (_) => {'status': 'failure'};
    await expectLater(repository.detail('42'), throwsA(isA<ApiException>()));
  });
}
