import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_skeleton.dart';
import '../../../role_guide/domain/home_creation.dart';
import '../../domain/conversation_generation_view.dart';
import '../../domain/conversation_snapshot.dart';
import 'conversation_card.dart';
import 'conversation_card_content.dart';
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
    this.onModelParametersRequested,
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
  final VoidCallback? onModelParametersRequested;
  final String? validationMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final heading = TextStyle(
      fontSize: 14,
      height: 1.5,
      color: colors.onSurface,
    );
    final body = TextStyle(
      fontSize: 13,
      height: 1.6,
      color: colors.onSurfaceVariant,
    );
    final displayedPoints = editable ? points : block.estimatedPoints;
    final configuration = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(l10n.chatPlanConfiguration, style: heading)),
            if (editable && onModelParametersRequested != null)
              IconButton(
                tooltip: l10n.roleModelParameters,
                onPressed: onModelParametersRequested,
                icon: const Icon(Icons.tune, size: 18),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (loading)
          AppSkeleton(
            label: l10n.loadingAssets,
            child: const AppSkeletonBox(height: 14),
          )
        else
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              for (final line in _configuration(l10n)) Text(line, style: body),
            ],
          ),
      ],
    );
    final estimate = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.chatPlanPoints, style: heading),
        const SizedBox(height: 8),
        if (loading || estimating)
          AppSkeleton(
            label: l10n.roleEstimatePending,
            child: const AppSkeletonBox(width: 80, height: 14),
          )
        else
          Text(
            displayedPoints == null
                ? l10n.chatUnavailable
                : l10n.chatPlanCredits(displayedPoints.toString()),
            style: body,
          ),
      ],
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
                      Text(
                        l10n.chatPlanHighlight,
                        style: heading.copyWith(fontSize: 13),
                      ),
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
            ColoredBox(
              key: const Key('conversation-plan-configuration'),
              color: colors.surface.withValues(alpha: .55),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth /
                            MediaQuery.textScalerOf(context).scale(1) <
                        440) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          configuration,
                          const SizedBox(height: 16),
                          estimate,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: configuration),
                        const SizedBox(width: 20),
                        SizedBox(width: 130, child: estimate),
                      ],
                    );
                  },
                ),
              ),
            ),
            if (validationMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  validationMessage!,
                  style: body.copyWith(color: colors.error),
                ),
              ),
            if (editable) actions,
          ],
        ],
      ),
    );
  }

  List<String> _configuration(AppLocalizations l10n) {
    if (!editable && view.configurationLines.isNotEmpty) {
      return view.configurationLines;
    }
    final selected = editable ? config : view.config;
    if (selected == null) return [l10n.chatUnavailable];
    return [
      '${l10n.chatPlanModel}: ${model?.name ?? l10n.chatUnavailable}',
      for (final entry in selected.params.entries)
        if (entry.value != null && _parameterLabel(entry.key, l10n) != null)
          '${_parameterLabel(entry.key, l10n)}: ${_parameterValue(entry, l10n)}',
    ];
  }

  String? _parameterLabel(String name, AppLocalizations l10n) => switch (name) {
    'resolution' => l10n.roleResolution,
    'ratio' => l10n.roleRatio,
    'duration' => l10n.roleDuration,
    _ =>
      model?.parameters
          .where((p) => p.name == name && p.label.isNotEmpty)
          .firstOrNull
          ?.label,
  };

  String _parameterValue(
    MapEntry<String, Object?> entry,
    AppLocalizations l10n,
  ) {
    final option = model?.parameters
        .where((p) => p.name == entry.key)
        .firstOrNull
        ?.options
        .where((option) => option.value == entry.value)
        .firstOrNull;
    if (option != null) return option.label;
    if (entry.key == 'duration' && entry.value is num) {
      return l10n.roleDurationSeconds(entry.value.toString());
    }
    return entry.value.toString();
  }
}
