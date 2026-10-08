import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/features/profile/data/social_app_binding_api.dart';
import 'package:popi_ai_app/features/profile/domain/social_app_binding.dart';
import 'package:popi_ai_app/shared/type/social_app_type.dart';

void main() {
  late SocialAppBindingApi api;
  late RequestOptions request;
  late Map<String, dynamic> response;

  setUp(() {
    response = {
      'status': '0000',
      'message': 'ok',
      'data': {'bound': false, 'nickname': '', 'avatar': ''},
    };
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: response,
            ),
          );
        },
      ),
    );
    api = SocialAppBindingApi(dio);
  });

  test('queries WeChat with GET and no authorization code', () async {
    final binding = await api.fetchStatus(SocialAppType.wechat);
    expect(request.path, '/api_client/users/user/wxAppBindStatus');
    expect(request.method, 'GET');
    expect(request.data, isNull);
    expect(binding.bound, isFalse);
  });

  test('queries Douyin with GET and no authorization code', () async {
    await api.fetchStatus(SocialAppType.douyin);
    expect(request.path, '/api_client/users/user/douyinAppBindStatus');
    expect(request.method, 'GET');
    expect(request.data, isNull);
  });

  for (final app in SocialAppType.values) {
    test('binds $app using the real authorization code', () async {
      response['data'] = {
        'status': 'success',
        'bound': true,
        'nickname': 'Social nickname',
        'avatar': 'https://example.com/avatar.png',
      };
      final binding = await api.bind(app, 'real-code');
      expect(
        request.path,
        app == SocialAppType.wechat
            ? '/api_client/users/user/bindWxAppByCode'
            : '/api_client/users/user/bindDouyinAppByCode',
      );
      expect(request.method, 'POST');
      expect(request.data, {'code': 'real-code'});
      expect(binding.bound, isTrue);
      expect(binding.nickname, 'Social nickname');
      expect(binding.avatar, 'https://example.com/avatar.png');
    });
  }

  test('rejects unsuccessful envelopes', () async {
    response['status'] = '1001';
    response['message'] = 'Already linked to another user';
    await expectLater(
      api.fetchStatus(SocialAppType.wechat),
      throwsA(isA<ApiException>()),
    );
    await expectLater(
      api.bind(SocialAppType.douyin, 'code'),
      throwsA(isA<ApiException>()),
    );
  });

  test('does not interpret a missing bound value as unbound', () async {
    response['data'] = <String, dynamic>{};
    await expectLater(
      api.fetchStatus(SocialAppType.wechat),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'rejects an unsuccessful binding result inside a success envelope',
    () async {
      await expectLater(
        api.bind(SocialAppType.wechat, 'code'),
        throwsA(isA<SocialBindingException>()),
      );
      response['data'] = {'status': 'failed', 'bound': true};
      await expectLater(
        api.bind(SocialAppType.wechat, 'code'),
        throwsA(isA<SocialBindingException>()),
      );
    },
  );

  test('rejects empty authorization codes', () async {
    await expectLater(
      api.bind(SocialAppType.wechat, ' '),
      throwsA(isA<FormatException>()),
    );
  });
}
