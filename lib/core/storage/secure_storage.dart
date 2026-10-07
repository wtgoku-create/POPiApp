import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class TokenStorage {
  Future<String?> readAccessToken();

  Future<void> writeAccessToken(String token);

  Future<void> deleteAccessToken();
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
