import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage.dart';
import '../domain/captcha_challenge.dart';
import '../domain/user.dart';
import '../domain/user_points.dart';
import 'auth_api.dart';

class AuthRepository {
  const AuthRepository({required this.api, required this.secureStorage});

  final AuthApi api;
  final TokenStorage secureStorage;

  Future<CaptchaChallenge> createCaptcha() async {
    try {
      return await api.createCaptcha();
    } on DioException catch (exception) {
      throw ApiException.fromDioException(exception);
    }
  }

  Future<void> sendLoginCode({
    required String phone,
    required String captchaId,
    required String captchaValue,
  }) async {
    try {
      await api.sendLoginCode(
        phone: phone,
        captchaId: captchaId,
        captchaValue: captchaValue,
      );
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
