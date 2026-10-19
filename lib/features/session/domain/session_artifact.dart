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
  });

  final String id;
  final SessionArtifactType type;
  final String title;
  final String summary;
  final String metadata;
  final String? previewAsset;
  final Uri? videoUrl;
  final List<SessionArtifactShot> shots;
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
