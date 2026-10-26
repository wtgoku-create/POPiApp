import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/agent_api_exception.dart';
import 'package:popi_ai_app/core/network/auth_interceptor.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/core/storage/secure_storage.dart';
import 'package:popi_ai_app/features/role_guide/domain/home_creation.dart';
import 'package:popi_ai_app/features/session/data/conversation_events.dart';
import 'package:popi_ai_app/features/session/data/session_repository.dart';
import 'package:popi_ai_app/features/session/domain/conversation_generation.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'conversation_events_test.dart'
    show chatDate, chatId, chatMessageJson, chatSnapshotJson;

Map<String, Object?> runtimeSnapshot({int seq = 0, String title = 'Runtime'}) =>
    {
      ...chatSnapshotJson(seq: seq),
      'session': {
        'id': chatId,
        'title': title,
        'revision': 1,
        'updatedAt': chatDate,
        'runtimeDirect': true,
        'defaultBot': {'displayName': 'Studio assistant'},
      },
      'messages': [],
    };

ConversationBlock runtimeCard() => ConversationBlock.fromJson({
  'type': 'object',
  'kind': 'plan',
  'data': {
    'id': 'card',
    'kind': 'generation',
    'runtimeDirect': true,
    'revision': 1,
    'status': 'ready',
    'allowedActions': ['confirm', 'cancel'],
    'planVersionId': 'v1',
    'planHash': 'hash1',
  },
});

const selection = ConversationGenerationSelection(
  config: HomeConfig(modelId: 'image', params: {'ratio': '1:1'}),
  estimatedPoints: 10,
  mediaPreferencesRevision: 7,
);

class _MemoryTokens implements TokenStorage {
  String? token = 'account';

  @override
  Future<String?> readAccessToken() async => token;

  @override
  Future<void> writeAccessToken(String value) async => token = value;

  @override
  Future<void> deleteAccessToken() async => token = null;
}

