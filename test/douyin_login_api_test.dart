import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/auth/data/douyin_auth_api.dart';
import 'package:popi_ai_app/features/auth/domain/douyin_app_login.dart';

void main() {
  late RequestOptions request;
  late Map<String, dynamic> response;
  late DefaultDouyinAuthApi api;

  setUp(() {
    response = {
      'token': 'douyin-token',
      'user': <String, dynamic>{},
      'expired': 200000,
    };
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      request = options;
      handler.resolve(Response<Map<String, dynamic>>(
        requestOptions: options,
        statusCode: 200,
        data: response,
      ));
    }));
    api = DefaultDouyinAuthApi(NetworkApi(dio));
  });

  test('posts authorization code and parses existing user session', () async {
    final result = await api.loginByDouyinApp(code: 'authorization-code');
    expect(request.path, '/api_client/auth/loginByDouyinCode');
    expect(request.method, 'POST');
    expect(request.data, {'code': 'authorization-code'});
    final session = (result as DouyinAppLoginSucceeded).session;
    expect(session.accessToken, 'douyin-token');
    expect(session.expiresIn, const Duration(seconds: 200000));
  });

  test('requires phone binding when needBindPhone is true', () async {
    response = {
      'registerToken': 'register-token',
      'needBindPhone': true,
      'user': null,
      'expired': 0,
    };
    final result = await api.loginByDouyinApp(code: 'new-user-code');
    expect((result as DouyinAppPhoneBindingRequired).registerToken,
        'register-token');
  });

  test('false needBindPhone takes precedence over registration token',
      () async {
    response.addAll({'needBindPhone': false, 'registerToken': 'stale-token'});
    expect(await api.loginByDouyinApp(code: 'code'),
        isA<DouyinAppLoginSucceeded>());
  });

  test('rejects binding response without registration token', () async {
    response = {'needBindPhone': true, 'registerToken': '', 'user': null};
    await expectLater(
        api.loginByDouyinApp(code: 'code'), throwsA(isA<FormatException>()));
  });

  test('posts phone binding and optional invitation code', () async {
    final session = await api.registerDouyinAppByPhone(
      registerToken: 'register-token',
      phone: '13097205795',
      code: '123456',
      inviteCode: 'invite',
    );
    expect(request.path, '/api_client/auth/douyinRegisterByPhone');
    expect(request.method, 'POST');
    expect(request.data, {
      'registerToken': 'register-token',
      'phone': '13097205795',
      'code': '123456',
      'inviteCode': 'invite',
    });
    expect(session.accessToken, 'douyin-token');
  });

  test('accepts envelope response and defaults invitation code to empty',
      () async {
    response = {'status': '0000', 'data': response};
    final session = await api.registerDouyinAppByPhone(
      registerToken: 'register-token',
      phone: '13097205795',
      code: '123456',
    );
    expect(request.data['inviteCode'], '');
    expect(session.accessToken, 'douyin-token');
  });
}
