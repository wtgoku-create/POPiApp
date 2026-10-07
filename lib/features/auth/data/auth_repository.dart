import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage.dart';
import '../domain/captcha_challenge.dart';
import '../domain/douyin_app_login.dart';
import '../domain/user.dart';
import '../domain/user_points.dart';
import '../domain/wechat_app_login.dart';
import 'auth_api.dart';
import 'douyin_auth_api.dart';

class AuthRepository {
  const AuthRepository({
    required this.api,
    required this.secureStorage,
    this.douyinApi = const UnavailableDouyinAuthApi(),
  });

  final AuthApi api;
  final TokenStorage secureStorage;
  final DouyinAuthApi douyinApi;

  Future<CaptchaChallenge> createCaptcha({required String phone}) async {
    try {
      return await api.createCaptcha(phone: phone);
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  Future<String> verifyCaptcha(SliderCaptchaVerification verification) async {
    try {
      return await api.verifyCaptcha(verification);
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  Future<void> sendLoginCode({
    required String phone,
    required String captchaToken,
  }) async {
    try {
      await api.sendLoginCode(phone: phone, captchaToken: captchaToken);
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  Future<User> loginWithCode({
    required String phone,
    required String code,
  }) async {
    try {
      final session = await api.loginByCode(phone: phone, code: code);
      await secureStorage.writeAccessToken(session.accessToken);
      try {
        return await api.currentUser();
      } catch (_) {
        await secureStorage.deleteAccessToken();
        rethrow;
      }
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  Future<User> loginWithPassword({
    required String phone,
    required String password,
  }) async {
    try {
      final session = await api.loginByPassword(
        username: phone,
        password: password,
      );
      await secureStorage.writeAccessToken(session.accessToken);
      try {
        return await api.currentUser();
      } catch (_) {
        await secureStorage.deleteAccessToken();
        rethrow;
      }
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  Future<WechatAppSignInResult> loginWithWechatApp({
    required String code,
  }) async {
    try {
      final response = await api.loginByWechatApp(code: code);
      if (response case WechatAppPhoneBindingRequired(
        registerToken: final registerToken,
      )) {
        return WechatAppSignInPhoneBindingRequired(registerToken);
      }
      final session = (response as WechatAppLoginSucceeded).session;
      await secureStorage.writeAccessToken(session.accessToken);
      try {
        return WechatAppSignInSucceeded(await api.currentUser());
      } catch (_) {
        await secureStorage.deleteAccessToken();
        rethrow;
      }
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  Future<User> registerWechatAppByPhone({
    required String registerToken,
    required String phone,
    required String code,
  }) async {
    try {
      final session = await api.registerWechatAppByPhone(
        registerToken: registerToken,
        phone: phone,
        code: code,
      );
      await secureStorage.writeAccessToken(session.accessToken);
      try {
        return await api.currentUser();
      } catch (_) {
        await secureStorage.deleteAccessToken();
        rethrow;
      }
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  Future<DouyinAppSignInResult> loginWithDouyinApp({
    required String code,
  }) async {
    try {
      final response = await douyinApi.loginByDouyinApp(code: code);
      if (response case DouyinAppPhoneBindingRequired(
        registerToken: final registerToken,
      )) {
        return DouyinAppSignInPhoneBindingRequired(registerToken);
      }
      final session = (response as DouyinAppLoginSucceeded).session;
      await secureStorage.writeAccessToken(session.accessToken);
      try {
        return DouyinAppSignInSucceeded(await api.currentUser());
      } catch (_) {
        await secureStorage.deleteAccessToken();
        rethrow;
      }
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  Future<User> registerDouyinAppByPhone({
    required String registerToken,
    required String phone,
    required String code,
  }) async {
    try {
      final session = await douyinApi.registerDouyinAppByPhone(
        registerToken: registerToken,
        phone: phone,
        code: code,
      );
      await secureStorage.writeAccessToken(session.accessToken);
      try {
        return await api.currentUser();
      } catch (_) {
        await secureStorage.deleteAccessToken();
        rethrow;
      }
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  Future<User> fetchCurrentUser() async {
    try {
      return await api.currentUser();
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  Future<UserPoints> fetchUserPoints() async {
    try {
      return await api.userPoints();
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  Future<User> updateUser({
    required String avatar,
    required String name,
    required String signature,
  }) async {
    try {
      return await api.updateUser(
        avatar: avatar,
        name: name,
        signature: signature,
      );
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  Future<void> logout() async {
    try {
      await api.logout();
    } on DioException {
      // Local logout must still succeed when the server is unavailable.
    } on ApiException {
      // Local logout must still succeed when the session already expired.
    } finally {
      await secureStorage.deleteAccessToken();
    }
  }
}
