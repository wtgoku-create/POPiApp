import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/demo/domain/harness_access_session.dart';

abstract interface class HarnessAccessStorage {
  Future<HarnessAccessSession?> readSession();

  Future<void> writeSession(HarnessAccessSession session);

  Future<void> deleteSession();
}

class SecureHarnessAccessStorage implements HarnessAccessStorage {
  const SecureHarnessAccessStorage(this.storage);

  static const sessionKey = 'remote_harness_access_session_v1';

  final FlutterSecureStorage storage;

  @override
  Future<HarnessAccessSession?> readSession() async {
    final encoded = await storage.read(key: sessionKey);
    if (encoded == null || encoded.isEmpty) return null;
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw const FormatException('Invalid Harness access session');
    }
    return HarnessAccessSession.fromJson(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  @override
  Future<void> writeSession(HarnessAccessSession session) =>
      storage.write(key: sessionKey, value: jsonEncode(session.toJson()));

  @override
  Future<void> deleteSession() => storage.delete(key: sessionKey);
}
