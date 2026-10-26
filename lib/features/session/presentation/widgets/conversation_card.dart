import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import 'conversation_style.dart';

/// Shared text hierarchy for conversation cards and their embedded documents.
abstract final class ConversationCardTypography {
  static const title = TextStyle(
    fontSize: 16,
    height: 1.5,
    fontWeight: FontWeight.w600,
  );
  static const body = TextStyle(fontSize: 14, height: 1.6);
  static const caption = TextStyle(fontSize: 13, height: 1.5);
}

/// 会话业务卡片共用外观，内部段落保持无边框布局。
class ConversationCard extends StatelessWidget {
  const ConversationCard({required this.child, this.framed = true, super.key});
  final Widget child;
  final bool framed;

  @override
  Widget build(BuildContext context) => Container(
    padding: framed ? const EdgeInsets.all(20) : EdgeInsets.zero,
    width: double.infinity,
    decoration: framed
        ? BoxDecoration(
            color: ConversationStyle.cardColor(context),
            borderRadius: BorderRadius.circular(ConversationStyle.cardRadius),
          )
        : null,
    child: Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle.merge(
        style: ConversationCardTypography.body.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
        child: child,
      ),
    ),
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
      'canceled' ||
      'cancelled' ||
      'interrupted' ||
      'aborted' => l10n.chatStopped,
      'expired' || 'stale' => l10n.chatExpired,
      'failed' => l10n.chatRunFailed,
      'draft' => l10n.chatRoleDraft,
      _ => '',
    };
