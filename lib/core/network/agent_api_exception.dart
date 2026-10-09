import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Preserves Agent error details needed for conflict recovery and retries.
class AgentApiException extends ApiException {
  const AgentApiException({
    super.message,
    super.statusCode,
    required this.code,
    this.retryable = false,
    this.requestId,
    this.current,
  });

  final String code;
  final bool retryable;
  final String? requestId;
  final Object? current;

  factory AgentApiException.fromDioException(DioException exception) {
    final body = exception.response?.data;
    final root = body is Map ? body : const <String, Object?>{};
    final nested = root['error'];
    final error = nested is Map ? nested : root;
    return AgentApiException(
      statusCode: exception.response?.statusCode,
      code: (root['code'] ?? error['code'])?.toString() ?? 'REQUEST_FAILED',
      message:
          (root['message'] ?? error['message'])?.toString() ??
          exception.response?.statusMessage ??
          exception.message,
      retryable: (root['retryable'] ?? error['retryable']) == true,
      requestId:
          (root['requestId'] ?? error['requestId'])?.toString() ??
          exception.response?.headers.value('x-request-id'),
      current: root['current'] ?? error['current'],
    );
  }
}
