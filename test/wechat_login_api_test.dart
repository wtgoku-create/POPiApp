import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/core/network/network_api.dart';

void main() {
  test('posts the WeChat App authorization code to the backend', () async {
    late RequestOptions request;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': '0000',
                'message': 'ok',
                'data': {
                  'token': 'popi-token',
                  'user': {'id': '1', 'name': '微信用户'},
                },
              },
            ),
          );
        },
      ),
    );

    await NetworkApi(dio).loginByWechatApp(code: 'wechat-auth-code');

    expect(request.path, '/api_client/auth/loginByWxApp');
    expect(request.method, 'POST');
    expect(request.data, {'code': 'wechat-auth-code'});
  });

  test('posts WeChat phone binding details to the backend', () async {
    late RequestOptions request;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': '0000',
                'message': 'ok',
                'data': {
                  'token': 'popi-token',
                  'user': {'id': '1', 'name': '微信用户'},
                },
              },
            ),
          );
        },
      ),
    );

    await NetworkApi(dio).registerWechatAppByPhone(
      registerToken: 'register-token',
      phone: '13097205795',
      code: '123456',
    );

    expect(request.path, '/api_client/auth/wxAppRegisterByPhone');
    expect(request.method, 'POST');
    expect(request.data, {
      'registerToken': 'register-token',
      'phone': '13097205795',
      'code': '123456',
      'inviteCode': '',
    });
  });

  test('accepts the direct response format documented for WeChat login',
      () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'registerToken': 'register-token',
                'needBindPhone': true,
                'user': null,
                'expired': 0,
              },
            ),
          );
        },
      ),
    );

    final result = await NetworkApi(dio).loginByWechatApp(
      code: 'wechat-auth-code',
    );

    expect(result['registerToken'], 'register-token');
    expect(result['needBindPhone'], isTrue);
  });
}
