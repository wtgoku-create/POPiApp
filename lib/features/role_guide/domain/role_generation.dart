enum RoleGenerationStatus {
  running,
  pausing,
  paused,
  canceling,
  completed,
  canceled,
  failed,
}

/// A task snapshot that can later be supplied by a remote generation repository.
class RoleGenerationProgress {
  const RoleGenerationProgress({
    this.status = RoleGenerationStatus.running,
    this.stage = 0,
    this.videoUrl,
    this.cover,
  });

  final RoleGenerationStatus status;
  final int stage;
  final Uri? videoUrl;
  final String? cover;
  bool get running => const [
    RoleGenerationStatus.running,
    RoleGenerationStatus.pausing,
    RoleGenerationStatus.canceling,
  ].contains(status);
}
