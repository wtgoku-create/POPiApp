import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../domain/conversation_snapshot.dart';

String conversationProgressTitle(
  ConversationBlock block,
  AppLocalizations l10n, {
  String? fallback,
}) {
  if (['canceled', 'cancelled', 'aborted'].contains(block.status)) {
    return l10n.chatProgressStopped;
  }
  if (['failed', 'interrupted'].contains(block.status)) {
    return l10n.chatProgressRunFailed;
  }
  if (block.status == 'completed') {
    return (block.data['waitingConfirmations'] as List?)?.isNotEmpty == true ||
            block.data['awaitingConfirmation'] == true
        ? l10n.chatAwaitingConfirmation
        : l10n.chatCompleted;
  }
  final current = block.progressDetails.reversed
      .where((step) => ['running', 'waiting', 'pending'].contains(step.status))
      .firstOrNull;
  return current == null
      ? fallback ?? l10n.chatProgressAnalyze
      : conversationProgressLabel(current.labelKey, l10n);
}

String conversationProgressLabel(
  String key,
  AppLocalizations l10n,
) => switch (key) {
  'harness.activity.thinking' => l10n.demoActivityThinking,
  'harness.activity.model' => l10n.demoActivityModel,
  'harness.activity.search' => l10n.demoActivitySearching,
  'harness.activity.fetch' => l10n.demoActivityReadingWeb,
  'harness.activity.vision' => l10n.demoActivityVision,
  'script.run.preparing' => l10n.chatPreparing,
  'script.run.understanding' => l10n.chatProgressUnderstanding,
  'script.run.selectingSkill' => l10n.chatProgressSelectingSkill,
  'script.run.readingRules' => l10n.chatProgressReadingRules,
  'script.run.composing' => l10n.chatProgressComposing,
  'script.run.generatingReply' => l10n.chatGeneratingReply,
  'script.run.planningGeneration' => l10n.chatPlanningGeneration,
  'script.run.preparingGeneration' => l10n.chatProgressPreparingGeneration,
  'script.run.generatingArtifact' => l10n.chatProgressGeneratingArtifact,
  'script.run.savingArtifact' => l10n.chatSavingArtifact,
  'script.run.completingDelivery' => l10n.chatProgressCompletingDelivery,
  'script.run.waiting' => l10n.chatProgressWaitingInput,
  'script.run.processing' => l10n.chatProgressProcessing,
  'pages.studio.progress.prepare' => l10n.chatProgressPrepare,
  'pages.studio.progress.reply' => l10n.chatProgressReply,
  'pages.studio.progress.saveText' => l10n.chatProgressSaveText,
  'pages.studio.progress.preparePlan' => l10n.chatProgressPreparePlan,
  'pages.studio.progress.analyze' => l10n.chatProgressAnalyze,
  'pages.studio.progress.executeTool' => l10n.chatProgressExecuteTool,
  'pages.studio.progress.loadSkill' => l10n.chatProgressLoadSkill,
  'pages.studio.progress.skillTopics' => l10n.chatProgressSkillTopics,
  'pages.studio.progress.skillScript' => l10n.chatProgressSkillScript,
  'pages.studio.progress.skillStoryboard' => l10n.chatProgressSkillStoryboard,
  'pages.studio.progress.skillThreeView' => l10n.chatProgressSkillThreeView,
  'pages.studio.progress.readRole' => l10n.chatReadRole,
  'pages.studio.progress.readContext' => l10n.chatReadContext,
  'pages.studio.progress.topics' => l10n.chatTopics,
  'pages.studio.progress.prepareRole' => l10n.chatPrepareRole,
  'pages.studio.progress.askUser' => l10n.chatAskUser,
  'pages.studio.progress.saveRole' => l10n.chatSaveRole,
  'pages.studio.progress.updateRole' => l10n.chatProgressUpdateRole,
  'pages.studio.progress.publishRole' => l10n.chatPublishRole,
  'pages.studio.progress.writeScript' => l10n.chatProgressWriteScript,
  'pages.studio.progress.writeStoryboard' => l10n.chatProgressWriteStoryboard,
  'pages.studio.progress.readTextSources' => l10n.chatProgressReadTextSources,
  'pages.studio.progress.validateText' => l10n.chatProgressValidateText,
  'pages.studio.progress.readText' => l10n.chatProgressReadText,
  'pages.studio.progress.searchRoles' => l10n.chatProgressSearchRoles,
  'pages.studio.progress.createRole' => l10n.chatProgressCreateRole,
  'pages.studio.progress.copyRole' => l10n.chatProgressCopyRole,
  'pages.studio.progress.adoptRoleImage' => l10n.chatProgressAdoptRoleImage,
  'pages.studio.progress.readAccount' => l10n.chatProgressReadAccount,
  'pages.studio.progress.searchAccounts' => l10n.chatProgressSearchAccounts,
  'pages.studio.progress.selectAccount' => l10n.chatProgressSelectAccount,
  'pages.studio.progress.updateAccount' => l10n.chatProgressUpdateAccount,
  'pages.studio.progress.updateMemory' => l10n.chatProgressUpdateMemory,
  'pages.studio.progress.searchCreations' => l10n.chatProgressSearchCreations,
  'pages.studio.progress.readCreation' => l10n.chatProgressReadCreation,
  'pages.studio.progress.readTemplates' => l10n.chatProgressReadTemplates,
  'pages.studio.progress.readReferences' => l10n.chatProgressReadReferences,
  'pages.studio.progress.validatePlan' => l10n.chatProgressValidatePlan,
  'pages.studio.progress.estimate' => l10n.chatProgressEstimate,
  'pages.studio.progress.awaitConfirmation' => l10n.chatAwaitingConfirmation,
  'pages.studio.progress.verifyResult' => l10n.chatProgressVerifyResult,
  'pages.studio.progress.compilePrompt' => l10n.chatProgressCompilePrompt,
  'pages.studio.progress.validatePrompt' => l10n.chatProgressValidatePrompt,
  'pages.studio.progress.savePrompt' => l10n.chatProgressSavePrompt,
  'pages.studio.progress.retryPrompt' => l10n.chatProgressRetryPrompt,
  'pages.studio.progress.submitGeneration' => l10n.chatProgressSubmitGeneration,
  'pages.studio.progress.queuedGeneration' => l10n.chatProgressQueuedGeneration,
  'pages.studio.progress.generateImage' => l10n.chatProgressGenerateImage,
  'pages.studio.progress.generateVideo' => l10n.chatProgressGenerateVideo,
  'pages.studio.progress.generateAudio' => l10n.chatProgressGenerateAudio,
  'pages.studio.progress.saveMedia' => l10n.chatProgressSaveMedia,
  'pages.studio.progress.syncResult' => l10n.chatProgressSyncResult,
  'pages.studio.state.completed' => l10n.chatCompleted,
  _ => l10n.chatProgressProcessing,
};

