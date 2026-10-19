import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/conversation_snapshot.dart';

String conversationProgressTitle(
  ConversationBlock block,
  AppLocalizations l10n, {
  String? fallback,
}) {
  if (['canceled', 'cancelled', 'aborted'].contains(block.status)) {
    return l10n.chatStopped;
  }
  if (['failed', 'interrupted'].contains(block.status)) {
    return l10n.chatRunFailed;
  }
  if (block.status == 'completed') {
    return block.data['awaitingConfirmation'] == true
        ? l10n.chatAwaitingConfirmation
        : l10n.chatThoughtProcess;
  }
  final current = block.progressDetails.reversed
      .where((step) => ['running', 'waiting', 'pending'].contains(step.status))
      .firstOrNull;
  return current == null
      ? fallback ?? l10n.chatThinking
      : conversationProgressLabel(current.labelKey, l10n);
}

String conversationProgressLabel(
  String key,
  AppLocalizations l10n,
) => switch (key) {
  'script.run.preparing' ||
  'pages.studio.progress.prepare' => l10n.chatPreparing,
  'script.run.generatingReply' ||
  'pages.studio.progress.reply' => l10n.chatGeneratingReply,
  'script.run.savingArtifact' ||
  'pages.studio.progress.saveText' => l10n.chatSavingArtifact,
  'script.run.planningGeneration' ||
  'pages.studio.progress.preparePlan' => l10n.chatPlanningGeneration,
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
  'pages.studio.progress.saveRole' ||
  'pages.studio.progress.updateRole' => l10n.chatSaveRole,
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
  _ => l10n.chatProcessing,
};

String _finishedProgressLabel(String key, AppLocalizations l10n) =>
    switch (key) {
      'script.run.preparing' ||
      'pages.studio.progress.prepare' => l10n.chatStepPrepare,
      'script.run.generatingReply' ||
      'pages.studio.progress.reply' => l10n.chatStepReply,
      'script.run.savingArtifact' ||
      'pages.studio.progress.saveText' => l10n.chatStepSaveText,
      'script.run.planningGeneration' ||
      'pages.studio.progress.preparePlan' => l10n.chatStepPreparePlan,
      'pages.studio.progress.analyze' => l10n.chatStepAnalyze,
      'pages.studio.progress.readRole' => l10n.chatStepReadRole,
      'pages.studio.progress.readContext' => l10n.chatStepReadContext,
      'pages.studio.progress.topics' => l10n.chatStepTopics,
      'pages.studio.progress.prepareRole' => l10n.chatStepPrepareRole,
      'pages.studio.progress.saveRole' ||
      'pages.studio.progress.updateRole' => l10n.chatStepSaveRole,
      'pages.studio.progress.publishRole' => l10n.chatStepPublishRole,
      'pages.studio.progress.verifyResult' => l10n.chatStepVerifyResult,
      'pages.studio.progress.generateImage' => l10n.chatStepGenerateImage,
      'pages.studio.progress.generateVideo' => l10n.chatStepGenerateVideo,
      'pages.studio.progress.generateAudio' => l10n.chatStepGenerateAudio,
      'pages.studio.progress.syncResult' => l10n.chatStepSyncResult,
      'pages.studio.state.completed' => l10n.chatThoughtProcess,
      'script.run.processing' => l10n.chatStepProcess,
      _ => conversationProgressLabel(key, l10n),
    };

/// Shared by conversation progress and the details of a generation task.
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final step in steps)
          Padding(
            key: ValueKey((step.parentId, step.labelKey)),
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
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      value: MediaQuery.disableAnimationsOf(context)
                          ? .75
                          : null,
                    ),
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
                    ['completed', 'failed', 'skipped'].contains(step.status)
                        ? _finishedProgressLabel(step.labelKey, l10n)
                        : conversationProgressLabel(step.labelKey, l10n),
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
                        'completed' => l10n.chatCompleted,
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
