import 'package:dio/dio.dart';

import '../storage/secure_storage.dart';
import 'auth_interceptor.dart';

class DioClient {
  DioClient({
    required TokenStorage secureStorage,
    String baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://www.popi.art',
    ),
    bool enableLogging = false,
  }) : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        ) {
    dio.interceptors.add(AuthInterceptor(secureStorage));
    if (enableLogging) {
      dio.interceptors
          .add(LogInterceptor(requestBody: true, responseBody: true));
    }
  }

  final Dio dio;
}
