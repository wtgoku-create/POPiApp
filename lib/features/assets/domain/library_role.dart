class LibraryRole {
  const LibraryRole({
    required this.id,
    required this.title,
    required this.description,
    this.avatar = '',
    this.profile = const {},
    this.canRead = false,
    this.canEdit = false,
    this.canCreate = false,
    this.canUseVideo = false,
    this.isCertified = false,
    this.profileComplete = false,
    this.profileVersion,
    this.profileVersionId,
  });

  final String id;
  final String title;
  final String description;
  final String avatar;
  final Map<String, dynamic> profile;
  final bool canRead;
  final bool canEdit;
  final bool canCreate;
  final bool canUseVideo;
  final bool isCertified;
  final bool profileComplete;
  final num? profileVersion;
  final String? profileVersionId;
  bool get readyForHomeCreation =>
      canRead &&
      profileComplete &&
      canUseVideo &&
      profileVersionId != null &&
      profileVersionId!.isNotEmpty;

  LibraryRole withFallbackAvatar(String fallback) => LibraryRole(
    id: id,
    title: title,
    description: description,
    avatar: avatar.isEmpty ? fallback : avatar,
    profile: profile,
    canRead: canRead,
    canEdit: canEdit,
    canCreate: canCreate,
    canUseVideo: canUseVideo,
    isCertified: isCertified,
    profileComplete: profileComplete,
    profileVersion: profileVersion,
    profileVersionId: profileVersionId,
  );

  factory LibraryRole.fromJson(Map<String, dynamic> json) {
    final version = json['profileVersion'];
    final candidate =
        json['profile'] ?? (version is Map ? version['profile'] : null);
    final profile = candidate is Map ? candidate : const {};
    final rawVersion =
        (version is Map ? version['version'] : version) ??
        profile['schemaVersion'];
    final profileVersion = rawVersion is num
        ? rawVersion
        : num.tryParse(rawVersion?.toString() ?? '');
    String firstText(List<dynamic> values) => values
        .map((value) => value?.toString().trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    return LibraryRole(
      id: json['id']?.toString() ?? '',
      title: firstText([profile['title'], json['title'], profile['name']]),
      description: firstText([
        profile['description'],
        json['description'],
        profile['appearance'],
      ]),
      avatar: firstText([json['avatar'], json['threeViewImage']]),
      profile: Map<String, dynamic>.from(profile),
      canRead: json['canRead'] == true,
      canEdit: json['canEdit'] == true,
      canCreate: json['canUseText'] == true || json['canUseVideo'] == true,
      canUseVideo: json['canUseVideo'] == true,
      isCertified: json['isCertified'] == true,
      profileComplete: json['profileComplete'] == true,
      profileVersionId: version is Map ? version['id']?.toString() : null,
      profileVersion:
          profileVersion != null &&
              profileVersion.isFinite &&
              profileVersion > 0
          ? profileVersion
          : null,
    );
  }
}

class LibraryRolePage {
  const LibraryRolePage({
    required this.items,
    required this.page,
    required this.pageCount,
  });

  final List<LibraryRole> items;
  final int page;
  final int pageCount;
  bool get hasMore => page < pageCount;

  factory LibraryRolePage.fromJson(Map<String, dynamic> json) {
    final list = json['list'];
    final info = json['pageInfo'];
    if (list is! List ||
        info is! Map ||
        info['page'] is! num ||
        info['pageCount'] is! num) {
      throw const FormatException('Invalid role page');
    }
    return LibraryRolePage(
      items: list
          .map(
            (item) =>
                LibraryRole.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .where((role) => role.id.isNotEmpty)
          .toList(),
      page: (info['page'] as num).toInt(),
      pageCount: (info['pageCount'] as num).toInt(),
    );
  }
}
