import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/business_agent_transport.dart';
import 'package:popi_ai_app/core/storage/secure_storage.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/shared/providers/business_agent_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

void main() {
  test(
    'business identity uses existing login without a handshake and changes with account',
    () async {
      final storage = _Tokens()..token = 'token-a';
      final adapters = <_IdentityAdapter>[];
      ProviderContainer createContainer() => ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(storage),
          businessAgentTransportFactoryProvider.overrideWithValue(({
            required baseUrl,
            required origin,
            required token,
            required isWeb,
            required isCurrent,
            required onUnauthorized,
          }) {
            final adapter = _IdentityAdapter(
              token == 'token-a' ? '101' : '102',
            );
            adapters.add(adapter);
            return createBusinessAgentDio(
              baseUrl: baseUrl,
              origin: origin,
              token: token,
              isWeb: isWeb,
              isCurrent: isCurrent,
              onUnauthorized: onUnauthorized,
            )..httpClientAdapter = adapter;
          }),
        ],
      );
      final container = createContainer();
      addTearDown(container.dispose);
      container.listen(businessAgentSessionProvider, (_, _) {});
      expect(await container.read(businessAgentSessionProvider.future), isNull);
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: '101', name: 'A', email: ''));
      final a = (await container.read(businessAgentSessionProvider.future))!;
      expect(a.userId, '101');
      expect(adapters.single.calls, 0);
      await a.dio.get<Object?>('/api_agent/v2/assets');
      expect(adapters.single.calls, 1);
      expect(a.mediaHeaders('https://untrusted.example/file'), isEmpty);
      storage.token = 'token-b';
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: '102', name: 'B', email: ''));
      final b = (await container.read(businessAgentSessionProvider.future))!;
      expect(b.userId, '102');
      expect(b.cacheNamespace, isNot(a.cacheNamespace));
      expect(adapters.first.closed, true);
      await a.invalidate();
      expect(container.read(userProvider)?.id, '102');
      await b.invalidate();
      expect(container.read(userProvider), isNull);
      expect(storage.token, isNull);
      expect(await container.read(businessAgentSessionProvider.future), isNull);

      storage.token = 'token-a';
      final restored = createContainer();
      addTearDown(restored.dispose);
      restored.listen(businessAgentSessionProvider, (_, _) {});
      await restored
          .read(userProvider.notifier)
          .setUser(const User(id: '101', name: 'A', email: ''));
      final session = (await restored.read(
        businessAgentSessionProvider.future,
      ))!;
      expect(session.userId, '101');
      expect(session.cacheNamespace, isNot(a.cacheNamespace));
    },
  );

  test(
    'missing native login token clears local user without a handshake',
    () async {
      final storage = _Tokens();
      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      container.listen(businessAgentSessionProvider, (_, _) {});
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: '101', name: 'A', email: ''));
      try {
        await container.read(businessAgentSessionProvider.future);
      } on Object {
        /* 失效会销毁正在等待的身份请求。 */
      }
      expect(container.read(userProvider), isNull);
      expect(storage.token, isNull);
    },
  );
}

class _Tokens implements TokenStorage {
  String? token;
  @override
  Future<String?> readAccessToken() async => token;
  @override
  Future<void> writeAccessToken(String value) async {
    token = value;
  }

  @override
  Future<void> deleteAccessToken() async {
    token = null;
  }
}

class _IdentityAdapter implements HttpClientAdapter {
  _IdentityAdapter(this.userId);
  final String userId;
  var calls = 0;
  var closed = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    expect(options.uri.path, isNot('/api_agent/v2/auth/session'));
    expect(options.headers['X-Popi-User-Id'], userId);
    return ResponseBody.fromString(
      jsonEncode({
        'userId': userId,
        'expiresAt': DateTime.now()
            .add(const Duration(hours: 1))
            .toIso8601String(),
      }),
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {
    closed = true;
  }
}
