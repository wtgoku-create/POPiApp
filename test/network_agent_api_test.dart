import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/config/app_config.dart';
import 'package:popi_ai_app/core/network/agent_api_exception.dart';
import 'package:popi_ai_app/core/network/dio_client.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/storage/secure_storage.dart';
import 'package:popi_ai_app/features/projects/data/project_repository.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';

void main() {
  test(
    'providers configure independent Agent transport and shared auth',
    () async {
      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(_Tokens())],
      );
      addTearDown(container.dispose);
      final business = container.read(dioProvider);
      final agent = container.read(agentDioProvider);
      addTearDown(() => business.close(force: true));
      addTearDown(() => agent.close(force: true));
      expect(identical(business, agent), isFalse);
      expect(business.options.baseUrl, AppConfig.apiBaseUrl);
      expect(agent.options.baseUrl, AppConfig.agentApiBaseUrl);
      expect(
        agent.options.headers['Origin'],
        AppConfig.agentApiOrigin.isEmpty ? null : AppConfig.agentApiOrigin,
      );
      expect(business.options.headers.containsKey('Origin'), isFalse);
      agent.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.headers['Authorization'], 'Bearer agent-token');
            handler.resolve(
              Response(requestOptions: options, data: {'list': []}),
            );
          },
        ),
      );
      await NetworkAgentApi(agent).projectSessionsPage('account', 1);
    },
  );

  test(
    'repository routes sessions to Agent host with Origin and raw JSON',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final subscription = server.listen((request) async {
        expect(request.uri.path, '/api_agent/v2/sessions/resolve');
        expect(request.headers.value('Origin'), 'http://localhost:5195');
        expect(request.headers.value('Authorization'), 'Bearer agent-token');
        expect(request.headers.value('Accept'), 'application/json');
        expect(request.headers.contentType?.mimeType, 'application/json');
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'clientRequestId': 'request-id',
          'mode': 'new',
          'title': 'New',
          'contextRef': {'kind': 'account', 'id': 'account / 1'},
        });
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'id': 's1', 'title': 'New'}));
        await request.response.close();
      });
      addTearDown(subscription.cancel);
      final business = Dio(BaseOptions(baseUrl: 'https://business.example'));
      final agent = DioClient(
        secureStorage: _Tokens(),
        baseUrl: 'http://127.0.0.1:${server.port}',
        headers: {'Origin': 'http://localhost:5195'},
      ).dio;
      addTearDown(() => business.close(force: true));
      addTearDown(() => agent.close(force: true));
      business.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.uri.host, 'business.example');
            expect(options.path, '/api_client/agent/v2/accounts');
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'status': '0000',
                  'data': {
                    'list': [],
                    'pageInfo': {
                      'page': 1,
                      'pageSize': 100,
                      'pageCount': 1,
                      'total': 0,
                    },
                  },
                },
              ),
            );
          },
        ),
      );
      final repository = ProjectRepository(
        NetworkApi(business),
        NetworkAgentApi(agent),
      );
      expect(await repository.listProjects(), isEmpty);
      final session = await repository.createSession(
        'account / 1',
        'New',
        clientRequestId: 'request-id',
      );
      expect(session.id, 's1');
    },
  );

  test(
    'receives the updated session after a revision checked update',
    () async {
      final dio = Dio();
      addTearDown(() => dio.close(force: true));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: options.method == 'PATCH'
                    ? {'id': 's1', 'title': 'Session', 'revision': 4}
                    : {
                        'session': {'revision': 3},
                      },
              ),
            );
          },
        ),
      );
      await NetworkAgentApi(
        dio,
      ).updateProjectSession('s1', clientRequestId: 'key', archived: true);
    },
  );

  for (final nested in [false, true]) {
    test(
      'preserves ${nested ? 'nested' : 'direct'} Agent HTTP errors',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final payload = {
          'code': 'REVISION_CONFLICT',
          'message': 'Changed elsewhere',
          'retryable': true,
          'requestId': 'r1',
          'current': {'revision': 4},
        };
        final subscription = server.listen((request) async {
          request.response.statusCode = 409;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(nested ? {'error': payload} : payload),
          );
          await request.response.close();
        });
        addTearDown(subscription.cancel);
        final dio = Dio(
          BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}'),
        );
        addTearDown(() => dio.close(force: true));
        await expectLater(
          NetworkAgentApi(dio).projectSessionsPage('a', 1),
          throwsA(
            isA<AgentApiException>()
                .having((e) => e.statusCode, 'status', 409)
                .having((e) => e.code, 'code', 'REVISION_CONFLICT')
                .having((e) => e.message, 'message', 'Changed elsewhere')
                .having((e) => e.retryable, 'retryable', true)
                .having((e) => e.requestId, 'requestId', 'r1')
                .having((e) => e.current, 'current', {'revision': 4}),
          ),
        );
      },
    );
  }

  test('rejects empty or non-object JSON for required responses', () async {
    for (final body in [null, <Object?>[], 'invalid']) {
      final dio = Dio();
      addTearDown(() => dio.close(force: true));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(Response(requestOptions: options, data: body));
          },
        ),
      );
      await expectLater(
        NetworkAgentApi(dio).projectSessionsPage('a', 1),
        throwsA(
          isA<AgentApiException>().having(
            (e) => e.code,
            'code',
            'INVALID_RESPONSE',
          ),
        ),
      );
    }
  });

  test('preserves cancellation and network failures', () async {
    for (final type in [
      DioExceptionType.cancel,
      DioExceptionType.connectionError,
    ]) {
      final dio = Dio();
      addTearDown(() => dio.close(force: true));
      late DioException failure;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            failure = DioException(requestOptions: options, type: type);
            handler.reject(failure);
          },
        ),
      );
      await expectLater(
        NetworkAgentApi(dio).projectSessionsPage('a', 1),
        throwsA(
          isA<DioException>().having(
            (e) => identical(e, failure),
            'same error',
            true,
          ),
        ),
      );
    }
  });
}

class _Tokens implements TokenStorage {
  @override
  Future<String?> readAccessToken() async => 'agent-token';
  @override
  Future<void> writeAccessToken(String token) async {}
  @override
  Future<void> deleteAccessToken() async {}
}
