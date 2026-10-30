import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'agent_api_exception.dart';
import 'network_agent_runtime.dart';

/// HTTP contracts for the independently configured /api_agent service.
class NetworkAgentApi {
  NetworkAgentApi(this.dio, {Dio? runtimeDio})
    : _runtimeDio = runtimeDio ?? dio;

  final Dio dio;
  final Dio _runtimeDio;
  bool _closed = false;
  late final runtime = NetworkAgentRuntime(_runtimeDio);

  void close() {
    _closed = true;
    runtime.close();
  }

  /// 业务封面只接受公开媒体路径；云端截帧仅允许固定处理参数，不接受签名或任意查询。
  String resolveBusinessPosterUrl(Object? value) {
    if (value is! Map || value['policy'] != 'public') return '';
    final raw = value['posterUrl']?.toString() ?? '';
    if (raw.isEmpty) return '';
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !const {'https', 'http'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        !uri.path.startsWith('/media/') ||
        uri.pathSegments.any((part) => part == '..' || part == '.') ||
        uri.path.contains(r'\')) {
      return '';
    }
    if (uri.hasQuery &&
        (uri.scheme != 'https' ||
            uri.query != 'ci-process=snapshot&time=0&format=jpg&width=640')) {
      return '';
    }
    return uri.toString();
  }

  /// 仅接受业务端鉴权返回的公开媒体地址，不接受凭据或临时查询参数。
  String resolveBusinessAccessUrl(Object? value) {
    if (value is! Map || value['policy'] != 'public') {
      throw const FormatException('Invalid business media access');
    }
    final uri = Uri.tryParse(value['url']?.toString() ?? '');
    if (uri == null ||
        !const {'https', 'http'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Invalid business media URL');
    }
    return uri.toString();
  }

  /// 下载前重新鉴权，外部 CDN 使用独立传输，绝不携带 Agent Token 或拦截器。
  Future<Uint8List> readBusinessAssetBytes(
    String id, {
    required int maxBytes,
  }) async {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id) || maxBytes <= 0) {
      throw const FormatException('Invalid business media request');
    }
    final Map<String, dynamic> access;
    try {
      access = await _request('/api_agent/v2/assets/$id/access');
    } on AgentApiException catch (error) {
      if (error.code != 'ASSET_ACCESS_UNAVAILABLE') rethrow;
      final bytes = await readAssetBytes('/api_agent/v2/assets/$id/content');
      if (bytes.length > maxBytes) {
        throw const FormatException('Business media exceeds download limit');
      }
      return bytes;
    }
    final url = resolveBusinessAccessUrl(access);
    final transport = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 60),
        followRedirects: false,
      ),
    );
    try {
      final response = await transport.get<ResponseBody>(
        url,
        options: Options(responseType: ResponseType.stream),
      );
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.data!.stream) {
        if (builder.length + chunk.length > maxBytes) {
          throw const FormatException('Business media exceeds download limit');
        }
        builder.add(chunk);
      }
      return builder.takeBytes();
    } finally {
      transport.close(force: true);
    }
  }

  Future<Map<String, dynamic>> createHarnessSession({
    required String clientRequestId,
    required String title,
    required String kind,
    Map<String, Object?>? configuration,
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/sessions',
    method: 'POST',
    data: {
      'clientRequestId': clientRequestId,
      'title': title,
      'kind': kind,
      if (configuration != null) 'configuration': configuration,
    },
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> assets({
    String? sessionId,
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/assets',
    queryParameters: {if (sessionId != null) 'sessionId': sessionId},
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> renameAsset(String id, String title) => _request(
    '/api_agent/v2/assets/${Uri.encodeComponent(id)}',
    method: 'PATCH',
    data: {'title': title},
  );

  Future<Map<String, dynamic>> deleteAsset(String id) => _request(
    '/api_agent/v2/assets/${Uri.encodeComponent(id)}',
    method: 'DELETE',
    data: const {},
  );

  Future<Map<String, dynamic>> libraryRoles({
    int page = 1,
    int pageSize = 100,
    String category = '',
  }) => _request(
    '/api_agent/v2/roles',
    queryParameters: {'page': page, 'pageSize': pageSize, 'category': category},
  );

  Future<Map<String, dynamic>> libraryRole(String id) =>
      _request('/api_agent/v2/roles/${Uri.encodeComponent(id)}');

  Future<Map<String, dynamic>> saveLibraryRole(
    Map<String, Object?> data, {
    String? id,
  }) => _request(
    id == null
        ? '/api_agent/v2/roles'
        : '/api_agent/v2/roles/${Uri.encodeComponent(id)}',
    method: id == null ? 'POST' : 'PATCH',
    data: data,
  );

  Future<Map<String, dynamic>> deleteLibraryRole(
    String id,
    String requestId,
    String revision,
  ) => _request(
    '/api_agent/v2/roles/${Uri.encodeComponent(id)}',
    method: 'DELETE',
    data: {'clientRequestId': requestId, 'revision': revision},
  );

  Future<Map<String, dynamic>> uploadRoleReference({
    required String roleId,
    required String requestId,
    required String revision,
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/api_agent/v2/roles/${Uri.encodeComponent(roleId)}/references',
      queryParameters: {
        'requestKey': requestId,
        'revision': revision,
        'name': name,
      },
      data: bytes,
      options: Options(
        contentType: mimeType,
        sendTimeout: const Duration(seconds: 200),
        receiveTimeout: const Duration(seconds: 200),
      ),
    );
    return response.data!;
  }

  /// Uploads one owned asset as a raw body. The request ID makes retries safe.
  Future<Map<String, dynamic>> importBusinessAsset(
    String businessAssetId, {
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/assets/import',
    method: 'POST',
    data: {'businessAssetId': businessAssetId},
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> uploadAsset({
    required String clientRequestId,
    required String name,
    required String mimeType,
    required Uint8List bytes,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dio.post<Object?>(
        '/api_agent/v2/assets',
        data: bytes,
        queryParameters: {'clientRequestId': clientRequestId, 'name': name},
        options: Options(
          contentType: mimeType,
          headers: {'Content-Length': bytes.lengthInBytes},
          // Document extraction may include a bounded OCR/Office conversion.
          sendTimeout: const Duration(seconds: 200),
          receiveTimeout: const Duration(seconds: 200),
        ),
        cancelToken: cancelToken,
      );
      final body = response.data;
      if ((response.statusCode != 200 && response.statusCode != 201) ||
          body is! Map<String, dynamic> ||
          body['asset'] is! Map) {
        throw AgentApiException(
          code: 'INVALID_RESPONSE',
          message: 'Invalid Agent upload response',
          statusCode: response.statusCode,
          requestId: response.headers.value('x-request-id'),
          retryable: true,
        );
      }
      return body;
    } on DioException catch (error) {
      if (error.response == null || CancelToken.isCancel(error)) rethrow;
      throw AgentApiException.fromDioException(error);
    }
  }

  /// Reads extracted text without decoding original PDF or Office bytes.
  Future<Map<String, dynamic>> assetText(
    String assetId, {
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/assets/${Uri.encodeComponent(assetId)}/text',
    cancelToken: cancelToken,
  );

  /// Reads the original upload bytes; parsed document text has its own route.
  Future<Uint8List> readAssetBytes(
    String contentUrl, {
    CancelToken? cancelToken,
  }) async {
    final uri = _ownedAssetContentUri(contentUrl);
    try {
      final response = await dio.get<List<int>>(
        uri.toString(),
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cancelToken,
      );
      final body = response.data;
      if (body == null) {
        throw AgentApiException(
          code: 'INVALID_RESPONSE',
          message: 'Invalid Agent asset response',
          statusCode: response.statusCode,
          requestId: response.headers.value('x-request-id'),
          retryable: true,
        );
      }
      return body is Uint8List ? body : Uint8List.fromList(body);
    } on DioException catch (error) {
      if (error.response == null || CancelToken.isCancel(error)) rethrow;
      throw AgentApiException.fromDioException(error);
    }
  }

  /// Resolves only the owned-asset route on the configured Agent origin.
  /// This prevents an upstream provider URL from becoming an image source.
  String resolveAssetContentUrl(String path) {
    final base = Uri.parse(dio.options.baseUrl);
    if (!base.hasScheme || base.host.isEmpty) {
      throw const FormatException('Agent base URL is not absolute');
    }
    final candidate = Uri.tryParse(path);
    if (candidate == null || candidate.hasScheme || candidate.hasAuthority) {
      throw const FormatException('Asset URL must be Agent-relative');
    }
    final resolved = base.resolveUri(candidate);
    final ownedPath = RegExp(r'^/api_agent/v2/assets/[A-Za-z0-9_-]+/content$');
    if (resolved.scheme != base.scheme ||
        resolved.host != base.host ||
        resolved.port != base.port ||
        !ownedPath.hasMatch(resolved.path) ||
        resolved.hasQuery ||
        resolved.hasFragment) {
      throw const FormatException('Asset URL is outside the Agent origin');
    }
    return resolved.toString();
  }

  /// Resolves only a server-owned video poster on the configured Agent origin.
  String resolveAssetPosterUrl(String path) {
    final base = Uri.parse(dio.options.baseUrl);
    if (!base.hasScheme || base.host.isEmpty) {
      throw const FormatException('Agent base URL is not absolute');
    }
    final candidate = Uri.tryParse(path);
    if (candidate == null || candidate.hasScheme || candidate.hasAuthority) {
      throw const FormatException('Asset poster URL must be Agent-relative');
    }
    final resolved = base.resolveUri(candidate);
    final ownedPath = RegExp(r'^/api_agent/v2/assets/[A-Za-z0-9_-]+/poster$');
    if (resolved.scheme != base.scheme ||
        resolved.host != base.host ||
        resolved.port != base.port ||
        !ownedPath.hasMatch(resolved.path) ||
        resolved.hasQuery ||
        resolved.hasFragment) {
      throw const FormatException(
        'Asset poster URL is outside the Agent origin',
      );
    }
    return resolved.toString();
  }

  /// Resolves only an owned image thumbnail on the configured Agent origin.
  String resolveAssetThumbnailUrl(String path) {
    final base = Uri.parse(dio.options.baseUrl);
    if (!base.hasScheme || base.host.isEmpty) {
      throw const FormatException('Agent base URL is not absolute');
    }
    final candidate = Uri.tryParse(path);
    if (candidate == null ||
        candidate.hasScheme ||
        candidate.hasAuthority ||
        candidate.pathSegments.contains('.') ||
        candidate.pathSegments.contains('..')) {
      throw const FormatException('Asset thumbnail URL must be Agent-relative');
    }
    final resolved = base.resolveUri(candidate);
    final ownedPath = RegExp(
      r'^/api_agent/v2/assets/[A-Za-z0-9_-]+/thumbnail$',
    );
    if (resolved.scheme != base.scheme ||
        resolved.host != base.host ||
        resolved.port != base.port ||
        !ownedPath.hasMatch(resolved.path) ||
        resolved.hasQuery ||
        resolved.hasFragment) {
      throw const FormatException(
        'Asset thumbnail URL is outside the Agent origin',
      );
    }
    return resolved.toString();
  }

  Uri _ownedAssetContentUri(String value) {
    final base = Uri.parse(dio.options.baseUrl);
    if (!base.hasScheme || base.host.isEmpty) {
      throw const FormatException('Agent base URL is not absolute');
    }
    final candidate = Uri.tryParse(value);
    if (candidate == null) throw const FormatException('Invalid asset URL');
    final resolved = candidate.hasScheme
        ? candidate
        : base.resolveUri(candidate);
    final ownedPath = RegExp(r'^/api_agent/v2/assets/[A-Za-z0-9_-]+/content$');
    if (resolved.scheme != base.scheme ||
        resolved.host != base.host ||
        resolved.port != base.port ||
        !ownedPath.hasMatch(resolved.path) ||
        resolved.hasQuery ||
        resolved.hasFragment) {
      throw const FormatException('Asset URL is outside the Agent origin');
    }
    return resolved;
  }

  Future<Map<String, dynamic>> enterHome(
    Map<String, Object?> input, {
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/home/enter',
    method: 'POST',
    receiveTimeout: const Duration(minutes: 1),
    data: input,
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> recommendHomeTopics(
    String sessionId,
    Map<String, Object?> input, {
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/sessions/${Uri.encodeComponent(sessionId)}/topics',
    method: 'POST',
    receiveTimeout: const Duration(minutes: 3),
    data: input,
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> generateHome(
    String sessionId,
    Map<String, Object?> input, {
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/sessions/${Uri.encodeComponent(sessionId)}/generate',
    method: 'POST',
    receiveTimeout: const Duration(minutes: 2),
    data: input,
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> updateSessionCast(
    String sessionId,
    Map<String, Object?> input, {
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/sessions/${Uri.encodeComponent(sessionId)}/cast',
    method: 'PUT',
    data: input,
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> selectHomeTopic(
    String sessionId,
    Map<String, Object?> input, {
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/sessions/${Uri.encodeComponent(sessionId)}/topic',
    method: 'PUT',
    data: input,
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> homeTask(
    String id, {
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/home-tasks/${Uri.encodeComponent(id)}',
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> controlHomeTask(
    String id,
    Map<String, Object?> input, {
    bool confirmVideo = false,
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/home-tasks/${Uri.encodeComponent(id)}/${confirmVideo ? 'confirm-video' : 'control'}',
    method: 'POST',
    data: input,
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> createSession({
    required String clientRequestId,
    String? title,
    String? accountId,
    String? entry,
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/sessions',
    method: 'POST',
    data: {
      'clientRequestId': clientRequestId,
      if (title != null) 'title': title,
      if (accountId != null) 'accountId': accountId,
      if (entry != null) 'entry': entry,
    },
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> createProjectSession(
    String projectId,
    String? title, {
    required String clientRequestId,
    CancelToken? cancelToken,
  }) => createSession(
    clientRequestId: clientRequestId,
    title: title,
    accountId: projectId,
    cancelToken: cancelToken,
  );

  /// Creates a new account and its bound main session from the content entry.
  Future<Map<String, dynamic>> createContentSession({
    required String clientRequestId,
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/sessions/content-entry',
    method: 'POST',
    data: {'clientRequestId': clientRequestId},
    expectedStatusCode: 201,
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> sessionByAccount(
    String accountId, {
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/sessions/by-account/${Uri.encodeComponent(accountId)}',
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> sessionsPage({
    int page = 1,
    int pageSize = 20,
    bool archived = false,
    String? accountId,
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/sessions',
    queryParameters: {
      'page': page,
      'pageSize': pageSize,
      'archived': archived.toString(),
      if (accountId != null) 'accountId': accountId,
    },
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> projectSessionsPage(
    String projectId,
    int page, {
    int pageSize = 20,
    CancelToken? cancelToken,
  }) => sessionsPage(
    page: page,
    pageSize: pageSize,
    accountId: projectId,
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> sessionSnapshot(
    String id, {
    CancelToken? cancelToken,
  }) async {
    if (runtime.enabled(id)) {
      return runtime.request(id, 'snapshot', cancelToken: cancelToken);
    }
    final value = await _request(
      '/api_agent/v2/sessions/${Uri.encodeComponent(id)}/snapshot',
      cancelToken: cancelToken,
    );
    return runtime.enabled(id)
        ? runtime.request(id, 'snapshot', cancelToken: cancelToken)
        : value;
  }

  /// Optional request IDs allow retries to retain their complete input.
  Future<Map<String, dynamic>> updateSession(
    String id, {
    String? clientRequestId,
    String? title,
    bool? archived,
    bool? pinned,
    Map<String, Object?>? configuration,
    int? expectedConfigRevision,
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/sessions/${Uri.encodeComponent(id)}',
    method: 'PATCH',
    data: {
      if (clientRequestId != null) 'clientRequestId': clientRequestId,
      if (title != null) 'title': title,
      if (archived != null) 'archived': archived,
      if (pinned != null) 'pinned': pinned,
      if (configuration != null) 'configuration': configuration,
      if (expectedConfigRevision != null)
        'expectedConfigRevision': expectedConfigRevision,
    },
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> archiveSession(
    String id, {
    String? clientRequestId,
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/sessions/${Uri.encodeComponent(id)}',
    method: 'DELETE',
    data: {if (clientRequestId != null) 'clientRequestId': clientRequestId},
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
    if (archived == true && title == null && pinned == null) {
      await archiveSession(
        id,
        clientRequestId: clientRequestId,
        cancelToken: cancelToken,
      );
      return;
    }
    await updateSession(
      id,
      clientRequestId: clientRequestId,
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
    List<String>? contextRoleIds,
    CancelToken? cancelToken,
  }) => _sessionRequest(
    id,
    'messages',
    method: 'POST',
    data: {
      'clientRequestId': clientRequestId,
      'text': text,
      if (taskId != null) 'taskId': taskId,
      if (mediaIds != null) 'mediaIds': mediaIds,
      if (contextRoleIds != null) 'contextRoleIds': contextRoleIds,
    },
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> stopSession(
    String id, {
    required String clientRequestId,
    CancelToken? cancelToken,
  }) => _sessionRequest(
    id,
    'stop',
    method: 'POST',
    data: {'clientRequestId': clientRequestId},
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> retryRun(
    String runId, {
    required String clientRequestId,
    String? sessionId,
    CancelToken? cancelToken,
  }) => sessionId != null && runtime.enabled(sessionId)
      ? runtime.request(
          sessionId,
          'executions/${Uri.encodeComponent(runId)}/retry',
          method: 'POST',
          data: {'clientRequestId': clientRequestId},
          cancelToken: cancelToken,
        )
      : _request(
          '/api_agent/v2/runs/${Uri.encodeComponent(runId)}/retry',
          method: 'POST',
          data: {'clientRequestId': clientRequestId},
          cancelToken: cancelToken,
        );

  Future<Map<String, dynamic>> respondQuestion(
    String sessionId,
    String questionId, {
    required int revision,
    required String action,
    String? clientRequestId,
    Map<String, Object?>? answer,
    CancelToken? cancelToken,
  }) => _sessionRequest(
    sessionId,
    'questions/${Uri.encodeComponent(questionId)}/respond',
    runtimeSuffix: 'interactions/${Uri.encodeComponent(questionId)}/respond',
    method: 'POST',
    data: {
      'revision': revision,
      'action': action,
      if (clientRequestId != null) 'clientRequestId': clientRequestId,
      if (answer != null) 'answer': answer,
    },
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> respondConfirmation(
    String sessionId,
    String confirmationId, {
    required String clientRequestId,
    required int revision,
    required String action,
    Map<String, Object?>? generationConfig,
    String? planVersionId,
    String? planHash,
    int? mediaPreferencesRevision,
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/sessions/${Uri.encodeComponent(sessionId)}/confirmations/${Uri.encodeComponent(confirmationId)}/respond',
    method: 'POST',
    data: {
      'clientRequestId': clientRequestId,
      'revision': revision,
      'action': action,
      if (generationConfig != null) 'generationConfig': generationConfig,
      if (planVersionId != null) 'planVersionId': planVersionId,
      if (planHash != null) 'planHash': planHash,
      if (mediaPreferencesRevision != null)
        'mediaPreferencesRevision': mediaPreferencesRevision,
    },
    cancelToken: cancelToken,
  );

  /// 首页方案与普通生成确认使用不同的业务入口。
  Future<Map<String, dynamic>> respondHomePlan(
    String sessionId,
    String planId,
    String action,
    Map<String, Object?> input, {
    CancelToken? cancelToken,
  }) {
    if (!['generate', 'cancel'].contains(action)) {
      throw ArgumentError.value(action, 'action');
    }
    return _request(
      '/api_agent/v2/sessions/${Uri.encodeComponent(sessionId)}/home-plans/${Uri.encodeComponent(planId)}/$action',
      method: 'POST',
      data: input,
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, dynamic>> configureRoleImage(
    String sessionId,
    String cardId,
    Map<String, Object?> input, {
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/sessions/${Uri.encodeComponent(sessionId)}/confirmations/${Uri.encodeComponent(cardId)}/configuration',
    method: 'POST',
    data: input,
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> previewGenerationTemplate(
    String sessionId,
    String cardId,
    String? templateId, {
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/sessions/${Uri.encodeComponent(sessionId)}/confirmations/${Uri.encodeComponent(cardId)}/template-preview',
    method: 'POST',
    data: {'roleTemplateId': templateId},
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> taskCapabilities(
    String id, {
    CancelToken? cancelToken,
  }) => _request(
    '/api_agent/v2/tasks/${Uri.encodeComponent(id)}/capabilities',
    cancelToken: cancelToken,
  );

  Future<Map<String, dynamic>> controlTask(
    String id,
    String action,
    Map<String, Object?> input, {
    CancelToken? cancelToken,
  }) {
    if (!['pause', 'resume', 'cancel', 'retry'].contains(action)) {
      throw ArgumentError.value(action, 'action');
    }
    return _request(
      '/api_agent/v2/tasks/${Uri.encodeComponent(id)}/$action',
      method: 'POST',
      data: input,
      cancelToken: cancelToken,
    );
  }

  Future<Map<String, dynamic>> respondProposal(
    String id,
    String action,
    Map<String, Object?> input, {
    CancelToken? cancelToken,
  }) {
    if (!['confirm', 'cancel'].contains(action)) {
      throw ArgumentError.value(action, 'action');
    }
    return _request(
      '/api_agent/v2/proposals/${Uri.encodeComponent(id)}/$action',
      method: 'POST',
      data: input,
      cancelToken: cancelToken,
    );
  }

  /// Returns raw SSE bytes; event parsing and message updates belong outside UI.
  Future<ResponseBody> openSessionEvents(
    String id, {
    int afterSeq = 0,
    String? lastEventId,
    required CancelToken cancelToken,
  }) async {
    if (_closed) throw StateError('Agent transport disposed');
    if (runtime.enabled(id)) return runtime.events(id, cancelToken);
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

  Future<Map<String, dynamic>> _sessionRequest(
    String id,
    String suffix, {
    String? runtimeSuffix,
    String method = 'GET',
    Map<String, Object?>? data,
    CancelToken? cancelToken,
  }) => runtime.enabled(id)
      ? runtime.request(
          id,
          runtimeSuffix ?? suffix,
          method: method,
          data: data,
          cancelToken: cancelToken,
        )
      : _request(
          '/api_agent/v2/sessions/${Uri.encodeComponent(id)}/$suffix',
          method: method,
          data: data,
          cancelToken: cancelToken,
        );

  Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, Object?>? data,
    Map<String, Object?>? queryParameters,
    Duration? receiveTimeout,
    int? expectedStatusCode,
    CancelToken? cancelToken,
  }) async {
    if (_closed) throw StateError('Agent transport disposed');
    try {
      final response = await dio.request<Object?>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(method: method, receiveTimeout: receiveTimeout),
        cancelToken: cancelToken,
      );
      final body = response.data;
      if (body is! Map<String, dynamic> ||
          (expectedStatusCode != null &&
              response.statusCode != expectedStatusCode)) {
        throw AgentApiException(
          code: 'INVALID_RESPONSE',
          message: 'Invalid Agent response',
          statusCode: response.statusCode,
          requestId: response.headers.value('x-request-id'),
          retryable: true,
        );
      }
      runtime.remember(body);
      return body;
    } on DioException catch (error) {
      // Preserve cancellation and transport failures for the caller's lifecycle.
      if (error.response == null || CancelToken.isCancel(error)) rethrow;
      throw AgentApiException.fromDioException(error);
    }
  }
}
