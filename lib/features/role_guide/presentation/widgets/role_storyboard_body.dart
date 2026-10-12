import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/home_storyboard.dart';
import 'role_guide_markdown.dart';

/// Presents each shot independently without exposing transport metadata.
class RoleStoryboardBody extends StatelessWidget {
  const RoleStoryboardBody({required this.storyboard, super.key});

  final HomeStoryboard storyboard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < storyboard.shots.length; index++) ...[
          if (index > 0) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
          ],
          Text(
            l10n.roleStoryboardShot(
              index + 1,
              storyboard.shots[index].duration.toString(),
            ),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          RoleGuideMarkdown(
            text: storyboard.shots[index].description,
            color: color,
            softLineBreak: true,
          ),
        ],
        if (storyboard.modelPrompt != null) ...[
          const SizedBox(height: 20),
          Text(
            l10n.roleVideoModelPrompt,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          RoleGuideMarkdown(
            text: storyboard.modelPrompt!,
            color: color,
            softLineBreak: true,
          ),
        ],
      ],
    );
  }
}
