import 'package:dio/dio.dart';

import '../../../core/network/network_api.dart';
import '../domain/conversation_snapshot.dart';
import '../domain/session_artifact.dart';

abstract class SessionArtifactRepository {
  const SessionArtifactRepository();

  Future<List<SessionArtifact>> list(String? sessionId);
}

/// Text outputs are paged independently of the messages loaded in the timeline.
class ApiSessionArtifactRepository extends SessionArtifactRepository {
  const ApiSessionArtifactRepository(this.api, {this.cancelToken});

  final NetworkApi api;
  final CancelToken? cancelToken;

  @override
  Future<List<SessionArtifact>> list(String? sessionId) async {
    if (sessionId == null || sessionId.isEmpty) return const [];
    final items = <String, SessionArtifact>{};
    for (var page = 1; ; page++) {
      if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
      final result = await api.sessionTextArtifactsPage(
        sessionId,
        page: page,
        cancelToken: cancelToken,
      );
      final rows = conversationMaps(result['list']);
      for (final row in rows) {
        final artifact = SessionArtifact.fromTextDraft(row);
        items[artifact.id] = artifact;
      }
      final pageCount = conversationMap(result['pageInfo'])['pageCount'] as int;
      if (rows.isEmpty || page >= pageCount) break;
    }
    return List.unmodifiable(items.values);
  }
}
