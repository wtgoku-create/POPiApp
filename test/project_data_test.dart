import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/network/auth_interceptor.dart';
import 'package:popi_ai_app/core/storage/secure_storage.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/projects/data/project_api.dart';
import 'package:popi_ai_app/features/projects/data/project_repository.dart';
import 'package:popi_ai_app/features/projects/domain/project.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

void main() {
  test('uses Web endpoints, envelopes, token and all project pages', () async {
    final requests = <RequestOptions>[];
    final dio = Dio()..interceptors.add(AuthInterceptor(_Tokens()));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final page = options.queryParameters['page'] as int;
          handler.resolve(
            Response(
              requestOptions: options,
              data: {
                'status': '0000',
                'data': _page(
                  [
                    {
                      'id': 'project-$page',
                      'title': 'Project $page',
                      'status': 'active',
                    },
                    if (page == 2)
                      {
                        'id': 'archived',
                        'title': 'Archived',
                        'status': 'archived',
                      },
                  ],
                  page: page,
                  pageCount: 2,
                ),
              },
            ),
          );
        },
      ),
    );
    final projects = await ProjectRepository(ProjectApi(dio)).listProjects();
    expect(projects.map((item) => item.id), ['project-1', 'project-2']);
    expect(requests.length, 2);
    for (final request in requests) {
      expect(request.method, 'GET');
      expect(request.path, '/api_client/agent/v2/accounts');
      expect(request.headers['Authorization'], 'Bearer project-token');
      expect(request.queryParameters['status'], 'active');
      expect(request.queryParameters['pageSize'], 100);
      expect(request.queryParameters.containsKey('mainRoleStatus'), isFalse);
    }
    expect(requests.map((request) => request.queryParameters['page']), [1, 2]);
  });

  test(
    'sessions use raw envelope, exclude archived and sort across pages',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, '/api_agent/v2/sessions');
            expect(options.queryParameters['contextKind'], 'account');
            expect(options.queryParameters['contextId'], 'project / 1');
            expect(options.queryParameters['pageSize'], 100);
            final page = options.queryParameters['page'] as int;
            handler.resolve(
              Response(
                requestOptions: options,
                data: _page(
                  page == 1
                      ? [
                          _session('old', updatedAt: '2026-01-01T00:00:00Z'),
                          _session('archived', archived: true),
                          _session(
                            'pinned-old',
                            pinnedAt: '2026-01-01T00:00:00Z',
                          ),
                        ]
                      : [
                          _session('new', updatedAt: '2026-10-01T00:00:00Z'),
                          _session(
                            'pinned-new',
                            pinnedAt: '2026-09-01T00:00:00Z',
                          ),
                        ],
                  page: page,
                  pageCount: 2,
                ),
              ),
            );
          },
        ),
      );
      final sessions = await ProjectRepository(
        ProjectApi(dio),
      ).listSessions('project / 1');
      expect(sessions.map((item) => item.id), [
        'pinned-new',
        'pinned-old',
        'new',
        'old',
      ]);
    },
  );

  test('rejects failed envelope and malformed pagination', () async {
    for (final body in [
      {'status': '4000', 'message': 'Denied'},
      {'data': _page([], page: 2)},
      {
        'data': {
          'list': [],
          'pageInfo': {'page': 1, 'pageCount': 0},
        },
      },
      {
        'data': _page([
          {'title': 'Missing ID'},
        ]),
      },
    ]) {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(Response(requestOptions: options, data: body));
          },
        ),
      );
      await expectLater(
        ProjectRepository(ProjectApi(dio)).listProjects(),
        throwsA(isA<ApiException>()),
      );
    }
  });

  test('a failed later page does not publish a partial project list', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final page = options.queryParameters['page'] as int;
          if (page == 2) {
            handler.reject(DioException(requestOptions: options));
          } else {
            handler.resolve(
              Response(
                requestOptions: options,
                data: {
                  'data': _page([
                    {'id': '1', 'title': 'One'},
                  ], pageCount: 2),
                },
              ),
            );
          }
        },
      ),
    );
    await expectLater(
      ProjectRepository(ProjectApi(dio)).listProjects(),
      throwsA(isA<DioException>()),
    );
  });

  test(
    'guest does not fetch; failure can be retried; logout clears lists',
    () async {
      final repository = _ControlledRepository();
      final container = ProviderContainer(
        overrides: [
          projectRepositoryProvider.overrideWithValue(repository),
          userProvider.overrideWith(_LocalUser.new),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(projectsProvider, (_, __) {});
      final sessions = container.listen(
        projectSessionsProvider('p'),
        (_, __) {},
      );
      addTearDown(subscription.close);
      addTearDown(sessions.close);
      expect(await container.read(projectsProvider.future), isEmpty);
      expect(
        await container.read(projectSessionsProvider('p').future),
        isEmpty,
      );
      expect(repository.projects, isEmpty);
      await container.read(userProvider.notifier).setUser(_user('a'));
      final failed = container.read(projectsProvider.future);
      final failedAssertion = expectLater(failed, throwsA(isA<ApiException>()));
      repository.projects.last.completeError(const ApiException());
      await failedAssertion;
      expect(container.read(projectsProvider).hasError, isTrue);
      final retry = container.refresh(projectsProvider.future);
      repository.projects.last.complete([const Project(id: 'p', title: 'One')]);
      expect((await retry).single.id, 'p');
      final sessionFuture = container.read(projectSessionsProvider('p').future);
      repository.sessions.last.complete([
        const ProjectSession(id: 's', title: 'Session'),
      ]);
      expect((await sessionFuture).single.id, 's');
      await container.read(userProvider.notifier).clearUser();
      expect(await container.read(projectsProvider.future), isEmpty);
      expect(
        await container.read(projectSessionsProvider('p').future),
        isEmpty,
      );
      expect(repository.projectTokens.last!.isCancelled, isTrue);
      expect(repository.sessionTokens.last!.isCancelled, isTrue);
    },
  );

  test('account changes cancel requests and ignore late results', () async {
    final repository = _ControlledRepository();
    final container = ProviderContainer(
      overrides: [projectRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    await container.read(userProvider.notifier).setUser(_user('a'));
    final subscription = container.listen(projectsProvider, (_, __) {});
    final sessionSubscription = container.listen(
      projectSessionsProvider('p'),
      (_, __) {},
    );
    addTearDown(subscription.close);
    addTearDown(sessionSubscription.close);
    await container.read(userProvider.notifier).setUser(_user('b'));
    final current = container.read(projectsProvider.future);
    final currentSessions = container.read(projectSessionsProvider('p').future);
    expect(repository.projectTokens.first!.isCancelled, isTrue);
    expect(repository.sessionTokens.first!.isCancelled, isTrue);
    repository.projects.last.complete([const Project(id: 'b', title: 'B')]);
    repository.sessions.last.complete([
      const ProjectSession(id: 'b', title: 'B'),
    ]);
    await current;
    await currentSessions;
    repository.projects.first.complete([const Project(id: 'a', title: 'A')]);
    repository.sessions.first.complete([
      const ProjectSession(id: 'a', title: 'A'),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(projectsProvider).requireValue.single.id, 'b');
    expect(
      container.read(projectSessionsProvider('p')).requireValue.single.id,
      'b',
    );
  });
}

Map<String, dynamic> _page(
  List<Map<String, dynamic>> list, {
  int page = 1,
  int pageCount = 1,
}) => {
  'list': list,
  'pageInfo': {
    'page': page,
    'pageSize': 100,
    'pageCount': pageCount,
    'total': 5,
  },
};

Map<String, dynamic> _session(
  String id, {
  String? updatedAt,
  String? pinnedAt,
  bool archived = false,
}) => {
  'id': id,
  'title': id,
  'archived': archived,
  'updatedAt': updatedAt,
  'pinnedAt': pinnedAt,
};

User _user(String id) => User(id: id, name: id, email: '');

class _LocalUser extends UserController {
  @override
  Future<void> clearUser() async => state = null;
}

class _ControlledRepository extends ProjectRepository {
  _ControlledRepository() : super(ProjectApi(Dio()));

  final projects = <Completer<List<Project>>>[];
  final sessions = <Completer<List<ProjectSession>>>[];
  final projectTokens = <CancelToken?>[];
  final sessionTokens = <CancelToken?>[];

  @override
  Future<List<Project>> listProjects({CancelToken? cancelToken}) {
    final completer = Completer<List<Project>>();
    projects.add(completer);
    projectTokens.add(cancelToken);
    return completer.future;
  }

  @override
  Future<List<ProjectSession>> listSessions(
    String projectId, {
    CancelToken? cancelToken,
  }) {
    final completer = Completer<List<ProjectSession>>();
    sessions.add(completer);
    sessionTokens.add(cancelToken);
    return completer.future;
  }
}

class _Tokens implements TokenStorage {
  @override
  Future<String?> readAccessToken() async => 'project-token';
  @override
  Future<void> writeAccessToken(String token) async {}
  @override
  Future<void> deleteAccessToken() async {}
}
