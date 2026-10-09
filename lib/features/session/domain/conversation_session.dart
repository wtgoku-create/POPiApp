/// A standalone conversation, independent of the legacy project hierarchy.
class ConversationSession {
  const ConversationSession({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.pinnedAt,
    this.avatarAsset,
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final DateTime? pinnedAt;
  final String? avatarAsset;
}
