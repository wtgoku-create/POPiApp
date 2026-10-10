import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../domain/ip_guide_draft.dart';
import '../ip_guide_copy.dart';
import 'ip_guide_controls.dart';

/// Account plan review reflects the draft, including custom answers.
class IpGuideReview extends StatelessWidget {
  const IpGuideReview({
    required this.draft,
    required this.nicknameController,
    required this.onConfirm,
    required this.onReselect,
    required this.onCreateRole,
    required this.onCreateContent,
    required this.onOpenProject,
    this.busy = false,
    this.submitted = false,
    this.completed = false,
    super.key,
  });

  final IpGuideDraft draft;
  final TextEditingController nicknameController;
  final VoidCallback onConfirm;
  final VoidCallback onReselect;
  final VoidCallback onCreateRole;
  final VoidCallback onCreateContent;
  final VoidCallback onOpenProject;
  final bool busy;
  final bool submitted;
  final bool completed;

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
      (l10n.ipPresentation, '$presentation · $format'),
      (
        l10n.ipTargetAudience,
        selectionLabel(
          draft.audience,
          (value) => audienceLabel(value, l10n),
          ' × ',
          l10n,
        ),
      ),
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
                          const AppSvgIcon.asset('ip_guide_account', size: 50),
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
                if (!completed) ...[
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
                    editInSheet: false,
                    readOnly: submitted,
                  ),
                ],
                const SizedBox(height: 20),
                for (var i = 0; i < summaries.length; i++) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 49),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            summaries[i].$1,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            summaries[i].$2,
                            key: Key('ip-review-value-$i'),
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: colors.onSurface,
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
                if (completed) ...[
                  IpGuideNextButton(
                    key: const Key('ip-create-role'),
                    label: l10n.ipCreateFirstRole,
                    onPressed: busy ? null : onCreateRole,
                  ),
                  const SizedBox(height: 10),
                  IpGuideNextButton(
                    key: const Key('ip-create-content'),
                    label: l10n.ipCreateFirstContent,
                    onPressed: busy ? null : onCreateContent,
                  ),
                  const SizedBox(height: 10),
                  _SecondaryAction(
                    key: const Key('ip-open-project'),
                    label: l10n.ipOpenProject,
                    onPressed: busy ? null : onOpenProject,
                  ),
                ] else ...[
                  IpGuideNextButton(
                    key: const Key('ip-confirm'),
                    label: busy ? l10n.ipCreating : l10n.ipConfirmCreate,
                    onPressed: busy ? null : onConfirm,
                  ),
                  if (!submitted) ...[
                    const SizedBox(height: 10),
                    _SecondaryAction(
                      key: const Key('ip-reselect'),
                      label: l10n.ipReselect,
                      onPressed: busy ? null : onReselect,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  const _SecondaryAction({
    required this.label,
    required this.onPressed,
    super.key,
  });
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(0, 50),
      shape: const StadiumBorder(),
      backgroundColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: .05),
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 18),
    ),
    child: Text(label, textAlign: TextAlign.center),
  );
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
