import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_api.dart';
import '../domain/project.dart';

class ProjectRepository {
  const ProjectRepository(this._api);

  final NetworkApi _api;

  /// Creates an idempotency key that can be retained across command retries.
  static String createClientRequestId() => const Uuid().v4();

  Future<ProjectSession> createSession(
    String projectId,
    String title, {
    required String clientRequestId,
    CancelToken? cancelToken,
  }) => _mutate(() async {
    final value = await _api.createProjectSession(
      projectId,
      _title(title),
      clientRequestId: clientRequestId,
      cancelToken: cancelToken,
    );
    if (value['id'] is! String ||
        (value['id'] as String).isEmpty ||
        value['title'] is! String) {
      throw const ApiException(message: 'Invalid session response');
    }
    return ProjectSession.fromJson(value);
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
    () => _api.updateProjectSession(
      id,
      clientRequestId: createClientRequestId(),
      title: _title(title),
      cancelToken: cancelToken,
    ),
  );

  Future<void> deleteSession(String id, {CancelToken? cancelToken}) => _mutate(
    () => _api.updateProjectSession(
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
    () => _api.updateProjectSession(
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

  Future<List<Project>> listProjects({CancelToken? cancelToken}) async {
    final items = await _pages(
      (page) => _api.projectsPage(page, cancelToken: cancelToken),
    );
    return List.unmodifiable(
      {
        for (final item in items)
          if (item['status'] != 'archived')
            (item['id'] as String): Project.fromJson(item),
      }.values,
    );
  }

  Future<List<ProjectSession>> listSessions(
    String projectId, {
    CancelToken? cancelToken,
  }) async {
    final items = await _pages(
      (page) =>
          _api.projectSessionsPage(projectId, page, cancelToken: cancelToken),
    );
    final sessions = {
      for (final item in items)
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
    return List.unmodifiable(sessions);
  }

  // Fetch every page before publishing, so a later failure cannot look complete.
  Future<List<Map<String, dynamic>>> _pages(
    Future<Map<String, dynamic>> Function(int) load,
  ) async {
    final items = <Map<String, dynamic>>[];
    for (var page = 1; ; page++) {
      final result = await load(page);
      final list = result['list'];
      final info = result['pageInfo'];
      if (list is! List ||
          info is! Map<String, dynamic> ||
          info['page'] != page ||
          info['pageSize'] != 100 ||
          info['pageCount'] is! int ||
          (info['pageCount'] as int) < 1 ||
          (info['pageCount'] as int) > 10000 ||
          info['total'] is! int ||
          (info['total'] as int) < 0 ||
          list.length > 100) {
        throw const ApiException(message: 'Invalid project pagination');
      }
      for (final item in list) {
        if (item is! Map<String, dynamic> ||
            item['id'] is! String ||
            (item['id'] as String).isEmpty ||
            item['title'] is! String) {
          throw const ApiException(message: 'Invalid project response');
        }
        items.add(item);
      }
      if (page >= (info['pageCount'] as int)) return items;
    }
  }
}
