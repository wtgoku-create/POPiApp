import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../session/presentation/widgets/conversation_progress.dart'
    show conversationProgressLabel;
import '../../domain/demo_models.dart';

/// Compact public activity for the assistant currently handling a message.
class DemoActivityIndicator extends StatelessWidget {
  const DemoActivityIndicator({
    required this.activity,
    required this.memberName,
    required this.avatar,
    super.key,
  });

  final DemoActivity activity;
  final String memberName;
  final Widget avatar;

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
    return Semantics(
      label: l.demoActivityTitle(memberName, label),
      excludeSemantics: true,
      liveRegion: running,
      child: Row(
        key: const Key('demo-activity-row'),
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: KeyedSubtree(
              key: const Key('demo-activity-avatar'),
              child: avatar,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              key: const Key('demo-activity-label'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
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
