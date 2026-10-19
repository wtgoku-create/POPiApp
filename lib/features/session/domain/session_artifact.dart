import 'conversation_snapshot.dart';

enum SessionArtifactType { image, script, video }

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
