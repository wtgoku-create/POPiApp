import 'dart:convert';

import 'package:dio/dio.dart';

import 'agent_api_exception.dart';
import 'api_exception.dart';

/// HTTP contracts for the independently configured /api_agent service.
class NetworkAgentApi {
  const NetworkAgentApi(this.dio);

  final Dio dio;

  Future<Map<String, dynamic>> resolveSession({
    required String clientRequestId,
    String mode = 'new',
    String? title,
    Map<String, Object?>? contextRef,
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/sessions/resolve',
    method: 'POST',
    data: {
      'clientRequestId': clientRequestId,
      'mode': mode,
      if (title != null) 'title': title,
      if (contextRef != null) 'contextRef': contextRef,
    },
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> createProjectSession(
    String projectId,
    String title, {
    required String clientRequestId,
    CancelToken? cancelToken,
  }) => resolveSession(
    clientRequestId: clientRequestId,
    title: title,
    contextRef: {'kind': 'account', 'id': projectId},
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> sessionsPage({
    int page = 1,
    int pageSize = 20,
    bool archived = false,
    String? contextKind,
    String? contextId,
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/sessions',
    queryParameters: {
      'page': page,
      'pageSize': pageSize,
      'archived': archived.toString(),
      if (contextKind != null) 'contextKind': contextKind,
      if (contextId != null) 'contextId': contextId,
    },
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> projectSessionsPage(
    String projectId,
    int page, {
    CancelToken? cancelToken,
  }) => sessionsPage(
    page: page,
    pageSize: 100,
    contextKind: 'account',
    contextId: projectId,
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> sessionSnapshot(
    String id, {
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/sessions/${Uri.encodeComponent(id)}/snapshot',
    cancelToken: cancelToken,
  );

  /// Retries must retain the same request ID, revision and complete input.
  Future<Map<String, dynamic>> updateSession(
    String id, {
    required String clientRequestId,
    required int expectedRevision,
    String? title,
    bool? archived,
    bool? pinned,
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/sessions/${Uri.encodeComponent(id)}',
    method: 'PATCH',
    data: {
      'clientRequestId': clientRequestId,
      'expectedRevision': expectedRevision,
      if (title != null) 'title': title,
      if (archived != null) 'archived': archived,
      if (pinned != null) 'pinned': pinned,
    },
    cancelToken: cancelToken,
  );

  Future<void> updateProjectSession(
    String id, {
    required String clientRequestId,
    String? title,
    bool? archived,
    bool? pinned,
    CancelToken? cancelToken,
  }) async {
    final detail = await sessionSnapshot(id, cancelToken: cancelToken);
    final session = detail['session'];
    final revision = session is Map ? session['revision'] : null;
    if (revision is! int || revision < 1) throw const ApiException();
    await updateSession(
      id,
      clientRequestId: clientRequestId,
      expectedRevision: revision,
      title: title,
      archived: archived,
      pinned: pinned,
      cancelToken: cancelToken,
    );
  }

  /// HTTP 202 returns run/message IDs; assistant content arrives via events.
  Future<Map<String, dynamic>> sendSessionMessage(
    String id, {
    required String clientRequestId,
    required String text,
    String? taskId,
    List<String>? mediaIds,
    List<Map<String, Object?>>? inputRefs,
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/sessions/${Uri.encodeComponent(id)}/messages',
    method: 'POST',
    data: {
      'clientRequestId': clientRequestId,
      'text': text,
      if (taskId != null) 'taskId': taskId,
      if (mediaIds != null) 'mediaIds': mediaIds,
      if (inputRefs != null) 'inputRefs': inputRefs,
    },
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> stopSession(
    String id, {
    required String clientRequestId,
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/sessions/${Uri.encodeComponent(id)}/stop',
    method: 'POST',
    data: {'clientRequestId': clientRequestId},
    cancelToken: cancelToken,
  );

  /// Returns raw SSE bytes; event parsing and message updates belong outside UI.
  Future<ResponseBody> openSessionEvents(
    String id, {
    int afterSeq = 0,
    String? lastEventId,
    required CancelToken cancelToken,
  }) async {
    try {
      final response = await dio.get<ResponseBody>(
        '/api_agent/v2/sessions/${Uri.encodeComponent(id)}/events',
        queryParameters: {'afterSeq': afterSeq},
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero,
          headers: {
            'Accept': 'text/event-stream',
            if (lastEventId != null) 'Last-Event-ID': lastEventId,
          },
        ),
        cancelToken: cancelToken,
      );
      final body = response.data;
      if (body == null ||
          response.headers.value('content-type')?.split(';').first.trim() !=
              'text/event-stream') {
        await body?.stream.listen(null).cancel();
        throw const AgentApiException(
          code: 'INVALID_RESPONSE',
          message: 'Invalid Agent event stream',
        );
      }
      return body;
    } on DioException catch (error) {
      if (error.response == null || CancelToken.isCancel(error)) rethrow;
      final body = error.response!.data;
      if (body is ResponseBody) {
        final text = await utf8.decoder.bind(body.stream).join();
        try {
          error.response!.data = jsonDecode(text);
        } on FormatException {
          error.response!.data = null;
        }
      }
      throw AgentApiException.fromDioException(error);
    }
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, Object?>? data,
    Map<String, Object?>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dio.request<Object?>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(method: method),
        cancelToken: cancelToken,
      );
      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw AgentApiException(
          code: 'INVALID_RESPONSE',
          message: 'Invalid Agent response',
          statusCode: response.statusCode,
          requestId: response.headers.value('x-request-id'),
          retryable: true,
        );
      }
      return body;
    } on DioException catch (error) {
      // Preserve cancellation and transport failures for the caller's lifecycle.
      if (error.response == null || CancelToken.isCancel(error)) rethrow;
      throw AgentApiException.fromDioException(error);
    }
  }
}
