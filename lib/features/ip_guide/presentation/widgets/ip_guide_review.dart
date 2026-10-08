import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/ip_guide_draft.dart';
import '../ip_guide_copy.dart';
import 'ip_guide_controls.dart';

/// Account plan review reflects the draft, including custom answers.
class IpGuideReview extends StatelessWidget {
  const IpGuideReview({
    required this.draft,
    required this.nicknameController,
    required this.onConfirm,
    super.key,
  });

  final IpGuideDraft draft;
  final TextEditingController nicknameController;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final direction = selectionLabel(
      draft.directions,
      (value) => directionLabel(value, l10n),
      ' × ',
      l10n,
    );
    final feeling = selectionLabel(
      draft.feelings,
      (value) => feelingLabel(value, l10n),
      ' / ',
      l10n,
    );
    final presentation = draft.presentation == null
        ? l10n.ipNotSelected
        : presentationLabel(draft.presentation!, l10n);
    final format = draft.customFormat.trim().isEmpty
        ? formatLabel(draft.format, l10n)
        : draft.customFormat.trim();
    final title = draft.nickname.trim().isEmpty
        ? l10n.ipNewAccount
        : draft.nickname.trim();
    final summaries = [
      (l10n.ipContentDirection, direction),
      (l10n.ipAudienceFeeling, feeling),
      (l10n.ipContentFormat, '$presentation · $format'),
      (l10n.ipTargetAudience, l10n.ipTargetAudienceValue),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            left: 35,
            right: 20,
            top: -18,
            bottom: 18,
            child: Transform.rotate(
              angle: 3.45 * math.pi / 180,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: .05),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Container(
            key: const Key('ip-review-panel'),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              l10n.ipAccountAvatar,
                              style: TextStyle(
                                fontSize: 18,
                                color: colors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  key: const Key('ip-review-name'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                    color: colors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$direction × $presentation',
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.4,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (constraints.maxWidth >= 340) ...[
                            const SizedBox(width: 10),
                            _AccountBadge(label: l10n.ipAccountProfile),
                          ],
                        ],
                      ),
                      if (constraints.maxWidth < 340) ...[
                        const SizedBox(height: 10),
                        _AccountBadge(label: l10n.ipAccountProfile),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  l10n.ipAccountNickname,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.25,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 5),
                IpGuideTextField(
                  key: const Key('ip-nickname'),
                  controller: nicknameController,
                  hint: l10n.ipNicknameHint,
                  limit: 15,
                  nickname: true,
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < summaries.length; i++) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 49),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            flex: 2,
                            child: Text(
                              summaries[i].$1,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 5,
                            child: Text(
                              summaries[i].$2,
                              key: Key('ip-review-value-$i'),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (i < summaries.length - 1)
                    Divider(height: 1, thickness: 1, color: colors.outline),
                ],
                const SizedBox(height: 20),
                IpGuideNextButton(
                  key: const Key('ip-confirm'),
                  label: l10n.ipConfirmCreate,
                  onPressed: onConfirm,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountBadge extends StatelessWidget {
  const _AccountBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 14,
        height: 1.25,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}
