import 'auth_session.dart';
import 'user.dart';

sealed class DouyinAppLoginResponse {
  const DouyinAppLoginResponse();

  factory DouyinAppLoginResponse.fromJson(Map<String, dynamic> json) {
    final registerToken = json['registerToken']?.toString().trim();
    final needsPhoneBinding = json['needBindPhone'] == true;
    if (needsPhoneBinding) {
      if (registerToken == null || registerToken.isEmpty) {
        throw const FormatException('Missing Douyin registration token');
      }
      return DouyinAppPhoneBindingRequired(registerToken);
    }
    return DouyinAppLoginSucceeded(AuthSession.fromJson(json));
  }
}

class DouyinAppLoginSucceeded extends DouyinAppLoginResponse {
  const DouyinAppLoginSucceeded(this.session);

  final AuthSession session;
}

class DouyinAppPhoneBindingRequired extends DouyinAppLoginResponse {
  const DouyinAppPhoneBindingRequired(this.registerToken);

  final String registerToken;
}

sealed class DouyinAppSignInResult {
  const DouyinAppSignInResult();
}

class DouyinAppSignInSucceeded extends DouyinAppSignInResult {
  const DouyinAppSignInSucceeded(this.user);

  final User user;
}

class DouyinAppSignInPhoneBindingRequired extends DouyinAppSignInResult {
  const DouyinAppSignInPhoneBindingRequired(this.registerToken);

  final String registerToken;
}
