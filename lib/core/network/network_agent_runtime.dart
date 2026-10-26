import 'dart:convert';

import 'package:dio/dio.dart';

import 'agent_api_exception.dart';

/// Fixed Runtime routes use the configured PI Host and login transport.
class NetworkAgentRuntime {
  NetworkAgentRuntime(this._dio);

  final Dio _dio;
  final _sessions = <String, bool>{};
  bool _closed = false;

  bool enabled(String id) => _sessions[id] == true;

  void remember(Map<String, dynamic> value) {
    if (_closed) return;
    final id = value['id'];
    if (id is String &&
        (value.containsKey('runtimeDirect') ||
            value.containsKey('accountId') ||
            value.containsKey('title'))) {
      _sessions[id] = value['runtimeDirect'] == true;
    }
    final session = value['session'];
    if (session is Map<String, dynamic>) remember(session);
    final list = value['list'];
    if (list is List) {
      for (final item in list.whereType<Map<String, dynamic>>()) {
        remember(item);
      }
    }
  }

  Future<Response<Object?>> _request(
    String id,
    String suffix, {
    String method = 'GET',
    Map<String, Object?>? data,
    bool stream = false,
    CancelToken? cancelToken,
  }) async {
    if (_closed) throw StateError('Runtime transport disposed');
    try {
      final response = await _dio.request<Object?>(
        '/runtime/v2/sessions/${Uri.encodeComponent(id)}/$suffix',
        data: data,
        options: Options(
          method: method,
          responseType: stream ? ResponseType.stream : ResponseType.json,
          followRedirects: false,
          maxRedirects: 0,
          receiveTimeout: stream ? Duration.zero : const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
          headers: {
            'Accept': stream ? 'text/event-stream' : 'application/json',
            if (data != null) 'Content-Type': 'application/json',
          },
        ),
        cancelToken: cancelToken,
      );
      return response;
    } on DioException catch (error) {
      if (error.response == null || CancelToken.isCancel(error)) rethrow;
      final body = error.response?.data;
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

  Future<Map<String, dynamic>> request(
    String id,
    String suffix, {
    String method = 'GET',
    Map<String, Object?>? data,
    CancelToken? cancelToken,
  }) async {
    final response = await _request(
      id,
      suffix,
      method: method,
      data: data,
      cancelToken: cancelToken,
    );
    final body = response.data;
    if (body is! Map<String, dynamic>) {
      throw const AgentApiException(
        code: 'INVALID_RESPONSE',
        message: 'Invalid Runtime response',
      );
    }
    if (suffix == 'snapshot') validateRuntimeSnapshot(id, body);
    return body;
  }

  Future<ResponseBody> events(String id, CancelToken cancelToken) async {
    final response = await _request(
      id,
      'events',
      stream: true,
      cancelToken: cancelToken,
    );
    final body = response.data;
    if (body is! ResponseBody ||
        response.headers.value('content-type')?.split(';').first.trim() !=
            'text/event-stream') {
      if (body is ResponseBody) await body.stream.listen(null).cancel();
      throw const AgentApiException(
        code: 'INVALID_RUNTIME_EVENT',
        message: 'Invalid Runtime event stream',
      );
    }
    return body;
  }

  void close() {
    _closed = true;
    _sessions.clear();
  }
}

/// Runtime SSE contains complete Host snapshots rather than legacy deltas.
void validateRuntimeSnapshot(String id, Map<String, Object?> value) {
  final session = value['session'];
  final seq = value['lastSeq'];
  if (session is! Map ||
      session['id'] != id ||
      seq is! int ||
      seq < 0 ||
      seq > 9007199254740991 ||
      value['timelineVersion'] != 1 ||
      value['timelineMessages'] is! List ||
      value['runs'] is! List ||
      value['messages'] is! List) {
    throw const AgentApiException(
      code: 'INVALID_RUNTIME_SNAPSHOT',
      statusCode: 502,
      message: 'Invalid Runtime snapshot',
    );
  }
}
