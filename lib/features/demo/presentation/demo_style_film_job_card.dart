import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/demo_style_film_models.dart';
import 'widgets/demo_widgets.dart';

class DemoStyleFilmJobCard extends StatelessWidget {
  const DemoStyleFilmJobCard({
    required this.job,
    required this.onOpen,
    this.onOpenOutput,
    this.onRetry,
    super.key,
  });

  final DemoStyleFilmJob job;
  final VoidCallback onOpen;
  final VoidCallback? onOpenOutput;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final (label, icon, color) = _presentation(
      l,
      Theme.of(context).colorScheme.error,
    );
    final action = job.isCompleted
        ? onOpenOutput
        : job.isFailed && job.allowedActions.contains('revise')
        ? onRetry
        : job.isAwaitingReview
        ? onOpen
        : null;
    return Material(
      key: ValueKey('demo-style-film-job-${job.jobId}'),
      color: demoSurface(context),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action ?? onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title.trim().isEmpty
                          ? job.styleNameZh.trim().isNotEmpty
                                ? job.styleNameZh
                                : job.styleId
                          : job.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: color),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, IconData, Color) _presentation(
    AppLocalizations l,
    Color errorColor,
  ) {
    if (job.isCompleted) {
      return (
        l.demoStyleFilmCompleted,
        Icons.play_circle_outline_rounded,
        AppColors.success,
      );
    }
    if (job.isFailed) {
      return (l.demoStyleFilmFailed, Icons.error_outline_rounded, errorColor);
    }
    if (job.isAwaitingReview) {
      return (
        l.demoStyleFilmAwaitingStoryboard,
        Icons.view_carousel_outlined,
        AppColors.brand,
      );
    }
    if (job.state == 'planning' || job.state == 'storyboard_rendering') {
      return (
        l.demoStyleFilmPreparingStoryboard,
        Icons.auto_awesome_outlined,
        AppColors.brand,
      );
    }
    return (
      l.demoStyleFilmCreating,
      Icons.movie_creation_outlined,
      AppColors.brand,
    );
  }
}
