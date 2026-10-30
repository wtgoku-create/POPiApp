import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_client.dart';
import '../../core/config/app_config.dart';
import '../../core/storage/secure_storage.dart';
import '../../features/demo/domain/harness_access_session.dart';
import 'harness_access_provider.dart';
import 'storage_provider.dart';
import 'user_provider.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = DioClient(secureStorage: ref.watch(secureStorageProvider)).dio;
  if (kIsWeb && AppConfig.businessAgentEnabled) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final path = options.uri.path;
          final userId = ref.read(userProvider)?.id;
          // 登录和当前用户查询负责建立身份，其余业务操作绑定当前标签页账号。
          if (userId != null &&
              options.uri.origin == Uri.parse(AppConfig.apiBaseUrl).origin &&
              path.startsWith('/api_client/') &&
              path != '/api_client/users/user/info' &&
              (!path.startsWith('/api_client/auth/') ||
                  path == '/api_client/auth/logout')) {
            options.headers['X-Popi-User-Id'] = userId;
          }
          handler.next(options);
        },
      ),
    );
  }
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

/// Native Harness clients send the allowed app origin; browsers set it themselves.
final agentDioProvider = Provider<Dio>((ref) {
  final requiresHarnessAccess = !kIsWeb && AppConfig.remoteHarnessEnabled;
  final dio = createAgentDio(
    secureStorage: ref.watch(secureStorageProvider),
    readHarnessAccessSession: requiresHarnessAccess
        ? () => ref.read(harnessAccessProvider).session
        : null,
    onHarnessUnauthorized: requiresHarnessAccess
        ? ref.read(harnessAccessProvider.notifier).invalidate
        : null,
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

@visibleForTesting
Dio createAgentDio({
  required TokenStorage secureStorage,
  String baseUrl = AppConfig.agentApiBaseUrl,
  String origin = AppConfig.agentApiOrigin,
  bool localHarnessEnabled = AppConfig.localHarnessEnabled,
  bool remoteHarnessEnabled = AppConfig.remoteHarnessEnabled,
  bool isWeb = kIsWeb,
  HarnessAccessSession? harnessAccessSession,
  HarnessAccessSession? Function()? readHarnessAccessSession,
  FutureOr<void> Function()? onHarnessUnauthorized,
}) {
  if (localHarnessEnabled && remoteHarnessEnabled) {
    throw StateError(
      'Local and remote Harness transports cannot both be enabled',
    );
  }
  final harnessEnabled = localHarnessEnabled || remoteHarnessEnabled;
  final agentUri = Uri.parse(baseUrl);
  if (localHarnessEnabled) {
    if (!agentUri.hasAuthority ||
        !['http', 'https'].contains(agentUri.scheme) ||
        !['127.0.0.1', 'localhost'].contains(agentUri.host)) {
      throw StateError('The local Harness transport requires a loopback host');
    }
  }
  if (remoteHarnessEnabled) {
    final originUri = Uri.parse(origin);
    if (agentUri.scheme != 'https' ||
        !agentUri.hasAuthority ||
        agentUri.userInfo.isNotEmpty ||
        agentUri.hasQuery ||
        agentUri.hasFragment) {
      throw StateError(
        'The remote Harness transport requires a clean HTTPS URL',
      );
    }
    if (originUri.scheme != 'https' ||
        !originUri.hasAuthority ||
        origin != originUri.origin ||
        originUri.origin != agentUri.origin) {
      throw StateError(
        'The remote Harness Origin must be the Agent HTTPS origin',
      );
    }
  }
  final dio = DioClient(
    secureStorage: secureStorage,
    baseUrl: baseUrl,
    useAuthentication: !harnessEnabled,
    headers: {
      // Browsers own this forbidden header and attach it to cross-origin calls.
      if (!isWeb && origin.isNotEmpty && !remoteHarnessEnabled)
        'Origin': origin,
    },
  ).dio;
  if (!isWeb && remoteHarnessEnabled) {
    HarnessAccessSession? currentSession() =>
        readHarnessAccessSession?.call() ?? harnessAccessSession;
    dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final allowed = _isRemoteHarnessRequest(
            options.uri,
            agentOrigin: agentUri.origin,
          );
          options.headers.removeWhere((name, value) {
            final normalized = name.toLowerCase();
            return normalized == 'cookie' || normalized == 'origin';
          });
          options.followRedirects = false;
          options.maxRedirects = 0;
          if (allowed) {
            options.headers['Origin'] = origin;
            final session = currentSession();
            if (session != null &&
                (session.origin != agentUri.origin ||
                    session.isExpiredAt(DateTime.now().toUtc()))) {
              await onHarnessUnauthorized?.call();
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.cancel,
                  message: 'Remote Harness access expired',
                ),
              );
              return;
            }
            if (session != null) {
              options.headers['Cookie'] = session.cookieHeader;
              options.extra[_harnessSessionNamespaceKey] =
                  session.cacheNamespace;
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final session = currentSession();
          if (error.response?.statusCode == 401 &&
              session != null &&
              error.requestOptions.extra[_harnessSessionNamespaceKey] ==
                  session.cacheNamespace &&
              error.requestOptions.headers['Cookie'] == session.cookieHeader &&
              _isRemoteHarnessRequest(
                error.requestOptions.uri,
                agentOrigin: agentUri.origin,
              )) {
            await onHarnessUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }
  return dio;
}

const _harnessSessionNamespaceKey = 'popiHarnessSessionNamespace';

bool _isRemoteHarnessRequest(Uri uri, {required String agentOrigin}) =>
    uri.scheme == 'https' &&
    uri.userInfo.isEmpty &&
    uri.origin == agentOrigin &&
    !uri.pathSegments.contains('..') &&
    !uri.pathSegments.contains('.') &&
    uri.path.startsWith('/api_agent/');

/// PI Host can use a separate local address while sharing login credentials.
final runtimeDioProvider = Provider<Dio>((ref) {
  final dio = DioClient(
    secureStorage: ref.watch(secureStorageProvider),
    baseUrl: AppConfig.runtimeApiBaseUrl,
    headers: {
      if (AppConfig.agentApiOrigin.isNotEmpty)
        'Origin': AppConfig.agentApiOrigin,
    },
  ).dio;
  ref.onDispose(() => dio.close(force: true));
  return dio;
});
