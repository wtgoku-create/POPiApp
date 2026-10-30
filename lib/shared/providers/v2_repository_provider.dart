import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/business_agent_transport.dart';
import '../../core/network/network_agent_api.dart';
import '../../core/network/network_api.dart';
import '../../features/v2_shared/data/v2_remote_repository.dart';
import '../../features/v2_shared/data/v2_repository.dart';
import 'storage_provider.dart';
import 'user_provider.dart';

final v2TransportFactoryProvider = Provider<BusinessAgentTransportFactory>(
  (ref) => createBusinessAgentDio,
);

/// A login owns its transports and polling; changing accounts disposes both.
final v2RepositoryProvider = FutureProvider.autoDispose<V2Repository?>((
  ref,
) async {
  final owner = ref.watch(userProvider.select((user) => user?.id));
  if (owner == null) return null;
  var active = true;
  ref.onDispose(() => active = false);
  bool current() => active && ref.read(userProvider)?.id == owner;
  final token = kIsWeb
      ? ''
      : await ref.read(secureStorageProvider).readAccessToken();
  if (!current()) return null;
  if (!kIsWeb && (token == null || token.isEmpty)) {
    await ref.read(userProvider.notifier).expireSession(owner);
    return null;
  }
  Future<void> unauthorized() async {
    if (current()) await ref.read(userProvider.notifier).expireSession(owner);
  }

  Dio transport(String baseUrl, String prefix) {
    final dio = createBusinessAgentDio(
      baseUrl: baseUrl,
      origin: AppConfig.agentApiOrigin,
      token: token ?? '',
      isWeb: kIsWeb,
      isCurrent: current,
      onUnauthorized: unauthorized,
      requestPathPrefix: prefix,
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['X-Popi-User-Id'] = owner;
          handler.next(options);
        },
      ),
    );
    ref.onDispose(() => dio.close(force: true));
    return dio;
  }

  final factory = ref.read(v2TransportFactoryProvider);
  final agent = factory(
    baseUrl: AppConfig.agentApiBaseUrl,
    origin: AppConfig.agentApiOrigin,
    token: token ?? '',
    isWeb: kIsWeb,
    isCurrent: current,
    onUnauthorized: unauthorized,
  );
  agent.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['X-Popi-User-Id'] = owner;
        handler.next(options);
      },
    ),
  );
  ref.onDispose(() => agent.close(force: true));
  Map<String, String> headers(String value) {
    final uri = Uri.tryParse(value);
    final base = Uri.parse(AppConfig.agentApiBaseUrl);
    if (!current() ||
        uri == null ||
        !uri.hasAuthority ||
        uri.origin != base.origin ||
        uri.userInfo.isNotEmpty ||
        !uri.path.startsWith('/api_agent/v2/')) {
      return {};
    }
    return {
      if (!kIsWeb) 'Authorization': 'Bearer ${token ?? ''}',
      'X-Popi-User-Id': owner,
      if (!kIsWeb && AppConfig.agentApiOrigin.isNotEmpty)
        'Origin': AppConfig.agentApiOrigin,
    };
  }

  final repository = V2RemoteRepository(
    ref.read(preferencesStorageProvider),
    NetworkAgentApi(agent),
    ownerId: owner,
    namespace: 'popi_v2:${AppConfig.agentApiBaseUrl}:$owner',
    mediaHeaders: headers,
    libraryApi: NetworkApi(
      transport(AppConfig.apiBaseUrl, '/api_client/asset-library/'),
    ),
  )..restore();
  ref.onDispose(repository.dispose);
  await repository.refresh();
  return current() ? repository : null;
});
