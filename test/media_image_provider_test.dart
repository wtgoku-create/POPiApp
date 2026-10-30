import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/config/app_config.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/network/media_image_repository.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/storage/app_image_cache.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/shared/providers/media_image_provider.dart';
import 'package:popi_ai_app/shared/providers/network_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

const _path = '/api_client/agent/v2/media/16524/content';

void main() {
  test(
    'relative image URLs resolve against the configured business server',
    () {
      expect(
        AppImageCache.resolveUrl('/avatars/a.png'),
        '${AppConfig.apiBaseUrl}/avatars/a.png',
      );
      const absolute = 'https://cdn.example/avatar.png?signature=original';
      expect(AppImageCache.resolveUrl(absolute), absolute);
    },
  );

  test(
    'only configured business media endpoints use authenticated transport',
    () {
      expect(MediaImageRepository.protectedMediaId(_path), '16524');
      expect(
        MediaImageRepository.protectedMediaId('${AppConfig.apiBaseUrl}$_path'),
        '16524',
      );
      for (final url in [
        'https://external.example$_path',
        '//external.example$_path',
        '${AppConfig.apiBaseUrl}.external.example$_path',
        'data:image/png;base64,abc',
        '/api_client/agent/v2/media/16524',
        '/api_client/agent/v2/media/not-an-id/content',
      ]) {
        expect(MediaImageRepository.protectedMediaId(url), isNull, reason: url);
      }
    },
  );

  test('redirect resolution stops before the CDN request', () async {
    final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
    addTearDown(dio.close);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.method, 'GET');
          expect(options.path, _path);
          expect(options.followRedirects, isFalse);
          expect(options.validateStatus(307), isTrue);
          expect(options.validateStatus(401), isFalse);
          handler.resolve(
            Response<void>(
              requestOptions: options,
              statusCode: 307,
              headers: Headers.fromMap({
                'location': [
                  'https://cdn.example/avatar.png?signature=current',
                ],
              }),
            ),
          );
        },
      ),
    );
    expect(
      await MediaImageRepository(NetworkApi(dio)).resolve(_path),
      'https://cdn.example/avatar.png?signature=current',
    );
  });

  test(
    'missing or unsafe redirects fail instead of loading empty avatars',
    () async {
      final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
      addTearDown(dio.close);
      String? location;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.resolve(
            Response<void>(
              requestOptions: options,
              statusCode: 307,
              headers: Headers.fromMap({
                if (location != null) 'location': [location],
              }),
            ),
          ),
        ),
      );
      for (final value in [
        null,
        '',
        'file:///tmp/avatar.png',
        'data:image/png,abc',
      ]) {
        location = value;
        await expectLater(
          NetworkApi(dio).mediaImageUrl('16524'),
          throwsA(isA<ApiException>()),
        );
      }
    },
  );

  test(
    'visible images share resolution and account changes clear it',
    () async {
      final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
      addTearDown(dio.close);
      var requests = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            handler.resolve(
              Response<void>(
                requestOptions: options,
                statusCode: 307,
                headers: Headers.fromMap({
                  'location': ['https://cdn.example/avatar.png?v=$requests'],
                }),
              ),
            );
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);
      final provider = mediaImageUrlProvider(_path);
      final listener = container.listen(provider, (_, __) {});
      addTearDown(listener.close);
      final first = await container.read(provider.future);
      expect(first, 'https://cdn.example/avatar.png?v=1');
      expect(await container.read(provider.future), first);
      expect(requests, 1);
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: 'another', name: '', email: ''));
      expect(
        await container.read(provider.future),
        'https://cdn.example/avatar.png?v=2',
      );
      expect(requests, 2);
    },
  );

  test(
    'an authentication failure is exposed and invalidation can recover',
    () async {
      final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
      addTearDown(dio.close);
      var failed = true;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (failed) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response<void>(
                    requestOptions: options,
                    statusCode: 401,
                  ),
                ),
              );
            } else {
              handler.resolve(
                Response<void>(
                  requestOptions: options,
                  statusCode: 307,
                  headers: Headers.fromMap({
                    'location': ['https://cdn.example/avatar.png'],
                  }),
                ),
              );
            }
          },
        ),
      );
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);
      final provider = mediaImageUrlProvider(_path);
      final listener = container.listen(provider, (_, __) {});
      addTearDown(listener.close);
      await expectLater(
        container.read(provider.future),
        throwsA(isA<DioException>()),
      );
      expect(container.read(provider).hasError, isTrue);
      failed = false;
      container.invalidate(provider);
      expect(
        await container.read(provider.future),
        'https://cdn.example/avatar.png',
      );
    },
  );
}
