import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/conversation_snapshot.dart';
import 'conversation_card.dart';
import 'conversation_card_content.dart';
import 'conversation_timeline.dart' show MarkdownMessage;

/// Confirmed stories keep their title visible while long documents scroll.
class ConversationSelectedTopicCard extends StatefulWidget {
  const ConversationSelectedTopicCard({
    required this.block,
    this.framed = true,
    super.key,
  });

  final ConversationBlock block;
  final bool framed;

  @override
  State<ConversationSelectedTopicCard> createState() =>
      _ConversationSelectedTopicCardState();
}

class _ConversationSelectedTopicCardState
    extends State<ConversationSelectedTopicCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final block = widget.block;
    final statusColor = colors.brightness == Brightness.light
        ? AppColors.success
        : const Color(0xFF8BCBA0);
    final hasContent = block.body.isNotEmpty || block.hook.isNotEmpty;
    final hasHeading = RegExp(
      r'^\s*#{1,6}\s',
      multiLine: true,
    ).hasMatch(block.body);
    return ConversationCard(
      framed: widget.framed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, size: 18, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.chatTopicConfirmed,
                  style: ConversationCardTypography.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (hasContent)
                IconButton(
                  key: const Key('conversation-selected-topic-toggle'),
                  tooltip: _expanded
                      ? l10n.chatCollapseStory
                      : l10n.chatExpandStory,
                  visualDensity: VisualDensity.standard,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (block.title.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              block.title,
              style: ConversationCardTypography.title.copyWith(
                fontSize: 18,
                height: 1.45,
                color: colors.onSurface,
              ),
            ),
          ],
          if (_expanded && hasContent) ...[
            Divider(height: 28, color: colors.outlineVariant),
            ConversationCardContent(
              storageId: 'selected-topic:${block.referenceId}:${block.scopeId}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (block.body.isNotEmpty) ...[
                    if (!hasHeading) ...[
                      Text(
                        l10n.roleStoryOverview,
                        style: ConversationCardTypography.title,
                      ),
                      const SizedBox(height: 8),
                    ],
                    MarkdownMessage(text: block.body, compact: true),
                  ],
                  if (block.hook.isNotEmpty &&
                      !block.body.contains(block.hook)) ...[
                    if (block.body.isNotEmpty) const SizedBox(height: 20),
                    Text(
                      l10n.chatPlanHighlight,
                      style: ConversationCardTypography.title,
                    ),
                    const SizedBox(height: 8),
                    MarkdownMessage(text: block.hook, compact: true),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
