import '../../assets/domain/library_role.dart';

/// The active account profile and its version-pinned resident role references.
class IpAccountHome {
  const IpAccountHome({
    required this.id,
    required this.title,
    required this.revision,
    this.status = 'active',
    this.profile = const {},
    this.residentRoles = const [],
  });

  final String id;
  final String title;
  final int revision;
  final String status;
  final Map<String, Object?> profile;
  final List<Map<String, Object?>> residentRoles;

  bool get editable => status == 'active';
  String text(String field) =>
      profile[field] is String ? (profile[field] as String).trim() : '';
  String get description => [
    text('contentDirection'),
    text('presentation'),
  ].where((value) => value.isNotEmpty).join(' x ');
}

class IpAccountCreation {
  const IpAccountCreation({
    required this.id,
    required this.title,
    this.sessionId,
  });
  final String id;
  final String title;
  final String? sessionId;
}

class IpAccountResources {
  const IpAccountResources({this.creations = const [], this.roles = const []});
  final List<IpAccountCreation> creations;
  final List<LibraryRole> roles;
}
