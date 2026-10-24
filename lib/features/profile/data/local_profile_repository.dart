import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../../core/storage/preferences_storage.dart';
import '../domain/local_profile.dart';

/// Persists the local display profile separately from the authenticated account.
class LocalProfileRepository {
  const LocalProfileRepository(this._storage);

  static const storageKey = 'local_display_profile_v1';
  static const maxNameCharacters = 15;
  static const maxAvatarBytes = 2 * 1024 * 1024;

  final PreferencesStorage _storage;

  LocalProfile? restore() {
    final stored = _storage.getString(storageKey);
    if (stored == null || stored.isEmpty) return null;

    try {
      final json = jsonDecode(stored) as Map<String, dynamic>;
      final name = _validateName(json['name'] as String);
      final encodedAvatar = json['avatar'] as String?;
      final avatarBytes = encodedAvatar == null || encodedAvatar.isEmpty
          ? null
          : base64Decode(encodedAvatar);
      _validateAvatar(avatarBytes);
      return LocalProfile(name: name, avatarBytes: avatarBytes);
    } on Object {
      return null;
    }
  }

  Future<LocalProfile> save({
    required String name,
    Uint8List? avatarBytes,
  }) async {
    final normalizedName = _validateName(name);
    _validateAvatar(avatarBytes);
    final profile = LocalProfile(
      name: normalizedName,
      avatarBytes: avatarBytes == null ? null : Uint8List.fromList(avatarBytes),
    );
    await _storage.setString(
      storageKey,
      jsonEncode({
        'name': profile.name,
        if (profile.avatarBytes != null)
          'avatar': base64Encode(profile.avatarBytes!),
      }),
    );
    return profile;
  }

  Future<void> clear() => _storage.remove(storageKey);

  static String _validateName(String value) {
    final name = value.trim();
    if (name.isEmpty) throw const FormatException('Nickname is required');
    if (name.characters.length > maxNameCharacters) {
      throw const FormatException('Nickname is too long');
    }
    return name;
  }

  static void _validateAvatar(Uint8List? bytes) {
    if (bytes != null && bytes.lengthInBytes > maxAvatarBytes) {
      throw const FormatException('Avatar is too large');
    }
  }
}
