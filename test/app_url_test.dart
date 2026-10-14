import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/config/app_config.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/utils/app_url.dart';
import 'package:popi_ai_app/features/assets/domain/library_role.dart';
import 'package:popi_ai_app/features/assets/domain/library_work.dart';
import 'package:popi_ai_app/features/auth/domain/captcha_challenge.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/ip_accounts/domain/account_preferences.dart';
import 'package:popi_ai_app/features/profile/domain/product_plan.dart';
import 'package:popi_ai_app/features/profile/domain/social_app_binding.dart';
import 'package:popi_ai_app/features/redemption/domain/redemption.dart';
import 'package:popi_ai_app/features/session/domain/conversation_generation.dart';
import 'package:popi_ai_app/features/session/domain/conversation_role_profile.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';

void main() {
  group('AppUrl.resolve', () {
    test('preserves complete URLs byte for byte', () {
      for (final url in [
        'https://CDN.example:443/a/../image.png?sig=%2f%2B&x=1+x#preview',
        'http://localhost:9000/media/video.mp4?token=original',
        'data:image/png;base64,aGVsbG8=',
      ]) {
        expect(AppUrl.resolve(url), url);
      }
    });

    test('completes root paths with the configured environment', () {
      expect(
        AppUrl.resolve('/api_client/agent/v2/media/16524/content'),
        '${AppConfig.apiBaseUrl}/api_client/agent/v2/media/16524/content',
      );
    });

    test('resolves relative paths, queries and network paths structurally', () {
      const base = 'https://api.example:8443/v2/';
      for (final entry in {
        'media/a.png': '${base}media/a.png',
        '../media/a.png?size=2#preview':
            'https://api.example:8443/media/a.png?size=2#preview',
        '/media/a.png': 'https://api.example:8443/media/a.png',
        '//cdn.example/a.png': 'https://cdn.example/a.png',
        '?version=2': '$base?version=2',
      }.entries) {
        expect(AppUrl.resolve(entry.key, baseUrl: base), entry.value);
      }
    });

    test('preserves missing values and local assets', () {
      expect(AppUrl.resolve(''), '');
      expect(AppUrl.resolveNullable(null), isNull);
      expect(AppUrl.resolveNullable(''), '');
      expect(
        AppUrl.resolve('assets/images/role.png'),
        'assets/images/role.png',
      );
    });

    test('does not rewrite malformed values or unsupported schemes', () {
      expect(AppUrl.resolve('http://[invalid'), 'http://[invalid');
      expect(AppUrl.resolve('javascript:alert(1)'), 'javascript:alert(1)');
      expect(redemptionImageUrl('javascript:alert(1)'), isNull);
    });

    test('repeated resolution keeps signed addresses intact', () {
      const url = 'https://CDN.example:443/image.png?signature=%2f%2B';
      expect(AppUrl.resolve(AppUrl.resolve(url)), url);
    });
  });

  test('upload results use the actual API base URL', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.example'));
    addTearDown(dio.close);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) => handler.resolve(
          Response(
            requestOptions: request,
            data: {
              'status': '0000',
              'data': {'url': '/media/avatar.png'},
            },
          ),
        ),
      ),
    );
    expect(
      await NetworkApi(dio).uploadAvatar(bytes: [1], filename: 'avatar.png'),
      'https://api.example/media/avatar.png',
    );
  });

  test('image redirects share resolution and preserve signed URLs', () async {
    const signed = 'https://CDN.example:443/image.png?sig=%2f%2B';
    for (final location in ['../preview.png', signed]) {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example'));
      addTearDown(dio.close);
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) => handler.resolve(
            Response<void>(
              requestOptions: request,
              statusCode: 307,
              headers: Headers.fromMap({
                'location': [location],
              }),
            ),
          ),
        ),
      );
      expect(
        await NetworkApi(dio).mediaImageUrl('16524'),
        location == signed
            ? signed
            : 'https://api.example/api_client/agent/v2/media/preview.png',
      );
    }
  });

  test('API image models consistently complete relative paths', () {
    const path = '/media/image.png';
    const expected = '${AppConfig.apiBaseUrl}$path';
    final block = ConversationBlock.fromJson({
      'type': 'object',
      'kind': 'role',
      'action': 'edited',
      'data': {'avatar': path, 'threeViewImage': path},
    });
    final captcha = CaptchaChallenge.fromJson({
      'id': 'captcha',
      'bgUrl': path,
      'puzzleUrl': path,
    });
    final urls = [
      LibraryRole.fromJson({'id': 1, 'avatar': path}).avatar,
      LibraryRole.fromJson({'id': 1, 'threeViewImage': path}).avatar,
      User.fromJson({'avatar': path}).avatarUrl,
      AccountPreferenceOption.fromJson({
        'name': 'style',
        'imageUrl': path,
      }).imageUrl,
      ProductPlan.fromJson({'image': path}).image,
      SocialAppBinding.fromJson({'bound': true, 'avatar': path}).avatar,
      ConversationRoleTemplate.fromJson({
        'id': 1,
        'title': 'style',
        'coverUrl': path,
      }).coverUrl,
      captcha.bgUrl,
      captcha.puzzleUrl,
      WechatBindingQrCode.fromJson({
        'sceneCode': 'scene',
        'qrCodeUrl': path,
      }).url,
      block.avatar,
      ConversationRoleProfile.fromBlock(block).portrait,
    ];
    expect(urls, everyElement(expected));
    expect(User.fromJson({}).avatarUrl, isNull);
    expect(
      AccountPreferenceOption.fromJson({'name': 'style'}).imageUrl,
      isNull,
    );
  });

  test(
    'work results complete relative paths and preserve absolute addresses',
    () {
      const signed = 'https://CDN.example:443/image.png?sig=%2f%2B';
      const video = 'http://localhost:9000/media/video.mp4';
      final page = LibraryWorkPage.fromJson(
        {
          'list': [
            {
              'type': 2,
              'status': 2,
              'resultList': [
                {'id': 1, 'video': video, 'cover': signed},
                {
                  'id': 2,
                  'images': ['/media/image.png'],
                },
              ],
            },
          ],
        },
        page: 1,
        pageSize: 20,
        mediaBaseUrl: 'https://api.example',
      );
      expect(page.items.first.previewUrl, signed);
      expect(page.items.first.videoUrl, video);
      expect(page.items.last.previewUrl, 'https://api.example/media/image.png');
      expect(page.items.last.videoUrl, '');
    },
  );
}
