import 'dart:typed_data';

/// Display-only profile used by the local product harness while signed out.
class LocalProfile {
  const LocalProfile({required this.name, this.avatarBytes});

  final String name;
  final Uint8List? avatarBytes;
}
