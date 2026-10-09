import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../domain/ip_guide_draft.dart';
import '../ip_guide_copy.dart';
import 'ip_guide_controls.dart';

/// Ordered choices; rows grow together when translated text needs more room.
class IpGuideChoiceGrid<T extends Enum> extends StatelessWidget {
  const IpGuideChoiceGrid({
    required this.values,
    required this.selection,
    required this.label,
    required this.onSelected,
    required this.keyPrefix,
    this.icon,
    this.description,
    this.showAvatar = true,
    super.key,
  });

  final List<T> values;
  final IpGuideSelection<T> selection;
  final String Function(T) label;
  final String Function(T)? icon;
  final String Function(T)? description;
  final ValueChanged<T> onSelected;
  final String keyPrefix;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(18) > 22;
      final columns = description == null
          ? (compact ? 2 : 3)
          : (compact ? 1 : 2);
      return Column(
        children: [
          for (var row = 0; row < (values.length / columns).ceil(); row++) ...[
            if (row > 0) const SizedBox(height: 15),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < columns; column++) ...[
                    if (column > 0) const SizedBox(width: 15),
                    Expanded(
                      child: row * columns + column >= values.length
                          ? const SizedBox()
                          : _choice(context, values[row * columns + column]),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );

  Widget _choice(BuildContext context, T value) {
    final colors = Theme.of(context).colorScheme;
    final order = selection.values.indexOf(value) + 1;
    final feeling = description != null;
    final textColor = !feeling && order > 0 ? colors.primary : colors.onSurface;
    return Semantics(
      selected: order > 0,
      button: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: feeling ? 125 : 110),
        child: Material(
          color: order > 0
              ? colors.primary.withValues(alpha: .05)
              : colors.surface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            key: Key('$keyPrefix-${value.name}'),
            onTap: () => onSelected(value),
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.all(feeling ? 20 : 15),
                  child: feeling
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: Row(
                                children: [
                                  if (showAvatar)
                                    ClipOval(
                                      child: Image.asset(
                                        'assets/images/ip_guide_feeling_avatar.png',
                                        width: 30,
                                        height: 30,
                                        fit: BoxFit.cover,
                                        excludeFromSemantics: true,
                                      ),
                                    ),
                                  if (showAvatar) const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      label(value),
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 15),
                            Text(
                              description!(value),
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppSvgIcon.asset(icon!(value), size: 44),
                              const SizedBox(height: 10),
                              Text(
                                label(value),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IpGuideSelectionBadge(order: order),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class IpGuidePresentationChoices extends StatelessWidget {
  const IpGuidePresentationChoices({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final IpPresentation? selected;
  final ValueChanged<IpPresentation> onSelected;

  static const _images = {
    IpPresentation.aiReal: 'assets/images/ip_guide_ai_real.png',
    IpPresentation.animation2d: 'assets/images/ip_guide_2d.png',
    IpPresentation.animation3d: 'assets/images/ip_guide_3d.png',
    IpPresentation.liveAction: 'assets/images/ip_guide_live.png',
    IpPresentation.pets: 'assets/images/ip_guide_pets.png',
    IpPresentation.clay: 'assets/images/ip_guide_clay.png',
    IpPresentation.ink: 'assets/images/ip_guide_ink.png',
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth < 300 &&
              MediaQuery.textScalerOf(context).scale(18) > 22
          ? 1
          : 2;
      return Column(
        children: [
          for (var row = 0; row < 6 ~/ columns; row++) ...[
            if (row > 0) const SizedBox(height: 15),
            Row(
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) const SizedBox(width: 15),
                  Expanded(
                    child: _tile(
                      context,
                      IpPresentation.values[row * columns + column],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      );
    },
  );

  Widget _tile(BuildContext context, IpPresentation value) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      selected: selected == value,
      button: true,
      child: Material(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('ip-presentation-${value.name}'),
          onTap: () => onSelected(value),
          child: SizedBox(
            height: 125,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  _images[value]!,
                  fit: BoxFit.cover,
                  alignment: value == IpPresentation.aiReal
                      ? const Alignment(0, -.6)
                      : Alignment.center,
                  excludeFromSemantics: true,
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 33),
                        color: Colors.white.withValues(alpha: .65),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          presentationLabel(value, l10n),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IpGuideSelectionBadge(
                    order: selected == value ? 1 : 0,
                    single: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
