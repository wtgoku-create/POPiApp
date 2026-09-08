import 'auth_session.dart';
import 'user.dart';

sealed class WechatAppLoginResponse {
  const WechatAppLoginResponse();

  factory WechatAppLoginResponse.fromJson(Map<String, dynamic> json) {
    final registerToken = json['registerToken']?.toString().trim();
    final needsPhoneBinding = json['needBindPhone'] == true;
    if (needsPhoneBinding || (registerToken?.isNotEmpty ?? false)) {
      if (registerToken == null || registerToken.isEmpty) {
        throw const FormatException('Missing WeChat registration token');
      }
      return WechatAppPhoneBindingRequired(registerToken);
    }
    return WechatAppLoginSucceeded(AuthSession.fromJson(json));
  }
}

class WechatAppLoginSucceeded extends WechatAppLoginResponse {
  const WechatAppLoginSucceeded(this.session);

  final AuthSession session;
}

class WechatAppPhoneBindingRequired extends WechatAppLoginResponse {
  const WechatAppPhoneBindingRequired(this.registerToken);

  final String registerToken;
}

sealed class WechatAppSignInResult {
  const WechatAppSignInResult();
}

class WechatAppSignInSucceeded extends WechatAppSignInResult {
  const WechatAppSignInSucceeded(this.user);

  final User user;
}

class WechatAppSignInPhoneBindingRequired extends WechatAppSignInResult {
  const WechatAppSignInPhoneBindingRequired(this.registerToken);

  final String registerToken;
}
