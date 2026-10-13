import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';

/// 会话业务卡片共用外观，内部段落保持无边框布局。
class ConversationCard extends StatelessWidget {
  const ConversationCard({required this.child, this.framed = true, super.key});
  final Widget child;
  final bool framed;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 4),
    padding: framed ? const EdgeInsets.all(20) : EdgeInsets.zero,
    width: double.infinity,
    decoration: framed
        ? BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.white.withValues(alpha: .6)
                : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadii.card),
          )
        : null,
    child: Material(type: MaterialType.transparency, child: child),
  );
}

String conversationStatusLabel(String status, AppLocalizations l10n) =>
    switch (status) {
      'pending' || 'queued' => l10n.chatQueued,
      'running' || 'saving' || 'resuming' || 'submitting' => l10n.chatThinking,
      'ready' || 'waiting_user' => l10n.chatAwaitingConfirmation,
      'awaiting_confirmation' => l10n.roleConfirmVideo,
      'paused' || 'pause_requested' => l10n.roleTaskPaused,
      'waiting' || 'waiting_external' => l10n.chatWaitingExternal,
      'confirmed' ||
      'answered' ||
      'completed' ||
      'published' ||
      'active' => l10n.chatCompleted,
      'canceling' => l10n.chatCanceling,
      'canceled' || 'interrupted' || 'aborted' => l10n.chatStopped,
      'expired' || 'stale' => l10n.chatExpired,
      'failed' => l10n.chatRunFailed,
      'draft' => l10n.chatRoleDraft,
      _ => '',
    };