/// Structured execution steps shown in a conversation's progress panel.
class ConversationProgressSteps extends StatelessWidget {
  const ConversationProgressSteps({
    required this.steps,
    this.showStatusLabels = true,
    this.singleLine = false,
    super.key,
  });

  final List<ConversationProgressStep> steps;
  final bool showStatusLabels;
  final bool singleLine;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final occurrences = <String, int>{};
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final step in steps)
          Padding(
            key: ValueKey((
              step.id,
              occurrences.update(
                step.id,
                (count) => count + 1,
                ifAbsent: () => 0,
              ),
            )),
            padding: EdgeInsets.fromLTRB(
              step.parentId == null ? 0 : 16,
              5,
              0,
              5,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (step.status == 'running')
                  const SizedBox.square(
                    dimension: 20,
                    child: Center(child: _ProgressSpinner()),
                  )
                else
                  Icon(
                    switch (step.status) {
                      'completed' => Icons.check,
                      'failed' => Icons.error_outline,
                      'skipped' => Icons.remove,
                      _ => Icons.schedule,
                    },
                    size: 20,
                    color: step.status == 'failed'
                        ? colors.error
                        : colors.primary,
                  ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    conversationProgressLabel(step.labelKey, l10n),
                    maxLines: singleLine ? 1 : null,
                    overflow: singleLine ? TextOverflow.ellipsis : null,
                    style: const TextStyle(fontSize: 14, height: 20 / 14),
                  ),
                ),
                if (showStatusLabels) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      switch (step.status) {
                        'running' => l10n.chatProgressRunning,
                        'pending' => l10n.chatProgressPending,
                        'waiting' => l10n.chatProgressWaiting,
                        'completed' => l10n.chatProgressCompleted,
                        'skipped' => l10n.chatStopped,
                        _ => l10n.chatProgressFailed,
                      },
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Matches Web's Arco loading glyph and one-second linear rotation.
class _ProgressSpinner extends StatefulWidget {
  const _ProgressSpinner();

  @override
  State<_ProgressSpinner> createState() => _ProgressSpinnerState();
}

class _ProgressSpinnerState extends State<_ProgressSpinner>
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
    child: AppSvgIcon.asset(
      'chat_progress_running',
      size: 16,
      color: Theme.of(context).colorScheme.primary,
    ),
  );
}
