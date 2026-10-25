import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_generation_indicator.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../session/domain/conversation_snapshot.dart';
import '../../../session/presentation/widgets/conversation_progress.dart';
import '../../domain/demo_models.dart';

/// Public execution stages for a message, with optional expandable history.
class DemoActivityIndicator extends StatelessWidget {
  const DemoActivityIndicator({
    required this.activity,
    required this.memberName,
    required this.expanded,
    required this.onToggle,
    super.key,
  });

  final DemoActivity activity;
  final String memberName;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final running = activity.status == 'running';
    final label = switch (activity.status) {
      'completed' => l.chatCompleted,
      'failed' => l.chatProgressRunFailed,
      'stopped' => l.chatProgressStopped,
      'waiting_user' => l.chatProgressWaitingInput,
      _ => conversationProgressLabel(_labelKey(activity.kind), l),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: running,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActivityIcon(kind: activity.kind, animated: running),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l.demoActivityTitle(memberName, label),
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: running ? colors.onSurface : colors.onSurfaceVariant,
                  ),
                ),
              ),
              if (activity.steps.isNotEmpty)
                Semantics(
                  expanded: expanded,
                  child: IconButton(
                    key: const Key('demo-activity-toggle'),
                    tooltip: expanded
                        ? l.chatCollapseProgress
                        : l.chatExpandProgress,
                    onPressed: onToggle,
                    icon: Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (expanded && activity.steps.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) => Container(
              key: const Key('demo-activity-steps'),
              width: math.min(constraints.maxWidth, 360),
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light
                    ? colors.surface.withValues(alpha: .75)
                    : colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(26),
              ),
              child: ConversationProgressSteps(
                showStatusLabels: false,
                steps: [
                  for (final step in activity.steps)
                    ConversationProgressStep(
                      id: step.id,
                      labelKey: _labelKey(step.kind),
                      status: switch (step.status == 'running' && !running
                          ? activity.status
                          : step.status) {
                        'completed' => 'completed',
                        'failed' => 'failed',
                        'stopped' => 'skipped',
                        'waiting_user' => 'waiting',
                        _ => step.status,
                      },
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _labelKey(String kind) => switch (kind) {
  'thinking' => 'harness.activity.thinking',
  'model' => 'harness.activity.model',
  'search' => 'harness.activity.search',
  'fetch' => 'harness.activity.fetch',
  'image' => 'pages.studio.progress.generateImage',
  'video' => 'pages.studio.progress.generateVideo',
  'script' => 'pages.studio.progress.writeScript',
  'audio' => 'pages.studio.progress.generateAudio',
  'vision' => 'harness.activity.vision',
  'reply' => 'script.run.generatingReply',
  _ => 'script.run.processing',
};

class _ActivityIcon extends StatelessWidget {
  const _ActivityIcon({required this.kind, required this.animated});

  final String kind;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final asset = switch (kind) {
      'search' || 'fetch' => 'demo_search',
      'image' || 'vision' => 'demo_image',
      'video' => 'demo_video',
      'script' => 'session_artifact_script',
      'audio' => 'demo_audio',
      _ => null,
    };
    final color = Theme.of(context).colorScheme.primary;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 24,
        child: asset == null
            ? AppGenerationIndicator(animated: animated, size: 24, color: color)
            : AppSvgIcon.asset(asset, size: 24, color: color),
      ),
    );
  }
}
