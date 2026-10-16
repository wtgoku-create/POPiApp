import '../../assets/domain/library_role.dart';

/// Account facts, structured preferences and retained resident role references.
class IpAccountHome {
  const IpAccountHome({
    required this.id,
    required this.title,
    required this.revision,
    this.avatar = '',
    this.iconBackgroundColor,
    this.status = 'active',
    this.profile = const {},
    this.residentRoles = const [],
    this.preferences = const {},
    this.memoryMarkdown = '',
    this.userPrompt = '',
  });

  final String id;
  final String title;
  final int revision;
  final String avatar;
  final String? iconBackgroundColor;
  final String status;
  final Map<String, Object?> profile;
  final List<Map<String, Object?>> residentRoles;
  final Map<String, Object?> preferences;
  final String memoryMarkdown;
  final String userPrompt;

  List<String> selections(String key) {
    final value = preferences[key];
    if (value is List) return value.whereType<String>().toList();
    if (value is String && value.isNotEmpty) return [value];
    return const [];
  }

  String preferenceText(String key) => selections(key).join(' / ');

  bool get editable => status == 'active';
  String text(String field) =>
      profile[field] is String ? (profile[field] as String).trim() : '';
  String get description => [
    preferenceText('contentDirections'),
    preferenceText('presentationFormats'),
  ].where((value) => value.isNotEmpty).join(' x ');
}

class IpAccountCreation {
  const IpAccountCreation({
    required this.id,
    required this.title,
    this.sessionId,
    this.versionId,
    this.summary = '',
  });
  final String id;
  final String title;
  final String? sessionId;
  final String? versionId;
  final String summary;
}

class IpAccountResources {
  const IpAccountResources({
    this.creations = const [],
    this.roles = const [],
    this.page = 1,
    this.pageCount = 1,
  });
  final List<IpAccountCreation> creations;
  final List<LibraryRole> roles;
  final int page;
  final int pageCount;
  bool get hasMore => page < pageCount;
}
