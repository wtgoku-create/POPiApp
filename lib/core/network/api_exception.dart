import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromDioException(DioException exception) {
    final data = exception.response?.data;
    final responseMessage =
        data is Map<String, dynamic> ? data['message']?.toString() : null;
    return ApiException(
      message: responseMessage ?? exception.message ?? 'Network request failed',
      statusCode: exception.response?.statusCode,
    );
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
