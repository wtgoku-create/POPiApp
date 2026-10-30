import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:popi_ai_app/core/network/business_agent_transport.dart';
import 'package:popi_ai_app/core/storage/secure_storage.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/v2_shared/data/v2_remote_repository.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/providers/v2_repository_provider.dart';
import 'package:popi_ai_app/shared/widgets/app_authenticated_image.dart';

class _Tokens implements TokenStorage {
  String? token = 'token-one';
  @override
  Future<String?> readAccessToken() async => token;
  @override
  Future<void> writeAccessToken(String value) async => token = value;
  @override
  Future<void> deleteAccessToken() async => token = null;
}

void main() {
  test(
    'transport binds credentials and rejects foreign paths and old responses',
    () async {
      var current = true;
      var expired = 0;
      final dio = createBusinessAgentDio(
        baseUrl: 'https://agent.example',
        origin: 'https://app.example',
        token: 'captured-token',
        isWeb: false,
        isCurrent: () => current,
        onUnauthorized: () async => expired++,
      );
      addTearDown(() => dio.close(force: true));
      final pending = Completer<void>();
      var reachedServer = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) async {
            reachedServer++;
            expect(o.headers['Authorization'], 'Bearer captured-token');
            expect(o.headers['Cookie'], isNull);
            if (o.path.endsWith('/snapshot')) await pending.future;
            h.resolve(
              Response(
                requestOptions: o,
                statusCode: 200,
                data: <String, Object?>{},
              ),
            );
          },
        ),
      );
      await dio.get<Object?>(
        '/api_agent/v2/sessions',
        options: Options(headers: {'Cookie': 'wrong'}),
      );
      await expectLater(
        dio.get<Object?>('https://cdn.example/private'),
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      await expectLater(
        dio.get<Object?>('/api_client/profile'),
        throwsA(isA<DioException>()),
      );
      expect(reachedServer, 1);
      final old = dio.get<Object?>('/api_agent/v2/sessions/id/snapshot');
      await Future<void>.delayed(Duration.zero);
      current = false;
      pending.complete();
      await expectLater(old, throwsA(isA<DioException>()));
      expect(expired, 0);
    },
  );

  test(
    'repository provider restores account completion and clears state on logout',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final tokens = _Tokens();
      final validity = <bool Function()>[];
      final capturedTokens = <String>[];
      final transports = <Dio>[];
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          secureStorageProvider.overrideWithValue(tokens),
          v2TransportFactoryProvider.overrideWithValue(({
            required String baseUrl,
            required String origin,
            required String token,
            required bool isWeb,
            required bool Function() isCurrent,
            required Future<void> Function() onUnauthorized,
          }) {
            validity.add(isCurrent);
            capturedTokens.add(token);
            final dio = Dio(BaseOptions(baseUrl: baseUrl))
              ..interceptors.add(
                InterceptorsWrapper(
                  onRequest: (o, h) => h.resolve(
                    Response(
                      requestOptions: o,
                      statusCode: 200,
                      data: <String, Object?>{
                        'list': <Object>[],
                        'pageInfo': {'pageCount': 1},
                      },
                    ),
                  ),
                ),
              );
            transports.add(dio);
            return dio;
          }),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(v2RepositoryProvider, (_, _) {});
      addTearDown(subscription.close);
      expect(await container.read(v2RepositoryProvider.future), isNull);
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: 'one', name: 'One', email: ''));
      final first =
          (await container.read(v2RepositoryProvider.future))!
              as V2RemoteRepository;
      expect(first.sessions, isEmpty);
      expect(first.hasCompletedOnboarding('one'), isFalse);
      expect(validity.single(), isTrue);
      tokens.token = 'token-two';
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: 'two', name: 'Two', email: ''));
      final second =
          (await container.read(v2RepositoryProvider.future))!
              as V2RemoteRepository;
      expect(capturedTokens, ['token-one', 'token-two']);
      expect(validity.first(), isFalse);
      expect(second.ownerId, 'two');
      await expectLater(first.refresh(), throwsStateError);
      final url =
          '${transports.last.options.baseUrl}/api_agent/v2/assets/asset/content';
      expect(second.mediaHeaders(url)['Authorization'], 'Bearer token-two');
      expect(
        second.mediaHeaders('https://cdn.example/media/image.png'),
        isEmpty,
      );
      expect(second.mediaHeaders(''), isEmpty);
      await container.read(userProvider.notifier).expireSession('one');
      expect(container.read(userProvider)?.id, 'two');
      await container.read(userProvider.notifier).expireSession('two');
      expect(await container.read(v2RepositoryProvider.future), isNull);
      expect(validity.last(), isFalse);
      expect(tokens.token, isNull);
      await expectLater(second.refresh(), throwsStateError);
    },
  );

  test('private image cache identity includes credentials', () {
    const first = AppAuthenticatedImage(
      'https://agent.example/image',
      headers: {'Authorization': 'one'},
    );
    const second = AppAuthenticatedImage(
      'https://agent.example/image',
      headers: {'Authorization': 'two'},
    );
    expect(first, isNot(second));
    expect(
      first,
      const AppAuthenticatedImage(
        'https://agent.example/image',
        headers: {'Authorization': 'one'},
      ),
    );
  });
}
