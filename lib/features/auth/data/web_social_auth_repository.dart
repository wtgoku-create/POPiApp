import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/network_api.dart';
import '../../../core/storage/secure_storage.dart';
import '../domain/user.dart';
import '../domain/web_social_login.dart';

/// Browser-only auth contracts, kept separate from native SDK authorization.
class WebSocialAuthRepository {
  const WebSocialAuthRepository(this.api, this.storage);

  final NetworkApi api;
  final TokenStorage storage;

  Future<WebSocialLoginChallenge> createChallenge({
    required bool douyin,
  }) async {
    try {
      return WebSocialLoginChallenge.fromJson(
        await api.webSocialLoginChallenge(douyin: douyin),
        douyin: douyin,
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<WebSocialSignInResult> check({
    required bool douyin,
    required String state,
    required CancelToken cancelToken,
  }) async {
    try {
      final data = await api.checkWebSocialLogin(
        douyin: douyin,
        state: state,
        cancelToken: cancelToken,
      );
      _checkCancellation(cancelToken);
      if (data['needBindPhone'] == true) {
        final token = data['registerToken']?.toString().trim() ?? '';
        if (token.isEmpty) {
          throw const FormatException('Missing registration token');
        }
        return WebSocialPhoneBindingRequired(token);
      }
      final token = (data['token'] ?? data['accessToken'])?.toString().trim();
      if (token == null || token.isEmpty) return const WebSocialWaiting();
      return WebSocialSignInSucceeded(
        await _complete(token, cancelToken: cancelToken),
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) rethrow;
      throw ApiException.fromDioException(error);
    }
  }

  Future<User> registerByPhone({
    required bool douyin,
    required String registerToken,
    required String phone,
    required String code,
  }) async {
    try {
      final data = await api.registerWebSocialByPhone(
        douyin: douyin,
        registerToken: registerToken,
        phone: phone,
        code: code,
      );
      final token = (data['token'] ?? data['accessToken'])?.toString().trim();
      if (token == null || token.isEmpty) {
        throw const FormatException('Missing login token');
      }
      return await _complete(token);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<User> _complete(String token, {CancelToken? cancelToken}) async {
    _checkCancellation(cancelToken);
    await storage.writeAccessToken(token);
    try {
      _checkCancellation(cancelToken);
      final data = await api.currentUser();
      _checkCancellation(cancelToken);
      return User.fromJson(data['user'] as Map<String, dynamic>);
    } catch (_) {
      if (await storage.readAccessToken() == token) {
        await storage.deleteAccessToken();
      }
      rethrow;
    }
  }

  void _checkCancellation(CancelToken? token) {
    if (token != null && token.isCancelled) throw token.cancelError!;
  }
}
