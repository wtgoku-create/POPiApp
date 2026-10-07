import '../../../core/network/network_api.dart';
import '../domain/auth_session.dart';
import '../domain/captcha_challenge.dart';
import '../domain/user.dart';
import '../domain/user_points.dart';
import '../domain/wechat_app_login.dart';

abstract interface class AuthApi {
  Future<CaptchaChallenge> createCaptcha({required String phone});

  Future<String> verifyCaptcha(SliderCaptchaVerification verification);

  Future<void> sendLoginCode({
    required String phone,
    required String captchaToken,
  });

  Future<AuthSession> loginByCode({
    required String phone,
    required String code,
    String inviteCode = '',
  });

  Future<WechatAppLoginResponse> loginByWechatApp({required String code});

  Future<AuthSession> loginByPassword({
    required String username,
    required String password,
  });

  Future<AuthSession> registerWechatAppByPhone({
    required String registerToken,
    required String phone,
    required String code,
    String inviteCode = '',
  });

  Future<User> currentUser();

  Future<UserPoints> userPoints();

  Future<User> updateUser({
    required String avatar,
    required String name,
    required String signature,
  });

  Future<void> logout();
}

class DefaultAuthApi implements AuthApi {
  const DefaultAuthApi(this.networkApi);

  final NetworkApi networkApi;

  @override
  Future<CaptchaChallenge> createCaptcha({required String phone}) async {
    return CaptchaChallenge.fromJson(
      await networkApi.createCaptcha(phone: phone),
    );
  }

  @override
  Future<String> verifyCaptcha(SliderCaptchaVerification verification) =>
      networkApi.verifyCaptcha(verification);

  @override
  Future<void> sendLoginCode({
    required String phone,
    required String captchaToken,
  }) async {
    await networkApi.sendLoginCode(phone: phone, captchaToken: captchaToken);
  }

  @override
  Future<AuthSession> loginByCode({
    required String phone,
    required String code,
    String inviteCode = '',
  }) async {
    final data = await networkApi.loginByCode(
      phone: phone,
      code: code,
      inviteCode: inviteCode,
    );
    return AuthSession.fromJson(data);
  }

  @override
  Future<AuthSession> loginByPassword({
    required String username,
    required String password,
  }) async {
    return AuthSession.fromJson(
      await networkApi.loginByPassword(username: username, password: password),
    );
  }

  @override
  Future<WechatAppLoginResponse> loginByWechatApp({
    required String code,
  }) async {
    return WechatAppLoginResponse.fromJson(
      await networkApi.loginByWechatApp(code: code),
    );
  }

  @override
  Future<AuthSession> registerWechatAppByPhone({
    required String registerToken,
    required String phone,
    required String code,
    String inviteCode = '',
  }) async {
    return AuthSession.fromJson(
      await networkApi.registerWechatAppByPhone(
        registerToken: registerToken,
        phone: phone,
        code: code,
        inviteCode: inviteCode,
      ),
    );
  }

  @override
  Future<User> currentUser() async {
    final data = await networkApi.currentUser();
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  @override
  Future<UserPoints> userPoints() async {
    return UserPoints.fromJson(await networkApi.userPoints());
  }

  @override
  Future<User> updateUser({
    required String avatar,
    required String name,
    required String signature,
  }) async {
    return User.fromJson(
      await networkApi.updateUser(
        avatar: avatar,
        name: name,
        signature: signature,
      ),
    );
  }

  @override
  Future<void> logout() async {
    await networkApi.logout();
  }
}
