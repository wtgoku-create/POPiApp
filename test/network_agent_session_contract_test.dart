import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/agent_api_exception.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';

const sessionId = '00000000-0000-4000-8000-000000000201';
const requestId = '00000000-0000-4000-8000-000000000004';

// Contracts from popiart-agent-server/src/studio/http/routes.ts and domain/contracts.ts.
void main() {
  late Dio dio;
  late NetworkAgentApi api;
  setUp(() {
    dio = Dio();
    api = NetworkAgentApi(dio);
  });
  tearDown(() => dio.close(force: true));

  test(
    'standalone resolve omits project context and retains binding state',
    () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, '/api_agent/v2/sessions/resolve');
            expect(options.method, 'POST');
            expect(options.data, {'clientRequestId': requestId, 'mode': 'new'});
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 201,
                data: {
                  'id': sessionId,
                  'title': 'New',
                  'bindingStatus': 'pending',
                  'revision': 1,
                  'requestId': 'server-request',
                },
              ),
            );
          },
        ),
      );
      final session = await api.resolveSession(clientRequestId: requestId);
      expect(session['bindingStatus'], 'pending');
      expect(session['requestId'], 'server-request');
    },
  );

  test(
    'resume preserves typed resource references and fixed versions',
    () async {
      final ref = {
        'kind': 'character',
        'id': 201,
        'versionId': '301',
        'revision': 2,
      };
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.data, {
              'clientRequestId': requestId,
              'mode': 'resume',
              'contextRef': ref,
            });
            handler.resolve(
              Response(requestOptions: options, data: {'id': sessionId}),
            );
          },
        ),
      );
      await api.resolveSession(
        clientRequestId: requestId,
        mode: 'resume',
        contextRef: ref,
      );
    },
  );

  test(
    'lists all sessions or archived context sessions with numeric pages',
    () async {
      var calls = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, '/api_agent/v2/sessions');
            expect(
              options.queryParameters,
              calls++ == 0
                  ? {'page': 1, 'pageSize': 20, 'archived': 'false'}
                  : {
                      'page': 2,
                      'pageSize': 50,
                      'archived': 'true',
                      'contextKind': 'creation',
                      'contextId': '401',
                    },
            );
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'list': [],
                  'pageInfo': {
                    'page': options.queryParameters['page'],
                    'pageSize': options.queryParameters['pageSize'],
                    'total': 0,
                    'pageCount': 1,
                  },
                  'requestId': 'server-request',
                },
              ),
            );
          },
        ),
      );
      expect((await api.sessionsPage())['list'], isEmpty);
      await api.sessionsPage(
        page: 2,
        pageSize: 50,
        archived: true,
        contextKind: 'creation',
        contextId: '401',
      );
    },
  );

  test(
    'update retries preserve caller revision and idempotency input',
    () async {
      final requests = <Map<String, Object?>>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.method, 'PATCH');
            expect(options.path, '/api_agent/v2/sessions/$sessionId');
            requests.add(Map<String, Object?>.from(options.data as Map));
            if (requests.length == 1) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {'id': sessionId, 'revision': 8, 'pinnedAt': null},
                ),
              );
            }
          },
        ),
      );
      Future<Map<String, dynamic>> update() => api.updateSession(
        sessionId,
        clientRequestId: requestId,
        expectedRevision: 7,
        title: 'Renamed',
        pinned: false,
      );
      await expectLater(update(), throwsA(isA<DioException>()));
      expect((await update())['revision'], 8);
      expect(
        requests,
        List.filled(2, {
          'clientRequestId': requestId,
          'expectedRevision': 7,
          'title': 'Renamed',
          'pinned': false,
        }),
      );
    },
  );

  test(
    'snapshot preserves event position and asynchronous message receipts',
    () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.endsWith('/snapshot')) {
              expect(options.method, 'GET');
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'session': {'id': sessionId, 'revision': 2},
                    'lastSeq': 9,
                    'messages': [],
                    'tasks': [],
                    'runs': [],
                    'actions': [],
                    'contextEvents': [],
                  },
                ),
              );
            } else {
              expect(
                options.path,
                '/api_agent/v2/sessions/$sessionId/messages',
              );
              expect(options.method, 'POST');
              expect(options.data, {
                'clientRequestId': requestId,
                'text': 'Continue',
                'taskId': sessionId,
                'mediaIds': ['801'],
                'inputRefs': [
                  {'kind': 'character', 'id': 201, 'versionId': '301'},
                ],
              });
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 202,
                  data: {
                    'messageId': 'message',
                    'taskId': null,
                    'runId': 'run',
                  },
                ),
              );
            }
          },
        ),
      );
      expect((await api.sessionSnapshot(sessionId))['lastSeq'], 9);
      expect(
        await api.sendSessionMessage(
          sessionId,
          clientRequestId: requestId,
          text: 'Continue',
          taskId: sessionId,
          mediaIds: ['801'],
          inputRefs: [
            {'kind': 'character', 'id': 201, 'versionId': '301'},
          ],
        ),
        {'messageId': 'message', 'taskId': null, 'runId': 'run'},
      );
    },
  );

  test('stop uses consultation endpoint and retains stopped run IDs', () async {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.method, 'POST');
          expect(options.path, '/api_agent/v2/sessions/$sessionId/stop');
          expect(options.data, {'clientRequestId': requestId});
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'stoppedRunIds': ['run'],
              },
            ),
          );
        },
      ),
    );
    expect(
      (await api.stopSession(
        sessionId,
        clientRequestId: requestId,
      ))['stoppedRunIds'],
      ['run'],
    );
  });

  test(
    'SSE preserves raw frames, reconnection cursor and no receive timeout',
    () async {
      const frames =
          ': heartbeat\n\nid: $requestId\nevent: message.delta\ndata: {"seq":10,"payload":{"text":"hello"}}\n\n';
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final subscription = server.listen((request) async {
        expect(request.uri.path, '/api_agent/v2/sessions/$sessionId/events');
        expect(request.uri.queryParameters, {'afterSeq': '9'});
        expect(request.headers.value('Accept'), 'text/event-stream');
        expect(request.headers.value('Last-Event-ID'), requestId);
        request.response.headers.set(
          'content-type',
          'text/event-stream; charset=utf-8',
        );
        request.response.write(frames);
        await request.response.close();
      });
      addTearDown(subscription.cancel);
      dio.options.baseUrl = 'http://127.0.0.1:${server.port}';
      dio.options.receiveTimeout = const Duration(seconds: 15);
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.receiveTimeout, Duration.zero);
            handler.next(options);
          },
        ),
      );
      final response = await api.openSessionEvents(
        sessionId,
        afterSeq: 9,
        lastEventId: requestId,
        cancelToken: CancelToken(),
      );
      expect(await utf8.decoder.bind(response.stream).join(), frames);
    },
  );

  test(
    'SSE JSON failures preserve snapshot recovery code and header request ID',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final subscription = server.listen((request) async {
        request.response.statusCode = 409;
        request.response.headers.contentType = ContentType.json;
        request.response.headers.set('x-request-id', 'server-request');
        request.response.write(
          jsonEncode({
            'code': 'SNAPSHOT_REQUIRED',
            'message': 'Cursor expired',
            'retryable': false,
          }),
        );
        await request.response.close();
      });
      addTearDown(subscription.cancel);
      dio.options.baseUrl = 'http://127.0.0.1:${server.port}';
      await expectLater(
        api.openSessionEvents(
          sessionId,
          lastEventId: requestId,
          cancelToken: CancelToken(),
        ),
        throwsA(
          isA<AgentApiException>()
              .having((e) => e.code, 'code', 'SNAPSHOT_REQUIRED')
              .having((e) => e.statusCode, 'status', 409)
              .having((e) => e.requestId, 'requestId', 'server-request'),
        ),
      );
    },
  );

  test(
    'SSE rejects non-event responses and preserves pre-connect cancellation',
    () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: ResponseBody.fromString('{}', 200),
                headers: Headers.fromMap({
                  'content-type': ['application/json'],
                }),
              ),
            );
          },
        ),
      );
      await expectLater(
        api.openSessionEvents(sessionId, cancelToken: CancelToken()),
        throwsA(isA<AgentApiException>()),
      );
      final token = CancelToken()..cancel();
      await expectLater(
        api.openSessionEvents(sessionId, cancelToken: token),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
    },
  );

  test(
    'session update rejects an empty 204 instead of assuming an authoritative revision',
    () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 204,
                headers: Headers.fromMap({
                  'x-request-id': ['server-request'],
                }),
              ),
            );
          },
        ),
      );
      await expectLater(
        api.updateSession(
          sessionId,
          clientRequestId: requestId,
          expectedRevision: 7,
          archived: true,
        ),
        throwsA(
          isA<AgentApiException>()
              .having((e) => e.code, 'code', 'INVALID_RESPONSE')
              .having((e) => e.requestId, 'requestId', 'server-request'),
        ),
      );
    },
  );
}
