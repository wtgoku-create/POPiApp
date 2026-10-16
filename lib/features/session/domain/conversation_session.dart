/// One server page; loading further history is driven by the drawer viewport.
class ConversationSessionPage {
  const ConversationSessionPage({
    required this.items,
    required this.page,
    required this.pageCount,
  });

  final List<ConversationSession> items;
  final int page;
  final int pageCount;
  bool get hasMore => page < pageCount;
}

/// A standalone conversation, independent of the legacy project hierarchy.
class ConversationSession {
  const ConversationSession({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.createdAt,
    this.lastMessageAt,
    this.pinnedAt,
    this.avatarIcon,
    this.iconBackgroundColor,
    this.revision = 1,
    this.archived = false,
    this.bindingStatus = 'pending',
    this.creatorV1 = false,
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final DateTime? createdAt;
  final DateTime? lastMessageAt;
  final DateTime? pinnedAt;
  final String? avatarIcon;
  final String? iconBackgroundColor;
  final int revision;
  final bool archived;
  final String bindingStatus;
  final bool creatorV1;

  bool get isPinned => pinnedAt != null;

  /// Older responses without creation time remain stable by ID, never updatedAt.
  DateTime get activityAt =>
      lastMessageAt ??
      createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  /// Metadata revisions and interaction timestamps advance independently.
  ConversationSession merge(ConversationSession incoming) {
    assert(id == incoming.id);
    if (identical(this, incoming)) return this;
    final latest = incoming.revision >= revision ? incoming : this;
    final interaction = incoming.lastMessageAt;
    return ConversationSession(
      id: id,
      title: latest.title,
      updatedAt: latest.updatedAt,
      createdAt: createdAt ?? incoming.createdAt,
      lastMessageAt:
          interaction != null &&
              (lastMessageAt == null || interaction.isAfter(lastMessageAt!))
          ? interaction
          : lastMessageAt,
      pinnedAt: latest.pinnedAt,
      avatarIcon: latest.avatarIcon,
      iconBackgroundColor:
          latest.iconBackgroundColor ??
          iconBackgroundColor ??
          incoming.iconBackgroundColor,
      revision: latest.revision,
      archived: latest.archived,
      bindingStatus: latest.bindingStatus,
      creatorV1: latest.creatorV1,
    );
  }

  factory ConversationSession.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final title = json['title'];
    final revision = json['revision'];
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        revision is! int ||
        revision < 1 ||
        updatedAt == null) {
      throw const FormatException('Invalid conversation session');
    }
    return ConversationSession(
      id: id,
      title: title,
      revision: revision,
      archived: json['archived'] == true,
      bindingStatus: json['bindingStatus'] as String? ?? 'pending',
      creatorV1: json['creatorV1'] == true,
      updatedAt: updatedAt,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      lastMessageAt: DateTime.tryParse(json['lastMessageAt']?.toString() ?? ''),
      pinnedAt: DateTime.tryParse(json['pinnedAt']?.toString() ?? ''),
      iconBackgroundColor: json['iconBackgroundColor'] is String
          ? json['iconBackgroundColor'] as String
          : null,
    );
  }
}
