import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/core/network/network_api.dart';

void main() {
  test('posts the WeChat authorization code to the backend', () async {
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

    await NetworkApi(dio).loginByWechat(code: 'wechat-auth-code');

    expect(request.path, '/api_client/auth/loginByWechat');
    expect(request.method, 'POST');
    expect(request.data, {'code': 'wechat-auth-code'});
  });
}
