import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_skeleton.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../domain/conversation_snapshot.dart';
import '../../domain/conversation_task.dart';
import '../conversation_controller.dart';
import '../conversation_error_text.dart';
import 'conversation_card.dart';
import 'conversation_card_content.dart';
import 'conversation_generation_card.dart';
import 'conversation_progress.dart';
import 'conversation_timeline.dart' show ConversationMediaView;

/// A single generation task owns its loading surface, outputs and saved plan.
class ConversationGenerationTaskCard extends StatefulWidget {
  const ConversationGenerationTaskCard({
    required this.block,
    required this.controller,
    super.key,
  });
  final ConversationBlock block;
  final ConversationController controller;

  @override
  State<ConversationGenerationTaskCard> createState() =>
      _ConversationGenerationTaskCardState();
}

class _ConversationGenerationTaskCardState
    extends State<ConversationGenerationTaskCard> {
  bool _expanded = true;
  bool _planExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final view = ConversationGenerationTaskView(
      widget.block,
      widget.controller.snapshot,
    );
    final activity = conversationProgressTitle(
      widget.block,
      l10n,
      fallback: switch (view.state) {
        'queued' => l10n.chatProgressQueuedGeneration,
        'saving' => l10n.chatProgressSaveMedia,
        'sync_error' => l10n.chatProgressSyncResult,
        _ => switch (widget.block.mediaType) {
          'video' => l10n.chatProgressGenerateVideo,
          'audio' => l10n.chatProgressGenerateAudio,
          _ => l10n.chatProgressGenerateImage,
        },
      },
    );
    final title = view.active
        ? activity
        : view.completed
        ? l10n.chatGenerationTaskCompleted
        : conversationStatusLabel(view.state, l10n);
    final failure = view.state != 'failed'
        ? conversationStatusLabel(view.state, l10n)
        : conversationTaskErrorText(
            l10n,
            code: widget.block.data['errorCode'] as String?,
            message: widget.block.data['error'] as String?,
            fallback: switch (widget.block.mediaType) {
              'image' => l10n.chatImageGenerationFailed,
              'video' => l10n.chatVideoGenerationFailed,
              _ => l10n.chatRunFailed,
            },
          );
    return Semantics(
      key: Key('conversation-generation-task-${widget.block.id}'),
      liveRegion: true,
      child: ConversationCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: ConversationCardTypography.title.copyWith(
                      color: colors.primary,
                    ),
                  ),
                ),
                if (view.active)
                  const _GenerationSpinner()
                else
                  IconButton(
                    key: Key(
                      'conversation-generation-task-toggle-${widget.block.id}',
                    ),
                    tooltip: _expanded
                        ? l10n.chatCollapseTask
                        : l10n.chatExpandTask,
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: colors.primary.withValues(alpha: .6),
                    ),
                  ),
              ],
            ),
            if (view.active || _expanded) ...[
              const SizedBox(height: 10),
              if (view.active)
                _GenerationPlaceholder(label: activity)
              else if (view.completed)
                if (view.mediaIds.isEmpty)
                  AppSkeleton(
                    label: l10n.loadingAssets,
                    child: const AspectRatio(
                      aspectRatio: 16 / 9,
                      child: AppSkeletonBox(radius: 20),
                    ),
                  )
                else
                  ConversationCardContent(
                    storageId: 'generation-task:${widget.block.id}:outputs',
                    child: Column(
                      children: [
                        for (final id in view.mediaIds)
                          ConversationMediaView(
                            key: ValueKey(id),
                            id: id,
                            repository: widget.controller.repository,
                            result: true,
                          ),
                      ],
                    ),
                  )
              else
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                        builder: (context, constraints) => Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                              width: constraints.maxWidth,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 32,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    failure,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (view.fixedPlan case final plan?) ...[
                const SizedBox(height: 10),
                TextButton(
                  key: Key(
                    'conversation-generation-task-plan-${widget.block.id}',
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: colors.onSurfaceVariant,
                  ),
                  onPressed: () =>
                      setState(() => _planExpanded = !_planExpanded),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.roleViewPlan,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(fontSize: 14),
                        ),
                      ),
                      Icon(
                        _planExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 20,
                      ),
                    ],
                  ),
                ),
                if (_planExpanded)
                  ConversationGenerationCard(
                    block: plan,
                    controller: widget.controller,
                    readOnly: true,
                    embedded: true,
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _GenerationPlaceholder extends StatelessWidget {
  const _GenerationPlaceholder({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => AspectRatio(
    key: const Key('conversation-generation-placeholder'),
    aspectRatio: 16 / 9,
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE5D7E7), Color(0xFF5FA6DD), Color(0xFFB461E7)],
          stops: [0, .52, 1],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) => Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const RotatedBox(
                      quarterTurns: 2,
                      child: AppSvgIcon.asset(
                        'chat_generation_loading',
                        size: 81,
                      ),
                    ),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _GenerationSpinner extends StatefulWidget {
  const _GenerationSpinner();
  @override
  State<_GenerationSpinner> createState() => _GenerationSpinnerState();
}

class _GenerationSpinnerState extends State<_GenerationSpinner>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _spin.stop();
      _spin.value = 0;
    } else {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
    turns: _spin,
    child: const AppSvgIcon.asset('chat_generation_spinner', size: 20),
  );
}
