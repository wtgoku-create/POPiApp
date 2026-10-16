import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/ip_accounts/data/ip_account_repository.dart';
import 'package:popi_ai_app/features/ip_accounts/domain/account_preferences.dart';

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
    'pageInfo': {'page': number, 'pageCount': count, 'total': items.length},
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
              data: {'requestId': 'req', 'data': respond(options)},
            ),
          );
        },
      ),
    );
    repository = IpAccountRepository(NetworkApi(dio));
    addTearDown(dio.close);
  });
  test('empty creation retries retain the request identifier', () async {
    respond = (_) => {'id': '42', 'revision': 1};
    await repository.create(requestId: 'same-request');
    await repository.create(requestId: 'same-request');
    expect(requests.first.data, {
      'clientRequestId': 'same-request',
      'accountType': 'ip_character',
    });
    expect(requests.first.data, requests.last.data);
  });
  test('archive sends no body and restore only sends its action', () async {
    respond = (_) => {'id': '42', 'revision': 8};
    await repository.archive('42');
    await repository.restore('42');
    expect(requests[0].method, 'DELETE');
    expect(requests[0].data, isNull);
    expect(requests[1].data, {'action': 'restore'});
  });
  test(
    'list filter follows pagination and handles zero-page empty results',
    () async {
      respond = (request) => page(
        [
          {
            'id': '42',
            'title': 'Archived',
            'status': 'archived',
            'iconBackgroundColor': '#FEF2ED',
            'preferences': {
              'contentDirections': ['校园'],
            },
          },
        ],
        number: request.queryParameters['page'] as int,
        count: 2,
      );
      final items = await repository.list(status: 'archived');
      expect(items.items, hasLength(1));
      expect(items.hasMore, isTrue);
      expect(items.items.first.isPaused, isTrue);
      expect(items.items.first.iconBackgroundColor, '#FEF2ED');
      expect(items.items.first.description, '校园');
      expect(requests.map((r) => r.queryParameters['status']), ['archived']);
      respond = (_) => page([], count: 0);
      expect((await repository.list()).items, isEmpty);
    },
  );
  test('patch can clear the user prompt independently', () async {
    respond = (_) => {'id': '42', 'revision': 8};
    await repository.update('42', userPrompt: '');
    expect(requests.single.data, {'userPrompt': ''});
  });
  test(
    'archive search and version queries stay scoped to their account',
    () async {
      respond = (request) => page(
        [
          {
            'id': '20',
            'title': 'School',
            'versionId': '30',
            'summary': 'A story',
          },
        ],
        number: request.queryParameters['page'] as int,
        count: 2,
      );
      final results = await repository.archives(
        '42',
        keyword: 'School',
        page: 2,
      );
      expect(results.items.single.versionId, '30');
      expect(requests.single.method, 'GET');
      expect(requests.single.queryParameters, {
        'keyword': 'School',
        'page': 2,
        'pageSize': 20,
      });
      expect(
        requests.single.path,
        '/api_client/agent/v2/accounts/42/creation-archives',
      );
      respond = (_) => {
        'title': 'School',
        'creationId': '20',
        'versionId': '30',
        'script': 'A story',
        'versions': [
          {'id': '30', 'version': 1},
        ],
      };
      final detail = await repository.archiveDetail(
        '42',
        '20',
        versionId: '30',
      );
      expect(detail.sections['script'], 'A story');
      expect(detail.versions, {'30': 1});
      expect(requests.last.queryParameters, {'versionId': '30'});
    },
  );
  test('Chinese names enforce byte and selection limits', () {
    const step = AccountPreferenceStep(
      key: 'direction',
      title: 'Direction',
      maxSelections: 2,
      maxNameBytes: 6,
    );
    expect(step.accepts(['校园', '家庭']), isTrue);
    expect(step.accepts(['校园', '家庭', '职场']), isFalse);
    expect(step.accepts(['校园生活']), isFalse);
    expect(step.accepts([' ']), isFalse);
    expect(step.accepts([]), isTrue);
  });
  test('busy archive errors preserve the backend explanation', () async {
    dio.interceptors.clear();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: 409,
              data: {'message': 'Stop the active task first'},
            ),
          ),
        ),
      ),
    );
    await expectLater(
      repository.archive('42'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Stop the active task first',
        ),
      ),
    );
  });
}
