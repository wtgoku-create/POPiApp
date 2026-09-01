import '../../../core/network/network_api.dart';
import '../domain/auth_session.dart';
import '../domain/captcha_challenge.dart';
import '../domain/user.dart';
import '../domain/user_points.dart';

abstract interface class AuthApi {
  Future<CaptchaChallenge> createCaptcha();

  Future<void> sendLoginCode({
    required String phone,
    required String captchaId,
    required String captchaValue,
  });

  Future<AuthSession> loginByCode({
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
  Future<CaptchaChallenge> createCaptcha() async {
    return CaptchaChallenge.fromJson(await networkApi.createCaptcha());
  }

  @override
  Future<void> sendLoginCode({
    required String phone,
    required String captchaId,
    required String captchaValue,
  }) async {
    await networkApi.sendLoginCode(
      phone: phone,
      captchaId: captchaId,
      captchaValue: captchaValue,
    );
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
