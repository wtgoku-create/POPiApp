import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/generation_credit_notice.dart';
import '../../../role_guide/domain/home_creation.dart';
import '../../domain/conversation_generation_view.dart';
import '../../domain/conversation_snapshot.dart';
import 'conversation_card.dart';
import 'conversation_card_content.dart';
import 'conversation_generation_configuration.dart';
import 'conversation_role_card.dart';
import 'conversation_timeline.dart' show MarkdownMessage;

/// Production plans mirror the Web sections while keeping controls visible.
class ConversationHomePlanCard extends StatelessWidget {
  const ConversationHomePlanCard({
    required this.block,
    required this.view,
    required this.expanded,
    required this.onToggle,
    required this.editable,
    required this.loading,
    required this.estimating,
    required this.config,
    required this.model,
    required this.points,
    required this.actions,
    this.validationMessage,
    super.key,
  });

  final ConversationBlock block;
  final ConversationGenerationView view;
  final bool expanded;
  final VoidCallback onToggle;
  final bool editable;
  final bool loading;
  final bool estimating;
  final HomeConfig? config;
  final HomeModel? model;
  final num? points;
  final Widget actions;
  final String? validationMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final heading = ConversationCardTypography.title.copyWith(
      color: colors.onSurface,
    );
    final body = ConversationCardTypography.body.copyWith(
      color: colors.onSurfaceVariant,
    );
    return ConversationCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.chatProductionPlan,
                  style: heading.copyWith(color: colors.primary),
                ),
              ),
              IconButton(
                tooltip: expanded
                    ? l10n.chatCollapseProfile
                    : l10n.roleGuideViewMore,
                onPressed: onToggle,
                icon: Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: colors.primary.withValues(alpha: .6),
                  size: 20,
                ),
              ),
            ],
          ),
          if (expanded) ...[
            Text(l10n.chatPlanCast, style: heading),
            const SizedBox(height: 8),
            for (final role in block.homeCast)
              ConversationRoleCard(block: role),
            if (block.homeTopic case final topic?) ...[
              const SizedBox(height: 12),
              ConversationCardContent(
                storageId: 'generation:${block.id}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.chatPlanStory, style: heading),
                    const SizedBox(height: 8),
                    Text(
                      topic.title,
                      style: heading.copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    if (!view.storyHasHeading)
                      Text(l10n.roleStoryOverview, style: body),
                    MarkdownMessage(
                      text: topic.body,
                      compact: true,
                      style: body,
                    ),
                    if (view.storyHook.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(l10n.chatPlanHighlight, style: heading),
                      const SizedBox(height: 4),
                      MarkdownMessage(
                        text: view.storyHook,
                        compact: true,
                        style: body,
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            ConversationGenerationConfiguration(
              config: editable ? config : view.config,
              model: model,
              points: editable ? points : block.estimatedPoints,
              savedConfiguration: editable ? const [] : view.configurationLines,
              loading: loading,
              estimating: estimating,
            ),
            if (validationMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  validationMessage!,
                  style: body.copyWith(color: colors.error),
                ),
              ),
            if (editable) ...[const GenerationCreditNotice(), actions],
          ],
        ],
      ),
    );
  }
}
