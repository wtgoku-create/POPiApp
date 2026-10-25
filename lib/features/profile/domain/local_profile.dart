import 'dart:typed_data';

/// Display-only profile used by the local product harness while signed out.
class LocalProfile {
  static const harnessDefaultName = 'PPP Art';
  static const harnessDefaultUid = '303180';
  static const harnessDefaultPoints = 10000;

  const LocalProfile({
    required this.name,
    this.uid = harnessDefaultUid,
    this.points = harnessDefaultPoints,
    this.avatarBytes,
  });

  /// Public fixture shared by local and remote Harness builds.
  ///
  /// The UID was generated once and remains stable across Web and macOS so the
  /// test profile behaves like one account instead of changing on each launch.
  static const harnessDefault = LocalProfile(name: harnessDefaultName);

  final String name;
  final String uid;
  final int points;
  final Uint8List? avatarBytes;
}
