import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_api.dart';
import '../../core/network/network_agent_api.dart';
import '../../features/projects/data/project_repository.dart';
import '../../features/projects/domain/project.dart';
import '../controllers/paged_list_controller.dart';
import 'network_provider.dart';
import 'user_provider.dart';

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(
    NetworkApi(ref.watch(dioProvider)),
    NetworkAgentApi(ref.watch(agentDioProvider)),
  ),
);

/// Account-scoped, in-memory lists; disposal cancels obsolete HTTP requests.
final projectsProvider =
    AsyncNotifierProvider.autoDispose<ProjectsController, List<Project>>(
      ProjectsController.new,
    );

/// Shares only loaded project pages across the legacy drawer and its actions.
class ProjectsController extends AutoDisposeAsyncNotifier<List<Project>> {
  PagedListController<Project>? _pages;
  bool _ready = false;
  bool get hasMore => _pages?.hasMore ?? false;
  bool get loadingMore => _ready && (_pages?.loading ?? false);
  bool get initialLoading => state.isLoading && !loadingMore;

  @override
  Future<List<Project>> build() async {
    final userId = ref.watch(userProvider.select((user) => user?.id));
    final repository = ref.watch(projectRepositoryProvider);
    _ready = false;
    final pages = _pages = PagedListController<Project>(
      itemId: (item) => item.id,
      fetch: (page, token) =>
          repository.listProjects(page: page, cancelToken: token),
    );
    ref.onDispose(pages.dispose);
    if (userId == null) return const [];
    await pages.load();
    if (pages.disposed) return const [];
    _ready = true;
    pages.addListener(() {
      state = pages.loading
          ? const AsyncLoading<List<Project>>().copyWithPrevious(
              state,
              isRefresh: false,
            )
          : AsyncData(pages.items);
    });
    return pages.items;
  }

  Future<void> loadMore() async {
    if (_ready) await _pages!.load();
  }
}

final projectSessionsProvider = AsyncNotifierProvider.autoDispose
    .family<ProjectSessionsController, List<ProjectSession>, String>(
      ProjectSessionsController.new,
    );

/// Keeps each project's loaded pages scoped to its signed-in account.
class ProjectSessionsController
    extends AutoDisposeFamilyAsyncNotifier<List<ProjectSession>, String> {
  PagedListController<ProjectSession>? _pages;
  bool _ready = false;
  bool get hasMore => _pages?.hasMore ?? false;
  bool get loadingMore => _ready && (_pages?.loading ?? false);
  bool get initialLoading => state.isLoading && !loadingMore;

  @override
  Future<List<ProjectSession>> build(String projectId) async {
    final userId = ref.watch(userProvider.select((user) => user?.id));
    final repository = ref.watch(projectRepositoryProvider);
    _ready = false;
    final pages = _pages = PagedListController<ProjectSession>(
      itemId: (item) => item.id,
      fetch: (page, token) =>
          repository.listSessions(projectId, page: page, cancelToken: token),
    );
    ref.onDispose(pages.dispose);
    if (userId == null) return const [];
    await pages.load();
    if (pages.disposed) return const [];
    _ready = true;
    pages.addListener(() {
      state = pages.loading
          ? const AsyncLoading<List<ProjectSession>>().copyWithPrevious(
              state,
              isRefresh: false,
            )
          : AsyncData(pages.items);
    });
    return pages.items;
  }

  Future<void> loadMore() async {
    if (_ready) await _pages!.load();
  }
}

final projectActionsProvider =
    NotifierProvider.autoDispose<ProjectActionsController, bool>(
      ProjectActionsController.new,
    );

/// Serializes sidebar mutations and isolates completion from account changes.
class ProjectActionsController extends AutoDisposeNotifier<bool> {
  int _generation = 0;
  String? _userId;
  CancelToken? _activeToken;
  final _pendingSessionRequests =
      <String, ({String requestId, String title})>{};

  @override
  bool build() {
    _userId = ref.read(userProvider)?.id;
    ref.listen(userProvider.select((user) => user?.id), (_, userId) {
      _userId = userId;
      _generation++;
      _activeToken?.cancel();
      _activeToken = null;
      _pendingSessionRequests.clear();
      state = false;
    });
    ref.onDispose(() {
      _generation++;
      _activeToken?.cancel();
      _pendingSessionRequests.clear();
    });
    return false;
  }

  Future<ProjectSession?> createSession(String projectId, String title) async {
    ProjectSession? session;
    final success = await _run(projectId, true, (repository, token) async {
      final pending = _pendingSessionRequests.putIfAbsent(
        projectId,
        () => (
          requestId: ProjectRepository.createClientRequestId(),
          title: title,
        ),
      );
      session = await repository.createSession(
        projectId,
        pending.title,
        clientRequestId: pending.requestId,
        cancelToken: token,
      );
      if (!token.isCancelled) _pendingSessionRequests.remove(projectId);
    });
    return success ? session : null;
  }

  Future<bool> renameProject(String id, String title) => _run(
    id,
    false,
    (repository, token) =>
        repository.renameProject(id, title, cancelToken: token),
  );

  Future<bool> deleteProject(String id) => _run(
    id,
    false,
    (repository, token) => repository.deleteProject(id, cancelToken: token),
  );

  Future<bool> renameSession(String projectId, String id, String title) => _run(
    projectId,
    true,
    (repository, token) =>
        repository.renameSession(id, title, cancelToken: token),
  );

  Future<bool> deleteSession(String projectId, String id) => _run(
    projectId,
    true,
    (repository, token) => repository.deleteSession(id, cancelToken: token),
  );

  Future<bool> setSessionPinned(String projectId, String id, bool pinned) =>
      _run(
        projectId,
        true,
        (repository, token) =>
            repository.setSessionPinned(id, pinned, cancelToken: token),
      );

  Future<bool> _run(
    String projectId,
    bool sessionOnly,
    Future<void> Function(ProjectRepository, CancelToken) command,
  ) async {
    final userId = _userId;
    if (state || userId == null) return false;
    final generation = _generation;
    final token = CancelToken();
    _activeToken = token;
    bool isCurrent() => generation == _generation && _userId == userId;
    state = true;
    try {
      await command(ref.read(projectRepositoryProvider), token);
      if (!isCurrent()) return false;
      ref.invalidate(projectSessionsProvider(projectId));
      if (!sessionOnly) ref.invalidate(projectsProvider);
      return true;
    } catch (_) {
      if (!isCurrent()) return false;
      rethrow;
    } finally {
      if (isCurrent()) {
        _activeToken = null;
        state = false;
      }
    }
  }
}
