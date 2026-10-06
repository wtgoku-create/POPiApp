import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/api_exception.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/auth/data/auth_api.dart';
import 'package:popi_ai_app/features/auth/domain/captcha_challenge.dart';

void main() {
  const verification = SliderCaptchaVerification(
    captchaId: 'challenge',
    phone: '13800138000',
    x: 110,
    y: 2,
    sliderOffsetX: 114,
    duration: 850,
    trail: [
      [10, 20],
      [124, 22]
    ],
  );

  test('uses web slider challenge, verification and SMS contracts', () async {
    final requests = <RequestOptions>[];
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      requests.add(request);
      handler.resolve(Response(requestOptions: request, data: {
        'status': '0000',
        'data': switch (request.path) {
          '/api_client/captcha/gen' => {
              'id': 'challenge',
              'bgUrl': 'https://example.com/bg.png',
              'puzzleUrl': 'https://example.com/puzzle.png',
            },
          '/api_client/captcha/verify' => {'err': 0, 'token': 'one-use-token'},
          _ => <String, dynamic>{},
        },
      }));
    }));
    final api = DefaultAuthApi(NetworkApi(dio));
    final challenge = await api.createCaptcha(phone: verification.phone);
    expect(challenge.id, 'challenge');
    final token = await api.verifyCaptcha(verification);
    await api.sendLoginCode(phone: verification.phone, captchaToken: token);
    expect(requests[0].queryParameters, {
      'phone': verification.phone,
      'usage': 'LOGIN',
      'type': 'SLIDER',
    });
    expect(requests[1].method, 'POST');
    expect(requests[1].data, {
      'id': 'challenge',
      'phone': verification.phone,
      'usage': 'LOGIN',
      'type': 'SLIDER',
      'x': 110.0,
      'y': 2.0,
      'sliderOffsetX': 114.0,
      'duration': 850,
      'trail': [
        [10.0, 20.0],
        [124.0, 22.0]
      ],
      'targetType': 'button',
    });
    expect(requests[2].queryParameters, {
      'phone': verification.phone,
      'usage': 'LOGIN',
      'captchaToken': 'one-use-token',
    });
  });

  test('rejects failed verification and missing tickets', () async {
    for (final result in [
      {'err': 1, 'token': 'invalid'},
      {'err': 0},
      {'err': 0, 'token': ''}
    ]) {
      final dio = Dio();
      dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
        handler.resolve(Response(
            requestOptions: request, data: {'status': '0000', 'data': result}));
      }));
      await expectLater(NetworkApi(dio).verifyCaptcha(verification),
          throwsA(isA<ApiException>()));
    }
  });
}