void main() {
  late Dio account;
  late _MemoryTokens tokens;
  late NetworkAgentApi api;
  late PreferencesStorage storage;
  late List<RequestOptions> accountCalls;
  late List<RequestOptions> runtimeCalls;

  ApiSessionRepository repository() =>
      ApiSessionRepository(api, NetworkApi(account), () => storage);

  void resolve(
    RequestInterceptorHandler handler,
    RequestOptions request,
    Object? data, {
    int status = 200,
  }) => handler.resolve(
    Response(requestOptions: request, data: data, statusCode: status),
  );

  setUp(() async {
    accountCalls = [];
    runtimeCalls = [];
    account = Dio(
      BaseOptions(
        baseUrl: 'https://gateway.example',
        headers: {'Origin': 'https://app.example'},
      ),
    );
    tokens = _MemoryTokens();
    account.interceptors.add(AuthInterceptor(tokens));
    api = NetworkAgentApi(account);
    SharedPreferences.setMockInitialValues({});
    storage = PreferencesStorage(await SharedPreferences.getInstance());
    account.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          if (request.path.startsWith('/runtime/')) {
            runtimeCalls.add(request);
          } else {
            accountCalls.add(request);
          }
          if (request.path.endsWith('/snapshot')) {
            resolve(handler, request, runtimeSnapshot());
          } else {
            resolve(handler, request, {'ok': true});
          }
        },
      ),
    );
  });

  tearDown(() {
    api.close();
    account.close(force: true);
  });

  test(
    'discovered sessions use fixed Runtime routes with login credentials; ordinary sessions retain their route',
    () async {
      final snapshot = await repository().snapshot(chatId);
      expect(snapshot.session.runtimeDirect, isTrue);
      expect(snapshot.session.assistantName, 'Studio assistant');
      await repository().send('user', chatId, 'hello', ['media']);
      await repository().stop('user', chatId);
      await repository().retry('user', 'execution/a', sessionId: chatId);
      await repository().answer(
        chatId,
        ConversationBlock.fromJson({
          'type': 'object',
          'kind': 'question',
          'data': {'id': 'question/a', 'revision': 2},
        }),
        'submit',
        {'answer': 'yes'},
      );
      expect(accountCalls.map((request) => request.path), [
        '/api_agent/v2/sessions/$chatId/snapshot',
      ]);
      expect(runtimeCalls.map((request) => request.uri.path), [
        '/runtime/v2/sessions/$chatId/snapshot',
        '/runtime/v2/sessions/$chatId/messages',
        '/runtime/v2/sessions/$chatId/stop',
        '/runtime/v2/sessions/$chatId/executions/execution%2Fa/retry',
        '/runtime/v2/sessions/$chatId/interactions/question%2Fa/respond',
      ]);
      for (final request in runtimeCalls) {
        expect(request.headers['Authorization'], 'Bearer account');
        expect(request.uri.origin, 'https://gateway.example');
        expect(request.headers['Origin'], 'https://app.example');
        expect(request.followRedirects, isFalse);
        if (request.data is Map) {
          expect((request.data as Map)['clientRequestId'], isA<String>());
        }
      }
      expect(storage.preferences.getKeys(), isEmpty);
      await api.sendSessionMessage(
        'ordinary',
        clientRequestId: 'id',
        text: 'hi',
      );
      expect(
        accountCalls.last.path,
        '/api_agent/v2/sessions/ordinary/messages',
      );
    },
  );

  test(
    'Runtime requests read the current login token without acquiring grants',
    () async {
      await repository().snapshot(chatId);
      await tokens.writeAccessToken('updated-account');
      await repository().snapshot(chatId);
      expect(
        runtimeCalls.last.headers['Authorization'],
        'Bearer updated-account',
      );
      expect(accountCalls, hasLength(1));
      expect(runtimeCalls, hasLength(2));
    },
  );

  test(
    'Runtime errors are preserved without automatically replaying mutations',
    () async {
      api.runtime.remember(
        Map<String, dynamic>.from(runtimeSnapshot()['session'] as Map),
      );
      account.interceptors.removeLast();
      var reject = true;
      final commands = <Object?>[];
      account.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            commands.add(request.data);
            if (reject) {
              handler.reject(
                DioException(
                  requestOptions: request,
                  type: DioExceptionType.badResponse,
                  response: Response(
                    requestOptions: request,
                    statusCode: 401,
                    data: {'code': 'UNAUTHORIZED'},
                  ),
                ),
              );
            } else {
              resolve(handler, request, {'ok': true});
            }
          },
        ),
      );
      await expectLater(
        repository().send('user', chatId, 'hello', []),
        throwsA(isA<AgentApiException>()),
      );
      expect(commands, hasLength(1));
      reject = false;
      await repository().send('user', chatId, 'hello', []);
      expect(commands, hasLength(2));
      expect(accountCalls, isEmpty);
    },
  );

  test(
    'snapshot and SSE reject another session while complete snapshots can skip sequence numbers',
    () async {
      final next = {
        ...runtimeSnapshot(seq: 20),
        'timelineMessages': [chatMessageJson(text: '完整回复')],
      };
      final bytes = utf8.encode(
        '\uFEFF: heartbeat\r\nevent: conversation\r\ndata: ${jsonEncode(next)}\r\n\r\n',
      );
      final events = await decodeConversationEvents(
        Stream.fromIterable(bytes.map((byte) => [byte])),
        runtimeSessionId: chatId,
      ).toList();
      var snapshot = ConversationSnapshot.fromJson(runtimeSnapshot(seq: 2));
      snapshot = applyConversationEvent(snapshot, events.single);
      expect(snapshot.lastSeq, 20);
      expect(snapshot.messages.single.text, '完整回复');
      final duplicate = applyConversationEvent(snapshot, events.single);
      expect(identical(snapshot, duplicate), isTrue);
      final stale = ConversationEvent.fromJson({
        'sessionId': chatId,
        'seq': 3,
        'type': 'runtime.conversation',
        'payload': {'snapshot': runtimeSnapshot(seq: 3)},
      });
      expect(
        identical(snapshot, applyConversationEvent(snapshot, stale)),
        isTrue,
      );
      final foreign = {
        ...next,
        'session': {...next['session'] as Map, 'id': 'other'},
      };
      await expectLater(
        decodeConversationEvents(
          Stream.value(
            utf8.encode(
              'event: conversation\ndata: ${jsonEncode(foreign)}\n\n',
            ),
          ),
          runtimeSessionId: chatId,
        ).toList(),
        throwsA(isA<AgentApiException>()),
      );
      await expectLater(
        decodeConversationEvents(
          Stream.value(
            utf8.encode('event: message\ndata: ${jsonEncode(next)}\n\n'),
          ),
          runtimeSessionId: chatId,
        ).toList(),
        throwsA(isA<AgentApiException>()),
      );
    },
  );

  for (final lost in ['configuration', 'respond']) {
    test(
      'direct confirmation restores the exact selection and plan after lost $lost response',
      () async {
        final calls = <({String path, Map<String, Object?> body})>[];
        var fail = true;
        account.interceptors.clear();
        account.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              calls.add((
                path: request.path,
                body: Map<String, Object?>.from(request.data as Map),
              ));
              if (request.path.endsWith('/$lost') && fail) {
                fail = false;
                handler.reject(
                  DioException(
                    requestOptions: request,
                    type: DioExceptionType.receiveTimeout,
                  ),
                );
              } else {
                resolve(handler, request, {
                  'confirmation': {
                    ...runtimeCard().data,
                    'revision': 2,
                    'planVersionId': 'v2',
                    'planHash': 'hash2',
                  },
                });
              }
            },
          ),
        );
        await expectLater(
          repository().confirmGeneration(
            'user',
            chatId,
            runtimeCard(),
            selection,
          ),
          throwsA(isA<DioException>()),
        );
        final recovered = ApiSessionRepository(
          NetworkAgentApi(account),
          NetworkApi(account),
          () => storage,
        );
        await recovered.confirmGeneration(
          'user',
          chatId,
          runtimeCard(),
          const ConversationGenerationSelection(
            config: HomeConfig(modelId: 'different', params: {}),
            estimatedPoints: 100,
            mediaPreferencesRevision: 99,
          ),
        );
        expect(
          calls.every((call) => call.path.startsWith('/api_agent/')),
          isTrue,
        );
        final configurations = calls
            .where((call) => call.path.endsWith('/configuration'))
            .toList();
        expect(configurations, hasLength(lost == 'configuration' ? 2 : 1));
        expect(configurations.first.body['modelId'], 'image');
        if (lost == 'configuration') {
          expect(configurations[0].path, configurations[1].path);
          expect(configurations[0].body, configurations[1].body);
        }
        final responses = calls
            .where((call) => call.path.endsWith('/respond'))
            .toList();
        expect(responses.last.body, {
          'clientRequestId': responses.first.body['clientRequestId'],
          'revision': 2,
          'action': 'confirm',
          'planVersionId': 'v2',
          'planHash': 'hash2',
          'mediaPreferencesRevision': 7,
        });
        if (lost == 'respond') {
          expect(responses[0].path, responses[1].path);
          expect(responses[0].body, responses[1].body);
        }
        expect(storage.preferences.getKeys(), isEmpty);
      },
    );
  }

  test(
    'direct cancellation sends the saved plan without business authorization or configuration',
    () async {
      await repository().confirm('user', chatId, runtimeCard(), 'cancel');
      expect(accountCalls, hasLength(1));
      expect(
        accountCalls.single.path,
        '/api_agent/v2/sessions/$chatId/confirmations/card/respond',
      );
      expect(accountCalls.single.data, containsPair('planVersionId', 'v1'));
      expect(accountCalls.single.data, containsPair('planHash', 'hash1'));
      expect(storage.preferences.getKeys(), isEmpty);
      for (final state in ['approved', 'submitting', 'confirmed']) {
        final card = ConversationBlock.fromJson({
          'type': 'object',
          'kind': 'plan',
          'data': {...runtimeCard().data, 'status': state},
        });
        expect(card.confirmationAvailable, isFalse);
      }
    },
  );

  for (final retryable in [false, true]) {
    test(
      'direct confirmation ${retryable ? 'retains' : 'clears'} recovery after an explicit rejection',
      () async {
        final calls = <Map<String, Object?>>[];
        var reject = true;
        account.interceptors.clear();
        account.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              calls.add(Map<String, Object?>.from(request.data as Map));
              if (request.path.endsWith('/respond') && reject) {
                handler.reject(
                  DioException(
                    requestOptions: request,
                    type: DioExceptionType.badResponse,
                    response: Response(
                      requestOptions: request,
                      statusCode: retryable ? 429 : 409,
                      data: {
                        'code': retryable
                            ? 'BUSY'
                            : 'MEDIA_PREFERENCES_CHANGED',
                        'retryable': retryable,
                      },
                    ),
                  ),
                );
              } else {
                resolve(handler, request, {
                  'confirmation': {
                    ...runtimeCard().data,
                    'revision': 2,
                    'planVersionId': 'v2',
                    'planHash': 'hash2',
                  },
                });
              }
            },
          ),
        );
        await expectLater(
          repository().confirmGeneration(
            'user',
            chatId,
            runtimeCard(),
            selection,
          ),
          throwsA(isA<AgentApiException>()),
        );
        expect(storage.preferences.getKeys().isNotEmpty, retryable);
        reject = false;
        await repository().confirmGeneration(
          'user',
          chatId,
          runtimeCard(),
          selection,
        );
        if (retryable) {
          expect(calls, hasLength(3));
          expect(calls[1], calls[2]);
        } else {
          expect(calls, hasLength(4));
          expect(
            calls[0]['clientRequestId'],
            isNot(calls[2]['clientRequestId']),
          );
        }
        expect(storage.preferences.getKeys(), isEmpty);
      },
    );
  }

  test(
    'canceled or disposed Runtime requests do not reach the transport',
    () async {
      api.runtime.remember(
        Map<String, dynamic>.from(runtimeSnapshot()['session'] as Map),
      );
      final token = CancelToken()..cancel();
      await expectLater(
        api.sendSessionMessage(
          chatId,
          clientRequestId: 'pending',
          text: 'hello',
          cancelToken: token,
        ),
        throwsA(
          isA<DioException>().having(
            (error) => error.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      api.close();
      await expectLater(
        api.sendSessionMessage(chatId, clientRequestId: 'late', text: 'hello'),
        throwsStateError,
      );
      expect(runtimeCalls, isEmpty);
      // Disposing session routing must not close the shared account Dio.
      await account.get<Object?>('/health');
      expect(accountCalls.single.path, '/health');
    },
  );

  test(
    'unnamed and role entries omit titles; explicit titles remain intact',
    () async {
      account.interceptors.clear();
      account.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            accountCalls.add(request);
            resolve(
              handler,
              request,
              runtimeSnapshot()['session'],
              status: 201,
            );
          },
        ),
      );
      await repository().create('user', null);
      await api.createSession(clientRequestId: 'role', entry: 'role');
      await repository().create('user', 'Custom title');
      expect(accountCalls[0].data, isNot(contains('title')));
      expect(accountCalls[1].data, {
        'clientRequestId': 'role',
        'entry': 'role',
      });
      expect(accountCalls[2].data, containsPair('title', 'Custom title'));
    },
  );

  test(
    'text artifacts use unified category filtering and preserve saved version fields',
    () async {
      account.interceptors.clear();
      account.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            expect(
              request.path,
              '/api_client/agent/v2/sessions/session%2Fa/artifacts',
            );
            expect(request.queryParameters, {
              'page': 2,
              'pageSize': 100,
              'category': 'text',
            });
            resolve(handler, request, {
              'status': '0000',
              'data': {
                'list': [
                  {
                    'category': 'text',
                    'text': {
                      'id': 'draft',
                      'version': 2,
                      'parentId': 'previous',
                      'content': 'Saved text',
                    },
                  },
                ],
                'pageInfo': {'page': 2, 'pageCount': 2},
              },
            });
          },
        ),
      );
      final result = await NetworkApi(
        account,
      ).sessionTextArtifactsPage('session/a', page: 2);
      expect(result['list'], [
        {
          'id': 'draft',
          'version': 2,
          'parentId': 'previous',
          'content': 'Saved text',
        },
      ]);
    },
  );

  test(
    'local Go and PI Host services use separate addresses with shared login and Origin',
    () async {
      final go = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => go.close(force: true));
      final host = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => host.close(force: true));
      final goPaths = <String>[];
      final hostPaths = <String>[];
      for (final server in [go, host]) {
        final subscription = server.listen((request) async {
          expect(request.headers.value('authorization'), 'Bearer account');
          expect(request.headers.value('origin'), 'http://localhost:5195');
          (server == go ? goPaths : hostPaths).add(request.uri.path);
          if (request.uri.path.endsWith('/events')) {
            request.response.headers.contentType = ContentType(
              'text',
              'event-stream',
            );
            request.response.write(
              'event: conversation\ndata: ${jsonEncode(runtimeSnapshot(seq: 5))}\n\n',
            );
          } else {
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode(
                request.uri.path.endsWith('/snapshot')
                    ? runtimeSnapshot(seq: server == go ? 0 : 3)
                    : {'ok': true},
              ),
            );
          }
          await request.response.close();
        });
        addTearDown(subscription.cancel);
      }
      Dio transport(HttpServer server) => Dio(
        BaseOptions(
          baseUrl: 'http://127.0.0.1:${server.port}',
          headers: {'Origin': 'http://localhost:5195'},
        ),
      )..interceptors.add(AuthInterceptor(tokens));
      final goDio = transport(go);
      final hostDio = transport(host);
      addTearDown(() => goDio.close(force: true));
      addTearDown(() => hostDio.close(force: true));
      final localApi = NetworkAgentApi(goDio, runtimeDio: hostDio);
      addTearDown(localApi.close);
      expect((await localApi.sessionSnapshot(chatId))['lastSeq'], 3);
      await localApi.sendSessionMessage(
        chatId,
        clientRequestId: 'id',
        text: 'hi',
      );
      final stream = await localApi.openSessionEvents(
        chatId,
        afterSeq: 3,
        cancelToken: CancelToken(),
      );
      final events = await decodeConversationEvents(
        stream.stream,
        runtimeSessionId: chatId,
      ).toList();
      expect(events.single.seq, 5);
      await localApi.respondConfirmation(
        chatId,
        'card',
        clientRequestId: 'cancel',
        revision: 1,
        action: 'cancel',
      );
      await localApi.sendSessionMessage(
        'ordinary',
        clientRequestId: 'other',
        text: 'hi',
      );
      expect(goPaths, [
        '/api_agent/v2/sessions/$chatId/snapshot',
        '/api_agent/v2/sessions/$chatId/confirmations/card/respond',
        '/api_agent/v2/sessions/ordinary/messages',
      ]);
      expect(hostPaths, [
        '/runtime/v2/sessions/$chatId/snapshot',
        '/runtime/v2/sessions/$chatId/messages',
        '/runtime/v2/sessions/$chatId/events',
      ]);
    },
  );

  test(
    'native transport reads real SSE with login credentials at the configured gateway',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <String>[];
      unawaited(
        server.forEach((request) async {
          requests.add(request.uri.path);
          expect(request.headers.value('authorization'), 'Bearer account');
          expect(request.headers.value('cookie'), isNull);
          if (request.uri.path.endsWith('/events')) {
            request.response.headers.contentType = ContentType(
              'text',
              'event-stream',
              charset: 'utf-8',
            );
            request.response.write(
              'event: conversation\ndata: ${jsonEncode(runtimeSnapshot(seq: 9))}\n\n',
            );
          } else {
            request.response.statusCode = 307;
            request.response.headers.set('location', '/must-not-follow');
          }
          await request.response.close();
        }),
      );
      final nativeDio = Dio(
        BaseOptions(baseUrl: 'http://127.0.0.1:${server.port}'),
      )..interceptors.add(AuthInterceptor(tokens));
      final native = NetworkAgentApi(nativeDio);
      addTearDown(() async {
        native.close();
        nativeDio.close(force: true);
        await server.close(force: true);
      });
      native.runtime.remember(
        Map<String, dynamic>.from(runtimeSnapshot()['session'] as Map),
      );
      final body = await native.openSessionEvents(
        chatId,
        afterSeq: 999,
        cancelToken: CancelToken(),
      );
      final events = await decodeConversationEvents(
        body.stream,
        runtimeSessionId: chatId,
      ).toList();
      expect(events.single.seq, 9);
      await expectLater(
        native.sendSessionMessage(chatId, clientRequestId: 'send', text: 'hi'),
        throwsA(isA<AgentApiException>()),
      );
      expect(requests, [
        '/runtime/v2/sessions/$chatId/events',
        '/runtime/v2/sessions/$chatId/messages',
      ]);
    },
  );
}
