/// A standalone conversation, independent of the legacy project hierarchy.
class ConversationSession {
  const ConversationSession({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.pinnedAt,
    this.avatarIcon,
    this.revision = 1,
    this.archived = false,
    this.bindingStatus = 'pending',
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final DateTime? pinnedAt;
  final String? avatarIcon;
  final int revision;
  final bool archived;
  final String bindingStatus;

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
      updatedAt: updatedAt,
      pinnedAt: DateTime.tryParse(json['pinnedAt']?.toString() ?? ''),
    );
  }
}
