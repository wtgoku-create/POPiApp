import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/generation_credit_notice.dart';
import '../../../role_guide/presentation/widgets/role_storyboard_body.dart';
import '../../domain/conversation_snapshot.dart';
import '../../domain/conversation_task.dart';
import '../conversation_controller.dart';
import '../conversation_error_text.dart';
import 'conversation_card.dart';
import 'conversation_card_content.dart';
import 'conversation_role_card.dart';
import 'conversation_timeline.dart'
    show ConversationMediaView, ConversationObjectView, MarkdownMessage;

/// The home production task uses the same stage and artifact layout as Web.
class ConversationHomeTaskCard extends StatefulWidget {
  const ConversationHomeTaskCard({
    required this.block,
    required this.view,
    required this.controller,
    required this.state,
    required this.disabled,
    required this.onControl,
    super.key,
  });

  final ConversationBlock block;
  final ConversationTaskView view;
  final ConversationController controller;
  final String state;
  final bool disabled;
  final ValueChanged<String> onControl;

  @override
  State<ConversationHomeTaskCard> createState() =>
      _ConversationHomeTaskCardState();
}

class _ConversationHomeTaskCardState extends State<ConversationHomeTaskCard> {
  bool _expanded = true;
  final Map<String, bool> _sections = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final block = widget.block;
    final view = widget.view;
    final status =
        widget.state == 'awaiting_confirmation' &&
            block.data['confirmationReason'] == 'storyboard_review'
        ? l10n.chatStoryboardReview
        : ['queued', 'running'].contains(widget.state) &&
              block.data['intent'] == 'pause'
        ? l10n.chatTaskPausing
        : conversationStatusLabel(widget.state, l10n);
    final stages = view.steps
        .where(
          (step) =>
              ['script', 'storyboard', 'video', 'review'].contains(step.key),
        )
        .toList();
    final confirm =
        widget.state == 'awaiting_confirmation' &&
        block.data['confirmationPending'] == true &&
        block.data['intent'] != 'cancel';
    final steps = view.steps
        .where((step) => step.content != null || step.mediaIds.isNotEmpty)
        .toList();
    return ConversationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      l10n.chatVideoProgress,
                      style: ConversationCardTypography.title.copyWith(
                        color: colors.primary,
                      ),
                    ),
                    if (status.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.onSurface.withValues(alpha: .04),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          status,
                          style: ConversationCardTypography.caption.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                key: Key('conversation-task-toggle-${block.id}'),
                tooltip: _expanded
                    ? l10n.chatCollapseProfile
                    : l10n.roleGuideViewMore,
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
              ),
            ],
          ),
          if (_expanded) ...[
            if (stages.isNotEmpty) _HomeTaskStages(steps: stages),
            if (view.roles.isNotEmpty)
              Column(
                key: const Key('conversation-home-task-cast'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  Text(
                    l10n.chatPlanCast,
                    style: ConversationCardTypography.title.copyWith(
                      color: colors.onSurface,
                    ),
                  ),
                  for (final role in view.roles)
                    ConversationRoleCard(
                      key: ValueKey(role.referenceId),
                      block: role,
                    ),
                ],
              ),
            if (steps.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var index = 0; index < steps.length; index++) ...[
                    if (index > 0)
                      SizedBox(
                        height: _stepGap(steps[index - 1], steps[index]),
                      ),
                    _step(steps[index], l10n),
                  ],
                ],
              ),
            for (final id in view.mediaIds)
              ConversationMediaView(
                key: ValueKey('home-task-media:$id'),
                id: id,
                repository: widget.controller.repository,
              ),
            if (view.errorCode != null || view.error != null)
              Text(
                conversationTaskErrorText(
                  l10n,
                  code: view.errorCode,
                  message: view.error,
                ),
                style: TextStyle(color: colors.error),
              ),
            if (confirm) const GenerationCreditNotice(),
            if (confirm || block.allowedActions.isNotEmpty)
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (confirm)
                    FilledButton.tonal(
                      key: Key('conversation-task-confirm-video-${block.id}'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        backgroundColor: colors.primary.withValues(alpha: .08),
                        foregroundColor: colors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        textStyle: Theme.of(
                          context,
                        ).textTheme.labelLarge?.copyWith(fontSize: 14),
                      ),
                      onPressed: widget.disabled
                          ? null
                          : () => widget.onControl('confirm-video'),
                      child: Text(l10n.roleConfirmVideo),
                    ),
                  for (final action in block.allowedActions.where(
                    (action) =>
                        ['pause', 'resume', 'cancel', 'retry'].contains(action),
                  ))
                    IconButton(
                      key: Key('conversation-task-$action-${block.id}'),
                      tooltip: switch (action) {
                        'pause' => l10n.rolePauseProduction,
                        'resume' => l10n.roleResumeProduction,
                        'cancel' => l10n.roleStopProduction,
                        _ => l10n.retry,
                      },
                      onPressed: widget.disabled
                          ? null
                          : () => widget.onControl(action),
                      icon: Icon(
                        switch (action) {
                          'pause' => Icons.pause,
                          'resume' => Icons.play_arrow,
                          'cancel' => Icons.close,
                          _ => Icons.refresh,
                        },
                        size: 18,
                        color: widget.disabled ? null : colors.primary,
                      ),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  bool _collapsible(ConversationTaskStep step) =>
      step.content != null &&
      step.content!.body.isNotEmpty &&
      ['script', 'storyboard', 'persona'].contains(step.key);

  bool _open(ConversationTaskStep step) =>
      _sections[step.key] ?? step.key != 'storyboard';

  bool _collapsed(ConversationTaskStep step) =>
      _collapsible(step) &&
      !_open(step) &&
      step.mediaIds.every((id) => step.content!.mediaIds.contains(id));

  double _stepGap(ConversationTaskStep before, ConversationTaskStep after) {
    final beforeCollapsed = _collapsed(before);
    final afterCollapsed = _collapsed(after);
    // Collapsed rows already provide their own full-height touch targets.
    if (beforeCollapsed && afterCollapsed) return 0;
    return beforeCollapsed || afterCollapsed ? 8 : 20;
  }

  Widget _step(ConversationTaskStep step, AppLocalizations l10n) {
    final content = step.content;
    return Column(
      key: ValueKey('home-task-step:${step.key}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        if (content != null)
          if (_collapsible(step))
            _section(step, l10n)
          else
            ConversationObjectView(
              block: content,
              controller: widget.controller,
              framed: false,
              mediaSpacing: 16,
            ),
        for (final id in step.mediaIds.where(
          (id) => !(content?.mediaIds.contains(id) ?? false),
        ))
          ConversationMediaView(
            key: ValueKey(id),
            id: id,
            repository: widget.controller.repository,
          ),
      ],
    );
  }

  Widget _section(ConversationTaskStep step, AppLocalizations l10n) {
    final open = _open(step);
    final content = step.content!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton(
          key: Key('conversation-task-section-${step.key}'),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            alignment: Alignment.centerLeft,
            textStyle: ConversationCardTypography.title.copyWith(
              fontFamily: Theme.of(context).textTheme.titleMedium?.fontFamily,
            ),
          ),
          onPressed: () => setState(() => _sections[step.key] = !open),
          child: Row(
            children: [
              Expanded(
                child: Text(switch (step.key) {
                  'script' => l10n.roleScriptContent,
                  'storyboard' => l10n.roleStoryboardContent,
                  _ => l10n.roleStageCharacters,
                }),
              ),
              Icon(
                open ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ConversationCardContent(
              storageId: 'home-task:${widget.block.id}:${step.key}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  if (step.key == 'storyboard' || content.isStoryboard)
                    RoleStoryboardBody(
                      body: content.body,
                      style: ConversationCardTypography.body,
                    )
                  else
                    MarkdownMessage(text: content.body, compact: true),
                  for (final id in content.mediaIds)
                    ConversationMediaView(
                      key: ValueKey(id),
                      id: id,
                      repository: widget.controller.repository,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _HomeTaskStages extends StatelessWidget {
  const _HomeTaskStages({required this.steps});
  final List<ConversationTaskStep> steps;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        // Connectors describe workflow stages; their lengths do not encode progress.
        Row(
          children: [
            for (var index = 0; index < steps.length; index++)
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: index == 0
                            ? Colors.transparent
                            : steps[index - 1].state == 'completed'
                            ? colors.primary
                            : colors.outlineVariant,
                      ),
                    ),
                    Semantics(
                      label: conversationStatusLabel(steps[index].state, l10n),
                      child: SizedBox.square(
                        dimension: 24,
                        child: steps[index].state == 'running'
                            ? const Padding(
                                padding: EdgeInsets.all(3),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                switch (steps[index].state) {
                                  'completed' => Icons.check,
                                  'failed' => Icons.error_outline,
                                  _ => Icons.circle_outlined,
                                },
                                size: 20,
                                color: steps[index].state == 'failed'
                                    ? colors.error
                                    : steps[index].state == 'completed'
                                    ? colors.primary
                                    : colors.primary.withValues(alpha: .3),
                              ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: index == steps.length - 1
                            ? Colors.transparent
                            : steps[index].state == 'completed'
                            ? colors.primary
                            : colors.outlineVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final step in steps)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    switch (step.key) {
                      'script' => l10n.roleStageScript,
                      'storyboard' => l10n.roleStageStoryboard,
                      'video' => l10n.chatStageGenerateVideo,
                      _ => l10n.chatStageInspectResult,
                    },
                    textAlign: TextAlign.center,
                    style: ConversationCardTypography.caption.copyWith(
                      color: ['completed', 'running'].contains(step.state)
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
