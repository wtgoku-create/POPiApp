import 'dart:convert';

import '../../../core/storage/preferences_storage.dart';

/// Persists only the short-lived browser flow; access tokens use TokenStorage.
class WebLoginProgress {
  const WebLoginProgress(this.storage);
  final PreferencesStorage storage;
  static const _key = 'popibot.douyin.pending-login';

  Future<void> save({
    required String state,
    required DateTime expiresAt,
    String? registerToken,
  }) => storage.setString(
    _key,
    jsonEncode({
      'state': state,
      'expiresAt': expiresAt.millisecondsSinceEpoch,
      'registerToken': registerToken,
    }),
  );

  ({String state, DateTime expiresAt, String? registerToken})? restore({
    String? callbackState,
  }) {
    try {
      final raw = storage.getString(_key);
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final state = data['state'] as String;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        data['expiresAt'] as int,
      );
      if (state.isEmpty ||
          !expiresAt.isAfter(DateTime.now()) ||
          (callbackState != null && callbackState != state)) {
        return null;
      }
      return (
        state: state,
        expiresAt: expiresAt,
        registerToken: data['registerToken'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() => storage.remove(_key);
}
