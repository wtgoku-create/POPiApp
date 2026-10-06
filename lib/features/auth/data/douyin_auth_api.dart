import '../../../core/network/network_api.dart';
import '../domain/auth_session.dart';
import '../domain/douyin_app_login.dart';

abstract interface class DouyinAuthApi {
  Future<DouyinAppLoginResponse> loginByDouyinApp({required String code});

  Future<AuthSession> registerDouyinAppByPhone({
    required String registerToken,
    required String phone,
    required String code,
    String inviteCode = '',
  });
}

class DefaultDouyinAuthApi implements DouyinAuthApi {
  const DefaultDouyinAuthApi(this.networkApi);

  final NetworkApi networkApi;

  @override
  Future<DouyinAppLoginResponse> loginByDouyinApp(
          {required String code}) async =>
      DouyinAppLoginResponse.fromJson(
        await networkApi.loginByDouyinApp(code: code),
      );

  @override
  Future<AuthSession> registerDouyinAppByPhone({
    required String registerToken,
    required String phone,
    required String code,
    String inviteCode = '',
  }) async =>
      AuthSession.fromJson(
        await networkApi.registerDouyinAppByPhone(
          registerToken: registerToken,
          phone: phone,
          code: code,
          inviteCode: inviteCode,
        ),
      );
}

class DouyinLoginUnavailableException implements Exception {
  const DouyinLoginUnavailableException();
}

class UnavailableDouyinAuthApi implements DouyinAuthApi {
  const UnavailableDouyinAuthApi();

  @override
  Future<DouyinAppLoginResponse> loginByDouyinApp(
      {required String code}) async {
    throw const DouyinLoginUnavailableException();
  }

  @override
  Future<AuthSession> registerDouyinAppByPhone({
    required String registerToken,
    required String phone,
    required String code,
    String inviteCode = '',
  }) async {
    throw const DouyinLoginUnavailableException();
  }
}
