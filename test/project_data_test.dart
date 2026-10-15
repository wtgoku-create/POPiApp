import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/network/auth_interceptor.dart';
import 'package:popi_ai_app/core/storage/secure_storage.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/features/projects/data/project_repository.dart';
import 'package:popi_ai_app/features/projects/domain/project.dart';
import 'package:popi_ai_app/shared/providers/project_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'support/list_page_fixtures.dart';

void main() {
  test(
    'requests a single project page with the Web envelope and token',
    () async {
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
      final projects = await ProjectRepository(
        NetworkApi(dio),
        NetworkAgentApi(dio),
      ).listProjects();
      expect(projects.items.map((item) => item.id), ['project-1']);
      expect(projects.hasMore, isTrue);
      expect(requests.length, 1);
      for (final request in requests) {
        expect(request.method, 'GET');
        expect(request.path, '/api_client/agent/v2/accounts');
        expect(request.headers['Authorization'], 'Bearer project-token');
        expect(request.queryParameters.containsKey('status'), isFalse);
        expect(request.queryParameters['pageSize'], 20);
        expect(request.queryParameters.containsKey('mainRoleStatus'), isFalse);
      }
      expect(requests.map((request) => request.queryParameters['page']), [1]);
    },
  );

  test(
    'sessions request one page, exclude archived and retain pagination',
    () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, '/api_agent/v2/sessions');
            expect(options.queryParameters['accountId'], 'project / 1');
            expect(options.queryParameters.containsKey('contextKind'), isFalse);
            expect(options.queryParameters.containsKey('contextId'), isFalse);
            expect(options.queryParameters['pageSize'], 20);
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
                  pageSize: 20,
                ),
              ),
            );
          },
        ),
      );
      final sessions = await ProjectRepository(
        NetworkApi(dio),
        NetworkAgentApi(dio),
      ).listSessions('project / 1');
      expect(sessions.items.map((item) => item.id), ['pinned-old', 'old']);
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
        ProjectRepository(NetworkApi(dio), NetworkAgentApi(dio)).listProjects(),
        throwsA(isA<ApiException>()),
      );
    }
  });

  test('a later page is requested only when the caller advances', () async {
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
    final repository = ProjectRepository(NetworkApi(dio), NetworkAgentApi(dio));
    final first = await repository.listProjects();
    expect(first.items.single.id, '1');
    expect(first.hasMore, isTrue);
    await expectLater(
      repository.listProjects(page: 2),
      throwsA(isA<DioException>()),
    );
    expect(first.items.single.id, '1');
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

  test(
    'shared project history appends on demand and retains rows after a page failure',
    () async {
      final repository = _ControlledRepository();
      final container = ProviderContainer(
        overrides: [
          projectRepositoryProvider.overrideWithValue(repository),
          userProvider.overrideWith(_LocalUser.new),
        ],
      );
      addTearDown(container.dispose);
      await container.read(userProvider.notifier).setUser(_user('a'));
      final subscription = container.listen(projectsProvider, (_, _) {});
      addTearDown(subscription.close);
      final all = [
        for (var index = 0; index < 45; index++)
          Project(id: '$index', title: 'Project $index'),
      ];
      final first = container.read(projectsProvider.future);
      repository.projects.last.complete(all);
      expect(await first, hasLength(20));
      final pager = container.read(projectsProvider.notifier);
      final second = pager.loadMore();
      await pager.loadMore();
      expect(repository.projectPages, [(1, 20), (2, 20)]);
      expect(container.read(projectsProvider).valueOrNull, hasLength(20));
      repository.projects.last.complete(all);
      await second;
      expect(container.read(projectsProvider).requireValue, hasLength(40));
      final failed = expectLater(
        pager.loadMore(),
        throwsA(isA<ApiException>()),
      );
      repository.projects.last.completeError(const ApiException());
      await failed;
      expect(container.read(projectsProvider).requireValue, hasLength(40));
      final retry = pager.loadMore();
      repository.projects.last.complete(all);
      await retry;
      expect(container.read(projectsProvider).requireValue, hasLength(45));
      expect(pager.hasMore, isFalse);
      await pager.loadMore();
      expect(repository.projectPages, [(1, 20), (2, 20), (3, 20), (3, 20)]);
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
  int pageSize = 20,
}) => {
  'list': list,
  'pageInfo': {
    'page': page,
    'pageSize': pageSize,
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
  _ControlledRepository() : super(NetworkApi(Dio()), NetworkAgentApi(Dio()));

  final projects = <Completer<List<Project>>>[];
  final sessions = <Completer<List<ProjectSession>>>[];
  final projectTokens = <CancelToken?>[];
  final projectPages = <(int, int)>[];
  final sessionTokens = <CancelToken?>[];

  @override
  Future<ListPage<Project>> listProjects({
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) {
    final completer = Completer<List<Project>>();
    projects.add(completer);
    projectPages.add((page, pageSize));
    projectTokens.add(cancelToken);
    return completer.future.then(
      (items) => fixturePage(items, page: page, pageSize: pageSize),
    );
  }

  @override
  Future<ListPage<ProjectSession>> listSessions(
    String projectId, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) {
    final completer = Completer<List<ProjectSession>>();
    sessions.add(completer);
    sessionTokens.add(cancelToken);
    return completer.future.then(
      (items) => fixturePage(items, page: page, pageSize: pageSize),
    );
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
