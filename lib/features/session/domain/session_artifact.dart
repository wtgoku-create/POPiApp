import 'conversation_snapshot.dart';

enum SessionArtifactType { image, script, video, audio }

/// A generated output belonging to a conversation.
class SessionArtifact {
  const SessionArtifact({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    required this.metadata,
    this.previewAsset,
    this.videoUrl,
    this.shots = const [],
    this.textKind,
    this.durationSeconds,
    this.createdAt,
    this.mediaId,
  });

  factory SessionArtifact.fromTextDraft(Map<String, Object?> json) =>
      SessionArtifact(
        id: json['id'].toString(),
        type: SessionArtifactType.script,
        title: json['title'] as String? ?? '',
        summary: json['content'] as String? ?? '',
        metadata: '',
        textKind: json['kind'] as String? ?? 'script',
        durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      );

  /// Unified outputs retain the saved text version and resolve media on demand.
  factory SessionArtifact.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    final type = json['type'];
    final text = category == 'text'
        ? conversationMap(json['text'])
        : const <String, Object?>{};
    final media = category == 'text'
        ? const <String, Object?>{}
        : conversationMap(json['media']);
    final artifactType = switch ((category, type)) {
      ('text', 'topic' || 'script' || 'storyboard') =>
        SessionArtifactType.script,
      ('media', 'image') ||
      ('role_image', 'three_view') => SessionArtifactType.image,
      ('media', 'video') => SessionArtifactType.video,
      ('media', 'audio') => SessionArtifactType.audio,
      _ => throw const FormatException('Invalid artifact type'),
    };
    final id = json['id'];
    final sourceId = artifactType == SessionArtifactType.script
        ? text['id']
        : media['id'];
    if (id is! String ||
        sourceId is! String ||
        sourceId.isEmpty ||
        id != '${category == 'text' ? 'text' : 'media'}:$sourceId' ||
        json['title'] is! String ||
        (category == 'text' && text['content'] is! String)) {
      throw const FormatException('Invalid artifact');
    }
    return SessionArtifact(
      id: id,
      type: artifactType,
      title: json['title'] as String,
      summary: text['content'] as String? ?? '',
      metadata: '',
      textKind: category == 'text' ? type as String : null,
      durationSeconds: (text['durationSeconds'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      mediaId: category == 'text' ? null : sourceId,
    );
  }

  static List<SessionArtifact> mediaFromSnapshot(
    ConversationSnapshot? snapshot,
  ) {
    final items = <String, SessionArtifact>{};
    for (final block in [
      ...?snapshot?.contents,
      for (final message in snapshot?.messages ?? <ConversationMessage>[])
        ...message.blocks.where((block) => block.kind == 'content'),
    ]) {
      if (!['image', 'video'].contains(block.objectKind)) continue;
      for (final id in block.mediaIds) {
        items[id] = SessionArtifact(
          id: 'media:$id',
          type: block.objectKind == 'video'
              ? SessionArtifactType.video
              : SessionArtifactType.image,
          title: block.title,
          summary: block.body,
          metadata: '',
          mediaId: id,
        );
      }
    }
    return items.values.toList();
  }

  final String id;
  final SessionArtifactType type;
  final String title;
  final String summary;
  final String metadata;
  final String? previewAsset;
  final Uri? videoUrl;
  final List<SessionArtifactShot> shots;
  final String? textKind;
  final int? durationSeconds;
  final DateTime? createdAt;
  final String? mediaId;
}

class SessionArtifactShot {
  const SessionArtifactShot(
    this.title,
    this.time,
    this.description,
    this.audio,
  );

  final String title;
  final String time;
  final String description;
  final String audio;
}
