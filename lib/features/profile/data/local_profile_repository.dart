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
      final uid = _validateUid(
        json['uid']?.toString() ?? LocalProfile.harnessDefault.uid,
      );
      final points = _validatePoints(
        json['points'] ?? LocalProfile.harnessDefault.points,
      );
      final encodedAvatar = json['avatar'] as String?;
      final avatarBytes = encodedAvatar == null || encodedAvatar.isEmpty
          ? null
          : base64Decode(encodedAvatar);
      _validateAvatar(avatarBytes);
      return LocalProfile(
        name: name,
        uid: uid,
        points: points,
        avatarBytes: avatarBytes,
      );
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
    final current = restore() ?? LocalProfile.harnessDefault;
    final profile = LocalProfile(
      name: normalizedName,
      uid: current.uid,
      points: current.points,
      avatarBytes: avatarBytes == null ? null : Uint8List.fromList(avatarBytes),
    );
    await _write(profile);
    return profile;
  }

  Future<void> ensureStored(LocalProfile profile) => _write(profile);

  Future<LocalProfile> resetToDefaults() async {
    await _storage.remove(storageKey);
    await _write(LocalProfile.harnessDefault);
    return LocalProfile.harnessDefault;
  }

  Future<void> clear() => _storage.remove(storageKey);

  Future<void> _write(LocalProfile profile) => _storage.setString(
    storageKey,
    jsonEncode({
      'name': profile.name,
      'uid': profile.uid,
      'points': profile.points,
      if (profile.avatarBytes != null)
        'avatar': base64Encode(profile.avatarBytes!),
    }),
  );

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

  static String _validateUid(String value) {
    final uid = value.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(uid)) {
      throw const FormatException('UID must contain six digits');
    }
    return uid;
  }

  static int _validatePoints(Object value) {
    final points = value is num ? value.toInt() : int.tryParse('$value');
    if (points == null || points < 0) {
      throw const FormatException('Points must be a non-negative integer');
    }
    return points;
  }
}
