import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_exception.dart';

/// Matches the Web Studio account and session APIs, including their envelopes.
class ProjectApi {
  const ProjectApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> createSession(
    String projectId,
    String title, {
    required String clientRequestId,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api_agent/v2/sessions/resolve',
      data: {
        'clientRequestId': clientRequestId,
        'mode': 'new',
        'title': title,
        'contextRef': {'kind': 'account', 'id': projectId},
      },
      cancelToken: cancelToken,
    );
    final body = response.data;
    if (body == null) throw const ApiException();
    return body;
  }

  Future<void> updateProject(
    String id, {
    String? title,
    bool archive = false,
    CancelToken? cancelToken,
  }) async {
    final path = '/api_client/agent/v2/accounts/${Uri.encodeComponent(id)}';
    final detail = await _dio.get<Map<String, dynamic>>(
      path,
      cancelToken: cancelToken,
    );
    final account = _businessData(detail.data);
    final response = await _dio.patch<Map<String, dynamic>>(
      path,
      data: {
        'clientRequestId': _requestId(),
        'expectedRevision': _revision(account),
        if (title != null) 'title': title,
        if (archive) 'action': 'archive',
      },
      cancelToken: cancelToken,
    );
    _businessData(response.data);
  }

  Future<void> updateSession(
    String id, {
    String? title,
    bool? archived,
    bool? pinned,
    CancelToken? cancelToken,
  }) async {
    final path = '/api_agent/v2/sessions/${Uri.encodeComponent(id)}';
    final detail = await _dio.get<Map<String, dynamic>>(
      '$path/snapshot',
      cancelToken: cancelToken,
    );
    final session = detail.data?['session'];
    if (session is! Map<String, dynamic>) throw const ApiException();
    final response = await _dio.patch<Map<String, dynamic>>(
      path,
      data: {
        'clientRequestId': _requestId(),
        'expectedRevision': _revision(session),
        if (title != null) 'title': title,
        if (archived != null) 'archived': archived,
        if (pinned != null) 'pinned': pinned,
      },
      cancelToken: cancelToken,
    );
    if (response.data == null) throw const ApiException();
  }

  int _revision(Map<String, dynamic> value) {
    final revision = value['revision'];
    if (revision is! int || revision < 1) throw const ApiException();
    return revision;
  }

  String _requestId() => createClientRequestId();

  /// Creates an idempotency key that can be retained across command retries.
  static String createClientRequestId() => const Uuid().v4();

  Map<String, dynamic> _businessData(Map<String, dynamic>? body) {
    if (body == null ||
        (body['status'] != null && body['status'].toString() != '0000')) {
      throw ApiException(message: body?['message'] as String?);
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) throw const ApiException();
    return data;
  }

  Future<Map<String, dynamic>> projectsPage(
    int page, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api_client/agent/v2/accounts',
      queryParameters: {'status': 'active', 'page': page, 'pageSize': 100},
      cancelToken: cancelToken,
    );
    return _businessData(response.data);
  }

  Future<Map<String, dynamic>> sessionsPage(
    String projectId,
    int page, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api_agent/v2/sessions',
      queryParameters: {
        'contextKind': 'account',
        'contextId': projectId,
        'page': page,
        'pageSize': 100,
      },
      cancelToken: cancelToken,
    );
    final body = response.data;
    if (body == null) throw const ApiException();
    return body;
  }
}
