import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/agent_api_exception.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/session/data/session_repository.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/assets/domain/library_work.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'conversation_events_test.dart' show chatId, chatDate, chatSnapshotJson;

void main() {
  late Dio dio;
  late PreferencesStorage storage;
  ApiSessionRepository repository() => ApiSessionRepository(
    NetworkAgentApi(dio),
    NetworkApi(dio),
    () => storage,
  );
  setUp(() async {
    dio = Dio();
    SharedPreferences.setMockInitialValues({});
    storage = PreferencesStorage(await SharedPreferences.getInstance());
  });
  tearDown(() => dio.close(force: true));

  for (final failure in ['timeout', 'server', 'pending', 'binding']) {
    test(
      'content entry recovers from $failure with the same request ID',
      () async {
        final commands = <Map<String, Object?>>[];
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              expect(options.path, '/api_agent/v2/sessions/content-entry');
              final command = Map<String, Object?>.from(options.data as Map);
              expect(command.keys, ['clientRequestId']);
              commands.add(command);
              if (commands.length == 1 && failure != 'binding') {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: failure == 'timeout'
                        ? DioExceptionType.receiveTimeout
                        : DioExceptionType.badResponse,
                    response: failure == 'timeout'
                        ? null
                        : Response(
                            requestOptions: options,
                            statusCode: failure == 'server' ? 503 : 409,
                            data: {
                              'code': failure == 'server'
                                  ? 'INTERNAL_ERROR'
                                  : 'COMMAND_PENDING',
                            },
                          ),
                  ),
                );
                return;
              }
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: {
                    'id': chatId,
                    'title': '新会话',
                    'revision': 1,
                    'bindingStatus': commands.length == 1 ? 'pending' : 'ready',
                    'updatedAt': chatDate,
                  },
                ),
              );
            },
          ),
        );
        await expectLater(
          repository().createFromContent('a'),
          throwsA(anything),
        );
        expect(storage.preferences.getKeys(), isNotEmpty);
        final session = await repository().createFromContent('a');
        expect(session.title, '新会话');
        expect(session.bindingStatus, 'ready');
        expect(commands[1], commands[0]);
        expect(storage.preferences.getKeys(), isEmpty);
        await repository().createFromContent('a');
        expect(
          commands[2]['clientRequestId'],
          isNot(commands[0]['clientRequestId']),
        );
      },
    );
  }

  test(
    'concurrent content entry calls share a request ID and users are isolated',
    () async {
      final requests = <(RequestOptions, RequestInterceptorHandler)>[];
      final bothStarted = Completer<void>();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add((options, handler));
            if (requests.length == 2) bothStarted.complete();
          },
        ),
      );
      final first = repository().createFromContent('a');
      final second = repository().createFromContent('a');
      await bothStarted.future;
      expect(requests[0].$1.data, requests[1].$1.data);
      for (final request in requests) {
        request.$2.reject(DioException(requestOptions: request.$1));
      }
      await Future.wait([
        expectLater(first, throwsA(isA<DioException>())),
        expectLater(second, throwsA(isA<DioException>())),
      ]);
      final thirdStarted = Completer<void>();
      dio.interceptors.clear();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.data, isNot(requests[0].$1.data));
            handler.reject(DioException(requestOptions: options));
            thirdStarted.complete();
          },
        ),
      );
      await expectLater(
        repository().createFromContent('b'),
        throwsA(isA<DioException>()),
      );
      await thirdStarted.future;
    },
  );

  test(
    'creation retries reuse the request ID across repository recreation',
    () async {
      final commands = <Map<String, Object?>>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, '/api_agent/v2/sessions');
            expect(options.method, 'POST');
            final command = Map<String, Object?>.from(options.data as Map);
            expect(command.keys, unorderedEquals(['clientRequestId', 'title']));
            expect(command['title'], 'New');
            commands.add(command);
            if (commands.length == 1) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionTimeout,
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 201,
                  data: {
                    'id': chatId,
                    'title': 'New',
                    'revision': 2,
                    'bindingStatus': 'ready',
                    'boundAccountId': '10',
                    'updatedAt': chatDate,
                  },
                ),
              );
            }
          },
        ),
      );
      await expectLater(
        repository().create('a', ' New '),
        throwsA(isA<DioException>()),
      );
      expect(storage.preferences.getKeys(), isNotEmpty);
      final session = await repository().create('a', ' New ');
      expect(session.id, chatId);
      expect(session.bindingStatus, 'ready');
      expect(commands[1], commands[0]);
      expect(storage.preferences.getKeys(), isEmpty);
    },
  );

  test(
    'an uncertain send persists exact input across repository recreation',
    () async {
      final commands = <Map<String, Object?>>[];
      final casts = <Map<String, Object?>>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.endsWith('/cast')) {
              expect(options.method, 'PUT');
              casts.add(Map<String, Object?>.from(options.data as Map));
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {'cast': [], 'runId': null},
                ),
              );
              return;
            }
            commands.add(Map<String, Object?>.from(options.data as Map));
            if (commands.length == 1) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionTimeout,
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 202,
                  data: {'runId': 'run'},
                ),
              );
            }
          },
        ),
      );
      await expectLater(
        repository().send('a', chatId, 'hello', ['801'], roleIds: ['2', '1']),
        throwsA(isA<DioException>()),
      );
      expect(
        storage.preferences.getKeys().any(
          (key) => key.startsWith('agent.command.a.'),
        ),
        isTrue,
      );
      await repository().send(
        'a',
        chatId,
        'hello',
        ['801'],
        roleIds: ['2', '1'],
      );
      expect(commands[1], commands[0]);
      expect(commands[1].containsKey('inputRefs'), isFalse);
      expect(casts[0], casts[1]);
      expect(casts[1], {
        'clientRequestId': commands[1]['clientRequestId'],
        'roleIds': [2, 1],
        'reply': false,
      });
      expect(storage.preferences.getKeys(), isEmpty);
      await repository().send(
        'a',
        chatId,
        'hello',
        ['801'],
        roleIds: ['2', '1'],
      );
      expect(
        commands[2]['clientRequestId'],
        isNot(commands[0]['clientRequestId']),
      );
    },
  );

  test('invalid role IDs cannot enter the message contract', () async {
    for (final id in ['invalid', '0', '-1', '9007199254740992']) {
      await expectLater(
        repository().send('a', chatId, 'hello', [], roleIds: [id]),
        throwsArgumentError,
      );
    }
    expect(storage.preferences.getKeys(), isEmpty);
  });

  test(
    'cast failure prevents sending and retries with the same request ID',
    () async {
      final requests = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            if (requests.length == 1) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                ),
              );
            } else {
              handler.resolve(
                Response(requestOptions: options, data: <String, dynamic>{}),
              );
            }
          },
        ),
      );
      await expectLater(
        repository().send('a', chatId, 'hello', [], roleIds: ['2']),
        throwsA(isA<DioException>()),
      );
      expect(requests.single.path, '/api_agent/v2/sessions/$chatId/cast');
      await repository().send('a', chatId, 'hello', [], roleIds: ['2']);
      expect(requests.map((request) => request.method), ['PUT', 'PUT', 'POST']);
      expect(requests[0].data, requests[1].data);
      expect(requests.last.path, '/api_agent/v2/sessions/$chatId/messages');
      expect(
        requests.last.data.keys,
        unorderedEquals(['clientRequestId', 'text', 'mediaIds']),
      );
    },
  );

  for (final refresh in [false, true]) {
    test(
      'conversation topic ${refresh ? 'refresh' : 'selection'} uses the session contract',
      () async {
        final requests = <RequestOptions>[];
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              if (requests.length == 1) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    type: DioExceptionType.receiveTimeout,
                  ),
                );
              } else {
                handler.resolve(
                  Response(requestOptions: options, data: {'snapshot': {}}),
                );
              }
            },
          ),
        );
        final topic = ConversationBlock.fromJson({
          'type': 'object',
          'kind': 'topic',
          'scope': {'kind': 'creation', 'id': '401'},
          'data': {'id': '701'},
        });
        await expectLater(
          repository().topicAction('a', chatId, topic, refresh: refresh),
          throwsA(isA<DioException>()),
        );
        await repository().topicAction('a', chatId, topic, refresh: refresh);
        expect(requests, hasLength(2));
        expect(requests.first.data, requests.last.data);
        expect(requests.last.method, refresh ? 'POST' : 'PUT');
        expect(
          requests.last.path,
          '/api_agent/v2/sessions/$chatId/${refresh ? 'topics' : 'topic'}',
        );
        expect(requests.last.data, {
          'clientRequestId': requests.first.data['clientRequestId'],
          if (refresh) 'mode': 'recommend' else 'topicId': '701',
        });
        expect(storage.preferences.getKeys(), isEmpty);
      },
    );
  }

  test(
    'update retries retain their input without loading a snapshot',
    () async {
      var snapshots = 0;
      final commands = <Map<String, Object?>>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.endsWith('/snapshot')) {
              snapshots++;
              handler.resolve(
                Response(requestOptions: options, data: chatSnapshotJson()),
              );
            } else {
              commands.add(Map<String, Object?>.from(options.data as Map));
              if (commands.length == 1) {
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
                    data: {
                      'id': chatId,
                      'title': 'renamed',
                      'revision': 2,
                      'updatedAt': chatDate,
                    },
                  ),
                );
              }
            }
          },
        ),
      );
      await expectLater(
        repository().update('a', chatId, title: 'renamed'),
        throwsA(isA<DioException>()),
      );
      expect(
        (await repository().update('a', chatId, title: 'renamed')).revision,
        2,
      );
      expect(snapshots, 0);
      expect(commands[0], commands[1]);
      expect(commands[1].keys, unorderedEquals(['clientRequestId', 'title']));
    },
  );

  test(
    'deletion retries reuse the persisted request ID after a timeout',
    () async {
      final commands = <Map<String, Object?>>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.method, 'DELETE');
            expect(options.path, '/api_agent/v2/sessions/$chatId');
            commands.add(Map<String, Object?>.from(options.data as Map));
            if (commands.length == 1) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.receiveTimeout,
                ),
              );
              return;
            }
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'id': chatId,
                  'title': 'Archived',
                  'archived': true,
                  'revision': 2,
                  'updatedAt': chatDate,
                },
              ),
            );
          },
        ),
      );
      await expectLater(
        repository().update('a', chatId, archived: true),
        throwsA(isA<DioException>()),
      );
      expect(storage.preferences.getKeys(), isNotEmpty);
      final session = await repository().update('a', chatId, archived: true);
      expect(session.archived, isTrue);
      expect(commands[0].keys, ['clientRequestId']);
      expect(commands[0]['clientRequestId'], isA<String>());
      expect(commands[1], commands[0]);
      expect(storage.preferences.getKeys(), isEmpty);
      await repository().update('a', chatId, archived: true);
      expect(
        commands[2]['clientRequestId'],
        isNot(commands[0]['clientRequestId']),
      );
    },
  );

  test(
    'commands are account scoped and definite failures clear recovery',
    () async {
      final ids = <String>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            ids.add((options.data as Map)['clientRequestId'] as String);
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 409,
                  data: {
                    'code': 'REVISION_CONFLICT',
                    'message': 'Refresh',
                    'retryable': false,
                  },
                ),
              ),
            );
          },
        ),
      );
      for (final user in ['a', 'b', 'a']) {
        await expectLater(
          repository().send(user, chatId, 'hello', []),
          throwsA(isA<AgentApiException>()),
        );
      }
      expect(ids.toSet().length, 3);
      expect(storage.preferences.getKeys(), isEmpty);
    },
  );

  test(
    'history requests one page of twenty and preserves server pagination',
    () async {
      final requests = <int>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final page = options.queryParameters['page'];
            requests.add(page as int);
            expect(options.queryParameters['pageSize'], 20);
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'list': [
                    {
                      'id': page == 1 ? 'new' : 'pinned',
                      'title': 'session',
                      'iconBackgroundColor': '#FEF2ED',
                      'revision': 1,
                      'updatedAt': chatDate,
                      'pinnedAt': page == 2 ? '2026-10-08T00:00:00Z' : null,
                    },
                  ],
                  'pageInfo': {
                    'page': page,
                    'pageSize': 20,
                    'pageCount': 2,
                    'total': 2,
                  },
                },
              ),
            );
          },
        ),
      );
      final first = await repository().list('a');
      expect(first.items.single.id, 'new');
      expect(first.items.single.iconBackgroundColor, '#FEF2ED');
      expect(first.page, 1);
      expect(first.hasMore, isTrue);
      expect(requests, [1]);
      final second = await repository().list('a', page: 2);
      expect(second.items.single.id, 'pinned');
      expect(second.hasMore, isFalse);
      expect(requests, [1, 2]);
    },
  );

  test(
    'history keeps server row order and parses interaction and creation time',
    () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'list': [
                    for (final id in ['a', 'z'])
                      {
                        'id': id,
                        'title': id,
                        'revision': 1,
                        'createdAt': chatDate,
                        'lastMessageAt': id == 'a'
                            ? null
                            : '2026-10-16T12:00:00Z',
                        'updatedAt': chatDate,
                      },
                  ],
                  'pageInfo': {
                    'page': 1,
                    'pageSize': 20,
                    'pageCount': 1,
                    'total': 2,
                  },
                },
              ),
            );
          },
        ),
      );
      final result = await repository().list('a');
      expect(result.items.map((s) => s.id), ['a', 'z']);
      expect(result.items.first.createdAt, DateTime.parse(chatDate));
      expect(result.items.first.lastMessageAt, isNull);
      expect(
        result.items.last.lastMessageAt,
        DateTime.parse('2026-10-16T12:00:00Z'),
      );
    },
  );

  test(
    'question answers match the Web contract and generation is confirmed before the Agent card',
    () async {
      final paths = <String>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            paths.add(options.path);
            if (options.path.contains('/questions/')) {
              expect(options.data, {
                'revision': 3,
                'action': 'submit',
                'answer': {'topic': 'Travel'},
              });
            }
            if (options.path.startsWith('/api_client/')) {
              expect(options.data, {
                'clientRequestId': 'business-command',
                'maxEstimatedPoints': 50,
              });
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'status': '0000',
                    'data': {'id': 'task'},
                  },
                ),
              );
            } else {
              handler.resolve(
                Response(requestOptions: options, data: {'ok': true}),
              );
            }
          },
        ),
      );
      final question = ConversationBlock.fromJson({
        'type': 'object',
        'kind': 'question',
        'data': {'id': 'question', 'revision': 3},
      });
      await repository().answer(chatId, question, 'submit', {
        'topic': 'Travel',
      });
      final card = ConversationBlock.fromJson({
        'type': 'object',
        'kind': 'plan',
        'data': {
          'id': 'card',
          'revision': 4,
          'kind': 'generation',
          'status': 'ready',
          'allowedActions': ['confirm', 'cancel'],
          'request': {
            'method': 'POST',
            'path': '/api_client/agent/v2/generation/confirmations',
            'body': {
              'clientRequestId': 'business-command',
              'maxEstimatedPoints': 50,
            },
          },
        },
      });
      await repository().confirm('a', chatId, card, 'confirm');
      expect(paths, [
        '/api_agent/v2/sessions/$chatId/questions/question/respond',
        '/api_client/agent/v2/generation/confirmations',
        '/api_agent/v2/sessions/$chatId/confirmations/card/respond',
      ]);
      await repository().confirm('a', chatId, card, 'cancel');
      expect(
        paths.last,
        '/api_agent/v2/sessions/$chatId/confirmations/card/respond',
      );
      expect(paths.where((path) => path.startsWith('/api_client/')).length, 1);
      expect(
        () => NetworkApi(
          dio,
        ).confirmStudioGeneration('https://untrusted.example/action', {}),
        throwsA(isA<Exception>()),
      );
    },
  );

  test(
    'images use the signed upload contract without leaking auth and retain media IDs for send retries',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      var uploads = 0;
      final subscription = server.listen((request) async {
        uploads++;
        expect(request.method, 'PUT');
        expect(request.headers.value('authorization'), isNull);
        expect(request.headers.value('x-upload-token'), 'signed');
        expect(
          await request.fold<List<int>>([], (all, part) => all..addAll(part)),
          bytes,
        );
        request.response.statusCode = 200;
        await request.response.close();
      });
      addTearDown(subscription.cancel);
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.endsWith('/complete')) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'status': '0000',
                    'data': {'mediaId': '801'},
                  },
                ),
              );
            } else {
              final input = options.data as Map;
              expect(input['mime'], 'image/png');
              expect(input['size'], bytes.length);
              expect((input['hash'] as String).length, 64);
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'status': '0000',
                    'data': {
                      'upload': {'id': '701'},
                      'uploadUrl': 'http://127.0.0.1:${server.port}/upload',
                      'uploadHeaders': {
                        'x-upload-token': 'signed',
                        'Content-Type': 'image/png',
                      },
                    },
                  },
                ),
              );
            }
          },
        ),
      );
      final progress = <(int, int)>[];
      expect(
        await repository().upload(
          'a',
          'reference.png',
          bytes,
          onSendProgress: (sent, total) => progress.add((sent, total)),
        ),
        '801',
      );
      expect(progress, isNotEmpty);
      expect(progress.last, (bytes.length, bytes.length));
      expect(await repository().upload('a', 'reference.png', bytes), '801');
      expect(uploads, 1);
    },
  );

  for (final isVideo in [false, true]) {
    test(
      'library ${isVideo ? 'video' : 'image'} registers source media and reuses its ID',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final source =
            'http://127.0.0.1:${server.port}/source.${isVideo ? 'mp4' : 'png'}';
        final bytes = Uint8List.fromList(
          isVideo
              ? [0, 0, 0, 24, 102, 116, 121, 112, 105, 115, 111, 109]
              : [137, 80, 78, 71, 13, 10, 26, 10],
        );
        var downloads = 0;
        var uploads = 0;
        final subscription = server.listen((request) async {
          expect(request.headers.value('authorization'), isNull);
          if (request.method == 'GET') {
            downloads++;
            expect(request.uri.path, Uri.parse(source).path);
            request.response.add(bytes);
          } else {
            uploads++;
            expect(
              await request.fold<List<int>>(
                [],
                (all, part) => all..addAll(part),
              ),
              bytes,
            );
          }
          await request.response.close();
        });
        addTearDown(subscription.cancel);
        dio.options.headers['Authorization'] = 'Bearer private';
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              final complete = request.path.endsWith('/complete');
              if (!complete) {
                expect(
                  (request.data as Map)['mime'],
                  isVideo ? 'video/mp4' : 'image/png',
                );
              }
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: {
                    'status': '0000',
                    'data': complete
                        ? {'mediaId': '801'}
                        : {
                            'upload': {'id': '701'},
                            'uploadUrl':
                                'http://127.0.0.1:${server.port}/upload',
                            'uploadHeaders': {
                              'Content-Type': isVideo
                                  ? 'video/mp4'
                                  : 'image/png',
                            },
                          },
                  },
                ),
              );
            },
          ),
        );
        final work = LibraryWork(
          id: '42',
          previewUrl: isVideo ? 'https://example.test/cover.png' : source,
          isVideo: isVideo,
          videoUrl: isVideo ? source : '',
          createdAt: null,
        );
        expect(await repository().importLibraryWork('a', work), '801');
        expect(await repository().importLibraryWork('a', work), '801');
        expect(downloads, 1);
        expect(uploads, 1);
        expect(await repository().importLibraryWork('b', work), '801');
        expect(downloads, 2);
        expect(uploads, 2);
      },
    );
  }
}
