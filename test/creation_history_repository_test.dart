import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/ip_accounts/data/ip_account_repository.dart';
import 'package:popi_ai_app/features/session/domain/session_artifact.dart';

Map<String, Object?> textOutput(
  String id, {
  String title = '',
  String body = '',
}) => {
  'id': 'text:$id',
  'category': 'text',
  'type': 'script',
  'title': title,
  'createdAt': '2026-10-19T08:01:00Z',
  'text': {
    'id': id,
    'kind': 'script',
    'content': body,
    'durationSeconds': 15,
    'version': 2,
    'parentId': '30',
  },
};

void main() {
  late Dio businessDio;
  late Dio agentDio;
  late IpAccountRepository repository;
  late List<RequestOptions> requests;
  late List<RequestOptions> bindingRequests;
  late Map<int, List<Map<String, Object?>>> pages;
  late String? bindingError;
  late bool failArtifacts;
  late bool invalidPage;

  setUp(() {
    businessDio = Dio();
    agentDio = Dio();
    requests = [];
    bindingRequests = [];
    pages = {
      1: [textOutput('31', title: 'Saved title', body: '## Saved version')],
    };
    bindingError = null;
    failArtifacts = false;
    invalidPage = false;
    agentDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          bindingRequests.add(request);
          if (bindingError != null) {
            handler.reject(
              DioException(
                requestOptions: request,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: request,
                  statusCode: 404,
                  data: {'code': bindingError},
                ),
              ),
            );
            return;
          }
          handler.resolve(
            Response(requestOptions: request, data: {'id': 'session/id'}),
          );
        },
      ),
    );
    businessDio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          final page = request.queryParameters['page'] as int;
          handler.resolve(
            Response(
              requestOptions: request,
              data: failArtifacts
                  ? {'status': '5000'}
                  : {
                      'requestId': 'request',
                      'data': {
                        'list': pages[page] ?? [],
                        'pageInfo': {
                          'page': invalidPage ? page + 1 : page,
                          'pageSize': 20,
                          'pageCount': pages.length,
                          'total': pages.values.fold<int>(
                            0,
                            (sum, rows) => sum + rows.length,
                          ),
                        },
                      },
                    },
            ),
          );
        },
      ),
    );
    repository = IpAccountRepository(
      NetworkApi(businessDio),
      agentApi: NetworkAgentApi(agentDio),
    );
  });

  tearDown(() {
    businessDio.close(force: true);
    agentDio.close(force: true);
  });

  test(
    'resolves bound session and reads unified outputs using business transport',
    () async {
      final result = await repository.creationHistory('account/id');
      expect(
        bindingRequests.single.path,
        '/api_agent/v2/sessions/by-account/account%2Fid',
      );
      final request = requests.single;
      expect(
        request.path,
        '/api_client/agent/v2/sessions/session%2Fid/artifacts',
      );
      expect(request.method, 'GET');
      expect(request.data, isNull);
      expect(request.queryParameters, {'page': 1, 'pageSize': 20});
      final item = result.items.single;
      expect(item.id, 'text:31');
      expect(item.summary, '## Saved version');
      expect(item.durationSeconds, 15);
      expect(item.createdAt, DateTime.utc(2026, 10, 19, 8, 1));
      expect(item.mediaId, isNull);
    },
  );

  test(
    'includes every output type and keeps namespaced IDs and media references',
    () async {
      pages[1] = [
        for (final kind in ['topic', 'script', 'storyboard'])
          {...textOutput(kind, body: 'Saved $kind'), 'type': kind},
        for (final kind in ['image', 'video', 'audio', 'three_view'])
          {
            'id': 'media:$kind',
            'category': kind == 'three_view' ? 'role_image' : 'media',
            'type': kind,
            'title': '',
            'media': {
              'id': kind,
              'kind': kind == 'three_view' ? 'image' : kind,
              'detailUrl': '/api_client/agent/v2/media/$kind',
            },
            if (kind == 'three_view') 'role': {'id': 201, 'versionId': '301'},
          },
      ];
      final result = await repository.creationHistory('42');
      expect(result.items.map((item) => item.type), [
        SessionArtifactType.script,
        SessionArtifactType.script,
        SessionArtifactType.script,
        SessionArtifactType.image,
        SessionArtifactType.video,
        SessionArtifactType.audio,
        SessionArtifactType.image,
      ]);
      expect(result.items.take(3).map((item) => item.textKind), [
        'topic',
        'script',
        'storyboard',
      ]);
      expect(result.items.skip(3).map((item) => item.mediaId), [
        'image',
        'video',
        'audio',
        'three_view',
      ]);
      expect(
        result.items.every(
          (item) => item.previewAsset == null && item.videoUrl == null,
        ),
        isTrue,
      );
      expect(requests, hasLength(1));
    },
  );

  test('search uses server filtering and preserves its pagination', () async {
    pages = {
      1: [textOutput('2', body: 'A NEEDLE in the saved script')],
      2: [textOutput('3', title: 'Needle final')],
    };
    final first = await repository.creationHistory('42', keyword: ' needle ');
    expect(first.items.single.id, 'text:2');
    expect(first.page, 1);
    expect(first.hasMore, isTrue);
    final last = await repository.creationHistory(
      '42',
      keyword: 'needle',
      page: first.page + 1,
    );
    expect(last.items.single.id, 'text:3');
    expect(last.hasMore, isFalse);
    expect(requests.map((request) => request.queryParameters['page']), [1, 2]);
    expect(
      requests.every(
        (request) => request.queryParameters['keyword'] == 'needle',
      ),
      isTrue,
    );
  });

  test(
    'search respects an empty server result without scanning pages',
    () async {
      pages = {1: []};
      final result = await repository.creationHistory('42', keyword: 'missing');
      expect(result.items, isEmpty);
      expect(result.page, 1);
      expect(result.hasMore, isFalse);
      expect(requests, hasLength(1));
      expect(requests.single.queryParameters['keyword'], 'missing');
    },
  );

  test('keyword preserves case and literal search characters', () async {
    await repository.creationHistory('42', keyword: '  Needle %_  ');
    expect(requests.single.queryParameters['keyword'], 'Needle %_');
  });

  test(
    'blank keyword omits filtering and retains the requested page',
    () async {
      pages[2] = [textOutput('32', title: 'Second page')];
      final result = await repository.creationHistory(
        '42',
        keyword: ' \t\n ',
        page: 2,
      );
      expect(requests.single.queryParameters, {'page': 2, 'pageSize': 20});
      expect(result.page, 2);
      expect(result.items.single.id, 'text:32');
    },
  );

  test(
    'server search results are retained without additional client filtering',
    () async {
      final result = await repository.creationHistory(
        '42',
        keyword: 'server query',
      );
      expect(requests.single.queryParameters['keyword'], 'server query');
      expect(result.items.single.id, 'text:31');
      expect(result.items.single.title, 'Saved title');
    },
  );

  test(
    'missing binding returns empty history without creating a session',
    () async {
      bindingError = 'ACCOUNT_SESSION_NOT_FOUND';
      expect((await repository.creationHistory('42')).items, isEmpty);
      expect(bindingRequests, hasLength(1));
      expect(bindingRequests.single.method, 'GET');
      expect(requests, isEmpty);
    },
  );

  test('other binding failures and artifact failures are propagated', () async {
    bindingError = 'ACCOUNT_NOT_FOUND';
    await expectLater(
      repository.creationHistory('42'),
      throwsA(isA<ApiException>()),
    );
    expect(requests, isEmpty);
    bindingError = null;
    failArtifacts = true;
    await expectLater(
      repository.creationHistory('42'),
      throwsA(isA<ApiException>()),
    );
  });

  test('invalid pagination and malformed output IDs are rejected', () async {
    invalidPage = true;
    await expectLater(
      repository.creationHistory('42'),
      throwsA(isA<ApiException>()),
    );
    invalidPage = false;
    pages[1] = [
      {...textOutput('31'), 'id': 'media:31'},
    ];
    await expectLater(
      repository.creationHistory('42'),
      throwsA(isA<ApiException>()),
    );
  });

  test('cancelled loads cannot request history', () async {
    final token = CancelToken()..cancel();
    await expectLater(
      repository.creationHistory('42', cancelToken: token),
      throwsA(isA<ApiException>()),
    );
    expect(bindingRequests, isEmpty);
    expect(requests, isEmpty);
  });
}
