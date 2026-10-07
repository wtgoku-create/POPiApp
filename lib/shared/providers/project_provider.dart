import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/projects/data/project_api.dart';
import '../../features/projects/data/project_repository.dart';
import '../../features/projects/domain/project.dart';
import 'network_provider.dart';
import 'user_provider.dart';

final projectRepositoryProvider = Provider<ProjectRepository>(
  (ref) => ProjectRepository(ProjectApi(ref.watch(dioProvider))),
);

/// Account-scoped, in-memory lists; disposal cancels obsolete HTTP requests.
final projectsProvider = FutureProvider.autoDispose<List<Project>>((ref) {
  final userId = ref.watch(userProvider.select((user) => user?.id));
  if (userId == null) return const [];
  final repository = ref.watch(projectRepositoryProvider);
  final token = CancelToken();
  ref.onDispose(token.cancel);
  return repository.listProjects(cancelToken: token);
});

final projectSessionsProvider = FutureProvider.autoDispose
    .family<List<ProjectSession>, String>((ref, projectId) {
      final userId = ref.watch(userProvider.select((user) => user?.id));
      if (userId == null) return const [];
      final repository = ref.watch(projectRepositoryProvider);
      final token = CancelToken();
      ref.onDispose(token.cancel);
      return repository.listSessions(projectId, cancelToken: token);
    });

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
        () => (requestId: ProjectApi.createClientRequestId(), title: title),
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
