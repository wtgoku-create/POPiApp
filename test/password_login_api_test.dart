import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/auth/data/auth_api.dart';

void main() {
  test('password login follows the web contract', () async {
    RequestOptions? request;
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
                'data': {
                  'token': 'password-token',
                  'user': {'id': '1', 'name': 'Password user'},
                  'expired': 3600,
                },
              },
            ),
          );
        },
      ),
    );
    final api = DefaultAuthApi(NetworkApi(dio));
    final login = api.loginByPassword(
      username: '13800138000',
      password: ' password ',
    );
    final session = await login;
    expect(request!.method, 'POST');
    expect(request!.path, '/api_client/auth/login');
    expect(request!.data, {
      'username': '13800138000',
      'password': ' password ',
    });
    expect(session.accessToken, 'password-token');
    expect(session.user.id, '1');
    expect(session.expiresIn, const Duration(hours: 1));
  });

  test('preserves the backend password error', () async {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {'status': '4000', 'message': 'Incorrect password'},
            ),
          );
        },
      ),
    );
    await expectLater(
      DefaultAuthApi(
        NetworkApi(dio),
      ).loginByPassword(username: '13800138000', password: 'wrong-password'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Incorrect password',
        ),
      ),
    );
  });
}
