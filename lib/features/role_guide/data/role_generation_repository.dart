import 'dart:async';

import '../domain/role_generation.dart';

/// Keeps preview timing outside widgets. A remote implementation can stream tasks.
abstract class RoleGenerationRepository {
  const RoleGenerationRepository();

  bool get isPreview;
  Stream<RoleGenerationProgress> generate(String plan);
}

/// Interaction preview only: no backend task, video file, or point charge.
class PreviewRoleGenerationRepository extends RoleGenerationRepository {
  const PreviewRoleGenerationRepository({
    this.stageDuration = const Duration(seconds: 2),
  });

  final Duration stageDuration;

  @override
  bool get isPreview => true;

  @override
  Stream<RoleGenerationProgress> generate(String plan) {
    Timer? timer;
    var stage = 0;
    late final StreamController<RoleGenerationProgress> controller;
    controller = StreamController<RoleGenerationProgress>(
      onListen: () {
        controller.add(const RoleGenerationProgress());
        timer = Timer.periodic(stageDuration, (_) {
          stage++;
          if (stage < 5) {
            controller.add(RoleGenerationProgress(stage: stage));
          } else {
            timer?.cancel();
            controller.add(
              const RoleGenerationProgress(
                status: RoleGenerationStatus.completed,
                stage: 5,
                cover: 'assets/images/role_guide_result_preview.png',
              ),
            );
            controller.close();
          }
        });
      },
      onCancel: () => timer?.cancel(),
    );
    return controller.stream;
  }
}
