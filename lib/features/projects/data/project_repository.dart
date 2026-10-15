import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/agent_api_exception.dart';
import '../../../core/network/network_api.dart';
import '../../../core/network/network_agent_api.dart';
import '../../../shared/type/list_page.dart';
import '../domain/project.dart';

class ProjectRepository {
  const ProjectRepository(this._api, this._agentApi);

  final NetworkApi _api;
  final NetworkAgentApi _agentApi;

  /// Creates an idempotency key that can be retained across command retries.
  static String createClientRequestId() => const Uuid().v4();

  /// Only an explicit missing binding allows callers to create a session.
  Future<ProjectSession?> boundSession(
    String accountId, {
    CancelToken? cancelToken,
  }) => _mutate(() async {
    try {
      return _session(
        await _agentApi.sessionByAccount(accountId, cancelToken: cancelToken),
      );
    } on AgentApiException catch (error) {
      if (error.statusCode == 404 &&
          error.code == 'ACCOUNT_SESSION_NOT_FOUND') {
        return null;
      }
      rethrow;
    }
  });

  ProjectSession _session(Map<String, dynamic> value) {
    if (value['id'] is! String ||
        (value['id'] as String).isEmpty ||
        value['title'] is! String) {
      throw const ApiException(message: 'Invalid session response');
    }
    return ProjectSession.fromJson(value);
  }

  Future<ProjectSession> createSession(
    String projectId,
    String title, {
    required String clientRequestId,
    CancelToken? cancelToken,
  }) => _mutate(() async {
    final value = await _agentApi.createProjectSession(
      projectId,
      _title(title),
      clientRequestId: clientRequestId,
      cancelToken: cancelToken,
    );
    return _session(value);
  });

  Future<void> renameProject(
    String id,
    String title, {
    CancelToken? cancelToken,
  }) => _mutate(
    () => _api.updateProject(
      id,
      clientRequestId: createClientRequestId(),
      title: _title(title),
      cancelToken: cancelToken,
    ),
  );

  Future<void> deleteProject(String id, {CancelToken? cancelToken}) => _mutate(
    () => _api.updateProject(
      id,
      clientRequestId: createClientRequestId(),
      archive: true,
      cancelToken: cancelToken,
    ),
  );

  Future<void> renameSession(
    String id,
    String title, {
    CancelToken? cancelToken,
  }) => _mutate(
    () => _agentApi.updateProjectSession(
      id,
      clientRequestId: createClientRequestId(),
      title: _title(title),
      cancelToken: cancelToken,
    ),
  );

  Future<void> deleteSession(String id, {CancelToken? cancelToken}) => _mutate(
    () => _agentApi.updateProjectSession(
      id,
      clientRequestId: createClientRequestId(),
      archived: true,
      cancelToken: cancelToken,
    ),
  );

  Future<void> setSessionPinned(
    String id,
    bool pinned, {
    CancelToken? cancelToken,
  }) => _mutate(
    () => _agentApi.updateProjectSession(
      id,
      clientRequestId: createClientRequestId(),
      pinned: pinned,
      cancelToken: cancelToken,
    ),
  );

  Future<T> _mutate<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  String _title(String value) {
    final title = value.trim();
    if (title.isEmpty || title.runes.length > 200) {
      throw const ApiException(message: 'Invalid project title');
    }
    return title;
  }

  Future<ListPage<Project>> listProjects({
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    final result = await _api.projectsPage(
      page,
      pageSize: pageSize,
      cancelToken: cancelToken,
    );
    final items = _page(result, page: page, pageSize: pageSize);
    return ListPage(
      items: [
        for (final item in items.items)
          if (item['status'] != 'archived') Project.fromJson(item),
      ],
      page: items.page,
      pageCount: items.pageCount,
    );
  }

  Future<ListPage<ProjectSession>> listSessions(
    String projectId, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    final result = await _agentApi.projectSessionsPage(
      projectId,
      page,
      pageSize: pageSize,
      cancelToken: cancelToken,
    );
    final items = _page(result, page: page, pageSize: pageSize);
    final sessions = {
      for (final item in items.items)
        (item['id'] as String): ProjectSession.fromJson(item),
    }.values.where((item) => !item.archived).toList();
    sessions.sort((a, b) {
      final pinned = (b.pinnedAt != null ? 1 : 0).compareTo(
        a.pinnedAt != null ? 1 : 0,
      );
      if (pinned != 0) return pinned;
      final date = (b.pinnedAt ?? b.updatedAt)?.millisecondsSinceEpoch ?? 0;
      final otherDate =
          (a.pinnedAt ?? a.updatedAt)?.millisecondsSinceEpoch ?? 0;
      return date.compareTo(otherDate) != 0
          ? date.compareTo(otherDate)
          : b.id.compareTo(a.id);
    });
    return ListPage(
      items: List.unmodifiable(sessions),
      page: page,
      pageCount: items.pageCount,
    );
  }

  ListPage<Map<String, dynamic>> _page(
    Map<String, dynamic> result, {
    required int page,
    required int pageSize,
  }) {
    final list = result['list'];
    final info = result['pageInfo'];
    if (list is! List ||
        info is! Map<String, dynamic> ||
        info['page'] != page ||
        info['pageSize'] != pageSize ||
        info['pageCount'] is! int ||
        (info['pageCount'] as int) < 1 ||
        (info['pageCount'] as int) > 10000 ||
        info['total'] is! int ||
        (info['total'] as int) < 0 ||
        list.length > pageSize) {
      throw const ApiException(message: 'Invalid project pagination');
    }
    for (final item in list) {
      if (item is! Map<String, dynamic> ||
          item['id'] is! String ||
          (item['id'] as String).isEmpty ||
          item['title'] is! String) {
        throw const ApiException(message: 'Invalid project response');
      }
    }
    return ListPage(
      items: list.cast<Map<String, dynamic>>(),
      page: page,
      pageCount: info['pageCount'] as int,
    );
  }
}
