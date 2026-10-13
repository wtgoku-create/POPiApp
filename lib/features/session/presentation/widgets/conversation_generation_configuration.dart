import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_skeleton.dart';
import '../../../role_guide/domain/home_creation.dart';

/// Shared model summary displayed outside a generation card's scroll viewport.
class ConversationGenerationConfiguration extends StatelessWidget {
  const ConversationGenerationConfiguration({
    required this.config,
    required this.model,
    required this.points,
    this.savedConfiguration = const [],
    this.loading = false,
    this.estimating = false,
    this.onModelParametersRequested,
    super.key,
  });

  final HomeConfig? config;
  final HomeModel? model;
  final num? points;
  final List<String> savedConfiguration;
  final bool loading;
  final bool estimating;
  final VoidCallback? onModelParametersRequested;

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
    final configuration = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(l10n.chatPlanConfiguration, style: heading)),
            if (onModelParametersRequested != null)
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
            points == null
                ? l10n.chatUnavailable
                : l10n.chatPlanCredits(points.toString()),
            style: body,
          ),
      ],
    );
    return ColoredBox(
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
                children: [configuration, const SizedBox(height: 16), estimate],
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
    );
  }

  List<String> _configuration(AppLocalizations l10n) {
    if (savedConfiguration.isNotEmpty) {
      return savedConfiguration;
    }
    final selected = config;
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
