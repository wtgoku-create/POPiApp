import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/features/auth/domain/wechat_app_login.dart';

void main() {
  test('requires phone binding when WeChat returns a registration token', () {
    final response = WechatAppLoginResponse.fromJson({
      'registerToken': 'register-token',
      'needBindPhone': true,
      'user': null,
      'expired': 0,
    });

    expect(response, isA<WechatAppPhoneBindingRequired>());
    expect(
      (response as WechatAppPhoneBindingRequired).registerToken,
      'register-token',
    );
  });
}
