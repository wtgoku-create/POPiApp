import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_dialog.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/generation_credit_notice.dart';
import '../../domain/conversation_snapshot.dart';
import '../../domain/conversation_task.dart';
import '../conversation_controller.dart';
import '../conversation_error_text.dart';
import 'conversation_card.dart';
import 'conversation_card_content.dart';
import 'conversation_home_task_card.dart';
import 'conversation_generation_task_card.dart';
import 'conversation_timeline.dart'
    show
        ConversationObjectView,
        ConversationMediaView,
        MarkdownMessage,
        conversationErrorText;

class ConversationTaskCard extends StatefulWidget {
  const ConversationTaskCard({
    required this.block,
    required this.controller,
    super.key,
  });
  final ConversationBlock block;
  final ConversationController controller;
  @override
  State<ConversationTaskCard> createState() => _ConversationTaskCardState();
}

class _ConversationTaskCardState extends State<ConversationTaskCard>
    with AutomaticKeepAliveClientMixin {
  CancelToken? _token;
  Map<String, Object?>? _capabilities;
  final Set<String> _expandedSteps = {};
  @override
  bool get wantKeepAlive => true;
  bool get _disabled => widget.controller.pending || widget.controller.loading;
  @override
  void initState() {
    super.initState();
    if (widget.block.action == 'workflow') unawaited(_load());
  }

  @override
  void didUpdateWidget(ConversationTaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.block.action == 'workflow' &&
        oldWidget.block.data['stateVersion'] !=
            widget.block.data['stateVersion']) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    _token?.cancel();
    final token = _token = CancelToken();
    setState(() {
      _capabilities = null;
    });
    try {
      final result = await widget.controller.repository.taskCapabilities(
        widget.block.id,
        cancelToken: token,
      );
      if (mounted && !token.isCancelled) setState(() => _capabilities = result);
    } catch (error) {
      if (mounted && !token.isCancelled) {
        AppToast.error(
          context,
          conversationErrorText(error, AppLocalizations.of(context)!),
        );
      }
    }
  }

  Future<void> _control(String action) async {
    if (_disabled) return;
    if (action == 'cancel') {
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await AppDialog.confirm(
        context: context,
        title: l10n.roleStopProductionTitle,
        description: l10n.roleStopProductionDescription,
        cancelLabel: l10n.roleKeepGenerating,
        confirmLabel: l10n.roleStopProduction,
      );
      if (!mounted || confirmed != true || _disabled) return;
    }
    await widget.controller.controlTask(
      widget.block,
      action,
      capabilities: _capabilities,
    );
  }

  @override
  void dispose() {
    _token?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final block = widget.block;
    final view = ConversationTaskView(block, widget.controller.snapshot);
    final l10n = AppLocalizations.of(context)!;
    if (block.action == 'generation') {
      return ConversationGenerationTaskCard(
        block: block,
        controller: widget.controller,
      );
    }
    final actions = ((_capabilities?['allowedActions'] as List?) ?? [])
        .whereType<String>()
        .toList();
    final state = block.data['intent'] == 'cancel' && block.status != 'canceled'
        ? 'canceling'
        : block.status;
    if (block.action == 'home') {
      return ConversationHomeTaskCard(
        block: block,
        view: view,
        controller: widget.controller,
        state: state,
        disabled: _disabled,
        onControl: _control,
      );
    }
    return ConversationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  view.title.isEmpty ? l10n.roleViewPlan : view.title,
                  style: ConversationCardTypography.title,
                ),
              ),
              if (['queued', 'running', 'saving', 'resuming'].contains(state))
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              conversationStatusLabel(state, l10n),
              style: ConversationCardTypography.caption,
            ),
          ),
          if (view.errorCode != null || view.error != null)
            Text(
              conversationTaskErrorText(
                l10n,
                code: view.errorCode,
                message: view.error,
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          for (final step in view.steps) ...[
            Row(
              children: [
                Icon(
                  step.state == 'completed'
                      ? Icons.check
                      : step.state == 'failed'
                      ? Icons.error_outline
                      : Icons.circle_outlined,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(_stepLabel(step.key, l10n))),
                Flexible(
                  child: Text(
                    conversationStatusLabel(step.state, l10n),
                    style: ConversationCardTypography.caption,
                  ),
                ),
                if (step.content != null)
                  IconButton(
                    tooltip: _expandedSteps.contains(step.key)
                        ? l10n.chatCollapseProfile
                        : l10n.roleGuideViewMore,
                    onPressed: () => setState(() {
                      _expandedSteps.contains(step.key)
                          ? _expandedSteps.remove(step.key)
                          : _expandedSteps.add(step.key);
                    }),
                    icon: Icon(
                      _expandedSteps.contains(step.key)
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                  ),
              ],
            ),
            if (step.content != null &&
                (_expandedSteps.contains(step.key) || step.key == 'video'))
              ConversationCardContent(
                storageId: 'task:${block.id}:${step.key}',
                child: ConversationObjectView(
                  block: step.content!,
                  controller: widget.controller,
                  framed: false,
                ),
              ),
            for (final id in step.mediaIds.where(
              (id) =>
                  !(_expandedSteps.contains(step.key) || step.key == 'video') ||
                  !(step.content?.mediaIds.contains(id) ?? false),
            ))
              ConversationMediaView(
                id: id,
                repository: widget.controller.repository,
              ),
          ],
          for (final id in view.mediaIds)
            ConversationMediaView(
              id: id,
              repository: widget.controller.repository,
            ),
          for (final proposal in view.proposals) ...[
            if (proposal.prompts.isNotEmpty)
              ConversationCardContent(
                storageId: 'task:${block.id}:proposal:${proposal.data['id']}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final prompt in proposal.prompts)
                      MarkdownMessage(text: prompt, compact: true),
                  ],
                ),
              ),
            if (proposal.estimatedPoints != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l10n.chatEstimatedPoints(proposal.estimatedPoints.toString()),
                ),
              ),
            if (proposal.status == 'ready') const GenerationCreditNotice(),
            if (proposal.status == 'ready')
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: _disabled || _capabilities == null
                        ? null
                        : () => widget.controller.respondProposal(
                            block,
                            proposal.data,
                            'cancel',
                          ),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed:
                        _disabled ||
                            _capabilities == null ||
                            _capabilities?['mediaExecutionAvailable'] ==
                                false ||
                            block.status != 'waiting_user' ||
                            !proposal.executionAvailable
                        ? null
                        : () => widget.controller.respondProposal(
                            block,
                            proposal.data,
                            'confirm',
                          ),
                    child: Text(l10n.chatConfirmGeneration),
                  ),
                ],
              ),
          ],
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              for (final action in actions.where(
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
                  onPressed: _disabled ? null : () => _control(action),
                  icon: Icon(switch (action) {
                    'pause' => Icons.pause,
                    'resume' => Icons.play_arrow,
                    'cancel' => Icons.close,
                    _ => Icons.refresh,
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _stepLabel(String key, AppLocalizations l10n) => switch (key) {
  'persona' || 'understanding_role' || 'profile' => l10n.roleStageCharacters,
  'script' || 'writing_script' => l10n.roleStageScript,
  'storyboard' || 'creating_storyboard' => l10n.roleStageStoryboard,
  'video' || 'generating_video' => l10n.roleStageVideo,
  'review' => l10n.roleStageReview,
  'writing_video_prompt' => l10n.roleVideoModelPrompt,
  _ => l10n.chatProcessing,
};
