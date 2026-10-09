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

  test(
    'an uncertain send persists exact input across repository recreation',
    () async {
      final commands = <Map<String, Object?>>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
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
        repository().send('a', chatId, 'hello', ['801']),
        throwsA(isA<DioException>()),
      );
      expect(
        storage.preferences.getKeys().any(
          (key) => key.startsWith('agent.command.a.'),
        ),
        isTrue,
      );
      await repository().send('a', chatId, 'hello', ['801']);
      expect(commands[1], commands[0]);
      expect(storage.preferences.getKeys(), isEmpty);
      await repository().send('a', chatId, 'hello', ['801']);
      expect(
        commands[2]['clientRequestId'],
        isNot(commands[0]['clientRequestId']),
      );
    },
  );

  test(
    'update retry keeps the original revision instead of loading a newer snapshot',
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
      expect(snapshots, 1);
      expect(commands[0], commands[1]);
      expect(commands[1]['expectedRevision'], 1);
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
    'all pages are fetched, deduplicated, and sorted before exposing history',
    () async {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final page = options.queryParameters['page'];
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'list': [
                    {
                      'id': page == 1 ? 'new' : 'pinned',
                      'title': 'session',
                      'revision': 1,
                      'updatedAt': chatDate,
                      'pinnedAt': page == 2 ? '2026-10-08T00:00:00Z' : null,
                    },
                  ],
                  'pageInfo': {
                    'page': page,
                    'pageSize': 100,
                    'pageCount': 2,
                    'total': 2,
                  },
                },
              ),
            );
          },
        ),
      );
      expect((await repository().list('a')).map((item) => item.id), [
        'pinned',
        'new',
      ]);
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
      expect(await repository().upload('a', 'reference.png', bytes), '801');
      expect(await repository().upload('a', 'reference.png', bytes), '801');
      expect(uploads, 1);
    },
  );
}
