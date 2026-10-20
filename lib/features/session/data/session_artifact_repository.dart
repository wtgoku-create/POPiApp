import 'package:dio/dio.dart';

import '../../../core/network/network_api.dart';
import '../../../shared/type/list_page.dart';
import '../domain/session_artifact.dart';

abstract class SessionArtifactRepository {
  const SessionArtifactRepository();

  Future<List<SessionArtifact>> list(String? sessionId);
}

/// All saved outputs are paged independently of the conversation timeline.
class ApiSessionArtifactRepository extends SessionArtifactRepository {
  const ApiSessionArtifactRepository(this.api, {this.cancelToken});

  final NetworkApi api;
  final CancelToken? cancelToken;

  Future<ListPage<SessionArtifact>> page(
    String sessionId, {
    int page = 1,
    int pageSize = 20,
    String keyword = '',
  }) async => ListPage.fromJson(
    await api.sessionArtifactsPage(
      sessionId,
      page: page,
      pageSize: pageSize,
      keyword: keyword,
      cancelToken: cancelToken,
    ),
    page: page,
    pageSize: pageSize,
    parse: SessionArtifact.fromJson,
  );

  @override
  Future<List<SessionArtifact>> list(String? sessionId) async {
    if (sessionId == null || sessionId.isEmpty) return const [];
    final items = <String, SessionArtifact>{};
    for (var page = 1; ; page++) {
      if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
      final result = await this.page(sessionId, page: page);
      for (final artifact in result.items) {
        items[artifact.id] = artifact;
      }
      if (result.items.isEmpty || !result.hasMore) break;
    }
    return List.unmodifiable(items.values);
  }
}
