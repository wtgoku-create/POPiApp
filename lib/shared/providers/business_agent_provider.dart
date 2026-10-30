import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/config/app_config.dart';
import '../../core/network/business_agent_transport.dart';
import '../../core/network/network_api.dart';
import 'storage_provider.dart';
import 'user_provider.dart';

final businessAgentTransportFactoryProvider =
    Provider<BusinessAgentTransportFactory>((ref) => createBusinessAgentDio);

class BusinessAgentSession {
  const BusinessAgentSession({
    required this.userId,
    required this.token,
    required this.dio,
    required this.cacheNamespace,
    required this.invalidate,
    this.libraryApi,
  });
  final String userId;
  final String token;
  final Dio dio;
  final String cacheNamespace;
  final Future<void> Function() invalidate;
  final NetworkApi? libraryApi;

  Map<String, String> mediaHeaders(String value) {
    final uri = Uri.tryParse(value);
    final base = Uri.parse(dio.options.baseUrl);
    if (uri == null) return const {};
    final resolved = base.resolveUri(uri);
    if (resolved.origin != base.origin ||
        resolved.userInfo.isNotEmpty ||
        !resolved.path.startsWith('/api_agent/v2/')) {
      return const {};
    }
    // Web 图片缓存请求不会默认发送跨源 Cookie，需显式携带当前用户凭据。
    return {
      if (!kIsWeb) 'Authorization': 'Bearer $token',
      'X-Popi-User-Id': userId,
      if (!kIsWeb) 'Origin': AppConfig.agentApiOrigin,
    };
  }
}

/// 仅在已有业务用户初始化完成后建立 Agent 身份；不保存 Token 到普通缓存。
final businessAgentSessionProvider =
    FutureProvider.autoDispose<BusinessAgentSession?>((ref) async {
      final userId = ref.watch(userProvider.select((user) => user?.id));
      if (userId == null) return null;
      var active = true;
      ref.onDispose(() => active = false);
      final storage = ref.read(secureStorageProvider);
      final token = kIsWeb ? '' : await storage.readAccessToken();
      if (!active) return null;
      if (!kIsWeb && (token == null || token.isEmpty)) {
        await ref.read(userProvider.notifier).expireSession(userId);
        return null;
      }
      bool isCurrent() => active && ref.read(userProvider)?.id == userId;
      Future<void> invalidate() async {
        if (isCurrent()) {
          await ref.read(userProvider.notifier).expireSession(userId);
        }
      }

      final dio = ref.read(businessAgentTransportFactoryProvider)(
        baseUrl: AppConfig.agentApiBaseUrl,
        origin: AppConfig.agentApiOrigin,
        token: token ?? '',
        isWeb: kIsWeb,
        isCurrent: isCurrent,
        onUnauthorized: invalidate,
      );
      ref.onDispose(() => dio.close(force: true));
      final libraryDio = createBusinessAgentDio(
        baseUrl: AppConfig.apiBaseUrl,
        origin: AppConfig.apiBaseUrl,
        token: token ?? '',
        isWeb: kIsWeb,
        isCurrent: isCurrent,
        onUnauthorized: invalidate,
        requestPathPrefix: '/api_client/asset-library/',
      );
      ref.onDispose(() => libraryDio.close(force: true));
      for (final transport in [dio, libraryDio]) {
        transport.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              options.headers['X-Popi-User-Id'] = userId;
              handler.next(options);
            },
          ),
        );
      }
      return BusinessAgentSession(
        userId: userId,
        token: token ?? '',
        dio: dio,
        cacheNamespace: const Uuid().v4(),
        invalidate: invalidate,
        libraryApi: NetworkApi(libraryDio),
      );
    });
