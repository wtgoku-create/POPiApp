import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_image_preview.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../../shared/widgets/app_video_preview.dart';
import '../../domain/role_generation.dart';
import 'role_guide_controls.dart';

/// Displays task state without inferring completion from timers in the UI.
class RoleGenerationPanel extends StatelessWidget {
  const RoleGenerationPanel({
    required this.progress,
    required this.preview,
    required this.onStop,
    required this.onRetry,
    required this.onContinue,
    required this.onViewPlan,
    super.key,
  });

  final RoleGenerationProgress progress;
  final bool preview;
  final VoidCallback onStop;
  final VoidCallback onRetry;
  final VoidCallback onContinue;
  final VoidCallback onViewPlan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final completed = progress.status == RoleGenerationStatus.completed;
    final status = switch (progress.status) {
      RoleGenerationStatus.running => l10n.roleTaskRunning,
      RoleGenerationStatus.completed => l10n.roleTaskCompleted,
      RoleGenerationStatus.canceled => l10n.roleTaskCanceled,
      RoleGenerationStatus.failed => l10n.roleTaskFailed,
    };
    final stages = [
      l10n.roleStageCharacters,
      l10n.roleStageScript,
      l10n.roleStageStoryboard,
      l10n.roleStageVideo,
      l10n.roleStageReview,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  status,
                  style: const TextStyle(color: AppColors.brand, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: roleGuideTint(context),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    switch (progress.status) {
                      RoleGenerationStatus.running => l10n.roleTaskExecuting,
                      RoleGenerationStatus.completed =>
                        l10n.roleStatusCompleted,
                      RoleGenerationStatus.failed => l10n.roleStatusFailed,
                      RoleGenerationStatus.canceled => l10n.roleStatusCanceled,
                    },
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.brand,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < stages.length; i++)
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i == 0
                                ? Colors.transparent
                                : i <= progress.stage
                                ? AppColors.brand.withValues(alpha: .5)
                                : colors.outlineVariant,
                          ),
                        ),
                        SizedBox.square(
                          dimension: 24,
                          child: i < progress.stage || completed
                              ? const Icon(
                                  Icons.check,
                                  color: AppColors.brand,
                                  size: 20,
                                )
                              : progress.running && i == progress.stage
                              ? const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.brand,
                                  ),
                                )
                              : Icon(
                                  progress.status ==
                                              RoleGenerationStatus.failed &&
                                          i == progress.stage
                                      ? Icons.error_outline
                                      : Icons.circle_outlined,
                                  size: 20,
                                  color: colors.outlineVariant,
                                ),
                        ),
                        Expanded(
                          child: Container(
                            height: 2,
                            color: i == stages.length - 1
                                ? Colors.transparent
                                : i < progress.stage
                                ? AppColors.brand.withValues(alpha: .5)
                                : colors.outlineVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      stages[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: i == progress.stage && progress.running
                            ? AppColors.brand
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 26),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.textScalerOf(context).scale(16) > 20
                  ? 220
                  : 160,
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: completed && progress.cover != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: 'role-guide-result',
                          child: Image.asset(
                            progress.cover!,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned.fill(
                          child: Center(
                            child: IconButton.filledTonal(
                              key: const Key('role-guide-preview-result'),
                              tooltip: progress.videoUrl == null
                                  ? l10n.rolePreviewCover
                                  : l10n.videoPlay,
                              onPressed: () => progress.videoUrl != null
                                  ? AppVideoPreview.show(
                                      context: context,
                                      url: progress.videoUrl!,
                                    )
                                  : AppImagePreview.show(
                                      context: context,
                                      image: AssetImage(progress.cover!),
                                      heroTag: 'role-guide-result',
                                      label: l10n.rolePreviewCover,
                                    ),
                              icon: Icon(
                                progress.videoUrl == null
                                    ? Icons.fullscreen
                                    : Icons.play_arrow,
                              ),
                            ),
                          ),
                        ),
                        if (preview)
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: .5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                l10n.rolePreviewCover,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: progress.running
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFE0D2E5),
                                  Color(0xFF579ED1),
                                  Color(0xFFA764E3),
                                ],
                              )
                            : null,
                        color: progress.running ? null : roleGuideTint(context),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (progress.running)
                              const RotatedBox(
                                quarterTurns: 2,
                                child: AppSvgIcon.asset(
                                  'role_guide_generating',
                                  size: 60,
                                ),
                              )
                            else
                              Icon(
                                progress.status == RoleGenerationStatus.failed
                                    ? Icons.error_outline
                                    : Icons.stop_circle_outlined,
                                size: 40,
                                color: colors.onSurfaceVariant,
                              ),
                            const SizedBox(height: 12),
                            Text(
                              progress.running
                                  ? l10n.roleWorkGenerating
                                  : status,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: progress.running
                                    ? Colors.white
                                    : colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        RoleGuideAction(
          key: const Key('role-guide-generation-action'),
          label: progress.running
              ? l10n.roleStopProduction
              : completed
              ? l10n.roleContinueCreating
              : l10n.retry,
          showArrow: !progress.running,
          onPressed: progress.running
              ? onStop
              : completed
              ? onContinue
              : onRetry,
        ),
        const SizedBox(height: 10),
        RoleGuideAction(
          key: const Key('role-guide-view-plan'),
          label: completed ? l10n.roleChatInSession : l10n.roleViewPlan,
          secondary: true,
          onPressed: onViewPlan,
        ),
      ],
    );
  }
}
