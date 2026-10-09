import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/features/projects/data/project_repository.dart';

void main() {
  final studioRequestId = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
  test('creates an account session with the Web resolve contract', () async {
    final dio = Dio();
    late RequestOptions request;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'id': 'created',
                'title': 'New conversation',
                'contextRef': {'kind': 'account', 'id': 'project / 1'},
              },
            ),
          );
        },
      ),
    );
    final requestId = ProjectRepository.createClientRequestId();
    final session =
        await ProjectRepository(
          NetworkApi(dio),
          NetworkAgentApi(dio),
        ).createSession(
          'project / 1',
          ' New conversation ',
          clientRequestId: requestId,
        );
    expect(request.method, 'POST');
    expect(request.path, '/api_agent/v2/sessions/resolve');
    expect(request.data, {
      'clientRequestId': requestId,
      'mode': 'new',
      'title': 'New conversation',
      'contextRef': {'kind': 'account', 'id': 'project / 1'},
    });
    expect(session.id, 'created');
    expect(request.data['clientRequestId'], matches(studioRequestId));
    expect(session.title, 'New conversation');
  });

  test('rejects a created session with missing identity', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(requestOptions: options, data: {'title': 'New'}),
          );
        },
      ),
    );
    await expectLater(
      ProjectRepository(
        NetworkApi(dio),
        NetworkAgentApi(dio),
      ).createSession('p', 'New', clientRequestId: 'key'),
      throwsA(isA<ApiException>()),
    );
  });

  test('preserves the session creation backend error', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 403,
                data: {'message': 'Project is archived'},
              ),
            ),
          );
        },
      ),
    );
    await expectLater(
      ProjectRepository(
        NetworkApi(dio),
        NetworkAgentApi(dio),
      ).createSession('p', 'New', clientRequestId: 'key'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Project is archived',
        ),
      ),
    );
  });

  for (final project in [true, false]) {
    final changes = project
        ? [
            {'title': 'Renamed'},
            {'action': 'archive'},
          ]
        : [
            {'title': 'Renamed'},
            {'archived': true},
            {'pinned': true},
            {'pinned': false},
          ];
    for (final change in changes) {
      test(
        '${project ? 'project' : 'session'} $change follows Web revision contract',
        () async {
          final requests = <RequestOptions>[];
          final dio = Dio();
          dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                requests.add(options);
                final value = {
                  'id': 'id / 1',
                  'title': 'Original',
                  'revision': 7,
                };
                handler.resolve(
                  Response(
                    requestOptions: options,
                    data: project
                        ? {'data': value}
                        : options.method == 'GET'
                        ? {'session': value}
                        : value,
                  ),
                );
              },
            ),
          );
          final repository = ProjectRepository(
            NetworkApi(dio),
            NetworkAgentApi(dio),
          );
          if (project) {
            if (change.containsKey('title')) {
              await repository.renameProject('id / 1', ' Renamed ');
            } else {
              await repository.deleteProject('id / 1');
            }
          } else if (change.containsKey('title')) {
            await repository.renameSession('id / 1', ' Renamed ');
          } else if (change.containsKey('archived')) {
            await repository.deleteSession('id / 1');
          } else {
            await repository.setSessionPinned(
              'id / 1',
              change['pinned'] as bool,
            );
          }
          final path =
              '${project ? '/api_client/agent/v2/accounts' : '/api_agent/v2/sessions'}/id%20%2F%201';
          expect(requests.map((request) => request.method), ['GET', 'PATCH']);
          expect(requests.first.path, project ? path : '$path/snapshot');
          expect(requests.last.path, path);
          final body = requests.last.data as Map<String, dynamic>;
          expect(body['clientRequestId'], matches(studioRequestId));
          expect(body, {
            'clientRequestId': body['clientRequestId'],
            'expectedRevision': 7,
            ...change,
          });
        },
      );
    }
  }

  for (final project in [true, false]) {
    for (final revision in [null, 0, -1]) {
      test(
        '${project ? 'project' : 'session'} revision $revision cannot mutate',
        () async {
          final requests = <RequestOptions>[];
          final dio = Dio();
          dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) {
                requests.add(options);
                handler.resolve(
                  Response(
                    requestOptions: options,
                    data: {
                      project ? 'data' : 'session': {
                        'id': '1',
                        if (revision != null) 'revision': revision,
                      },
                    },
                  ),
                );
              },
            ),
          );
          await expectLater(
            project
                ? ProjectRepository(
                    NetworkApi(dio),
                    NetworkAgentApi(dio),
                  ).deleteProject('1')
                : ProjectRepository(
                    NetworkApi(dio),
                    NetworkAgentApi(dio),
                  ).deleteSession('1'),
            throwsA(isA<ApiException>()),
          );
          expect(requests.map((request) => request.method), ['GET']);
        },
      );
    }
  }

  test('preserves backend conflict message for retry', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.method == 'GET') {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'session': {'revision': 1},
                },
              ),
            );
          } else {
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 409,
                  data: {
                    'code': 'REVISION_CONFLICT',
                    'message': 'Changed elsewhere',
                  },
                ),
              ),
            );
          }
        },
      ),
    );
    await expectLater(
      ProjectRepository(
        NetworkApi(dio),
        NetworkAgentApi(dio),
      ).setSessionPinned('1', true),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'status', 409)
            .having((error) => error.message, 'message', 'Changed elsewhere'),
      ),
    );
  });

  test('validates trimmed names with the Web 200-code-point limit', () async {
    final dio = Dio();
    var requests = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests++;
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'data': {'revision': 1},
              },
            ),
          );
        },
      ),
    );
    final repository = ProjectRepository(NetworkApi(dio), NetworkAgentApi(dio));
    for (final title in [
      '   ',
      List.filled(201, 'a').join(),
      List.filled(201, '😀').join(),
    ]) {
      await expectLater(
        repository.renameProject('1', title),
        throwsA(isA<ApiException>()),
      );
      await expectLater(
        repository.renameSession('1', title),
        throwsA(isA<ApiException>()),
      );
    }
    expect(requests, 0);
    await repository.renameProject('1', List.filled(200, '😀').join());
    expect(requests, 2);
  });
}
