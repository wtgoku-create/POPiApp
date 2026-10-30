import 'dart:async';
import 'package:dio/dio.dart';
import 'business_web_credentials.dart';

typedef BusinessAgentTransportFactory =
    Dio Function({
      required String baseUrl,
      required String origin,
      required String token,
      required bool isWeb,
      required bool Function() isCurrent,
      required Future<void> Function() onUnauthorized,
    });

/// 请求绑定本次登录凭据，旧 Repository 不会在换号后读取新用户 Token。
Dio createBusinessAgentDio({
  required String baseUrl,
  required String origin,
  required String token,
  required bool isWeb,
  required bool Function() isCurrent,
  required Future<void> Function() onUnauthorized,
  String requestPathPrefix = '/api_agent/v2/',
}) {
  final base = Uri.parse(baseUrl);
  if (!base.hasAuthority ||
      base.userInfo.isNotEmpty ||
      base.hasQuery ||
      base.hasFragment ||
      !['', '/'].contains(base.path) ||
      (base.scheme != 'https' &&
          !(base.scheme == 'http' &&
              ['localhost', '127.0.0.1'].contains(base.host)))) {
    throw StateError('Business Agent requires HTTPS or a loopback endpoint');
  }
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      followRedirects: false,
      maxRedirects: 0,
    ),
  );
  if (isWeb) configureBusinessWebCredentials(dio);
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (!isCurrent() ||
            options.uri.origin != base.origin ||
            options.uri.userInfo.isNotEmpty ||
            !options.uri.path.startsWith(requestPathPrefix)) {
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.cancel,
              message: 'Business session changed or request origin is invalid',
            ),
          );
          return;
        }
        options.headers.removeWhere(
          (key, _) =>
              ['authorization', 'cookie', 'origin'].contains(key.toLowerCase()),
        );
        if (!isWeb) options.headers['Authorization'] = 'Bearer $token';
        if (!isWeb) options.headers['Origin'] = origin;
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (!isCurrent()) {
          handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              type: DioExceptionType.cancel,
            ),
          );
        } else {
          handler.next(response);
        }
      },
      onError: (error, handler) async {
        if ([401, 403].contains(error.response?.statusCode) && isCurrent()) {
          final body = error.response?.data;
          if (error.response?.statusCode == 401 ||
              (body is Map && body['code'] == 'USER_DISABLED')) {
            await onUnauthorized();
          }
        }
        handler.next(error);
      },
    ),
  );
  return dio;
}
