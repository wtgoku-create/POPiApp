import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/features/projects/data/project_api.dart';
import 'package:popi_ai_app/features/projects/data/project_repository.dart';

void main() {
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
    final session = await ProjectRepository(ProjectApi(dio)).createSession(
      'project / 1',
      ' New conversation ',
      clientRequestId: 'retry-key',
    );
    expect(request.method, 'POST');
    expect(request.path, '/api_agent/v2/sessions/resolve');
    expect(request.data, {
      'clientRequestId': 'retry-key',
      'mode': 'new',
      'title': 'New conversation',
      'contextRef': {'kind': 'account', 'id': 'project / 1'},
    });
    expect(session.id, 'created');
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
        ProjectApi(dio),
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
        ProjectApi(dio),
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
          final repository = ProjectRepository(ProjectApi(dio));
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
          expect(
            body['clientRequestId'],
            matches(RegExp(r'^mobile-project-[0-9a-f]{32}$')),
          );
          expect(body, {
            'clientRequestId': body['clientRequestId'],
            'expectedRevision': 7,
            ...change,
          });
        },
      );
    }
  }

  test('does not send a mutation when revision is missing', () async {
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
                'data': {'id': '1'},
              },
            ),
          );
        },
      ),
    );
    await expectLater(
      ProjectRepository(ProjectApi(dio)).deleteProject('1'),
      throwsA(isA<ApiException>()),
    );
    expect(requests.map((request) => request.method), ['GET']);
  });

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
      ProjectRepository(ProjectApi(dio)).setSessionPinned('1', true),
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
    final repository = ProjectRepository(ProjectApi(dio));
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
