import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStorage {
  Future<String?> readAccessToken();

  Future<void> writeAccessToken(String token);

  Future<void> deleteAccessToken();
}

/// Web 业务登录由 HttpOnly Cookie 管理，不在客户端持久化登录响应中的 Token，并清理旧版本存储。
class CookieTokenStorage implements TokenStorage {
  const CookieTokenStorage(this.legacy);
  final TokenStorage legacy;
  @override
  Future<String?> readAccessToken() async {
    await legacy.deleteAccessToken();
    return null;
  }

  @override
  Future<void> writeAccessToken(String token) => legacy.deleteAccessToken();
  @override
  Future<void> deleteAccessToken() => legacy.deleteAccessToken();
}

class SecureStorage implements TokenStorage {
  const SecureStorage(this.storage);

  static const accessTokenKey = 'access_token';
  final FlutterSecureStorage storage;

  @override
  Future<String?> readAccessToken() => storage.read(key: accessTokenKey);

  @override
  Future<void> writeAccessToken(String token) =>
      storage.write(key: accessTokenKey, value: token);

  @override
  Future<void> deleteAccessToken() => storage.delete(key: accessTokenKey);
}
