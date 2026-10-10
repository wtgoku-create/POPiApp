import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_svg_icon.dart';
import '../../../assets/domain/library_role.dart';

Color roleGuideTint(BuildContext context) =>
    Theme.of(context).brightness == Brightness.light
    ? const Color(0xFFF8F6FF)
    : Theme.of(context).colorScheme.surfaceContainerHighest;

/// Shared pill action for the character creation flow.
class RoleGuideAction extends StatelessWidget {
  const RoleGuideAction({
    required this.label,
    required this.onPressed,
    this.count,
    this.secondary = false,
    this.showArrow = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final int? count;
  final bool secondary;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = secondary ? colors.onSurface : Colors.white;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: foreground,
          backgroundColor: onPressed == null
              ? colors.onSurface.withValues(alpha: .08)
              : secondary
              ? roleGuideTint(context)
              : AppColors.brand,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text.rich(
                TextSpan(
                  text: label,
                  children: [
                    if (count != null)
                      TextSpan(
                        text: AppLocalizations.of(
                          context,
                        )!.roleSelectedCount(count!),
                        style: const TextStyle(fontSize: 14),
                      ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: secondary ? FontWeight.w400 : FontWeight.w600,
                  color: onPressed == null
                      ? Theme.of(context).disabledColor
                      : foreground,
                ),
              ),
            ),
            if (showArrow) ...[
              const SizedBox(width: 5),
              SizedBox(
                width: 8,
                height: 14,
                child: AppSvgIcon.asset(
                  'role_guide_forward',
                  color: onPressed == null
                      ? Theme.of(context).disabledColor
                      : foreground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reusable segment control that grows vertically for translated labels.
class RoleGuideSegments extends StatelessWidget {
  const RoleGuideSegments({
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.filledTrack = true,
    this.scrollable = false,
    super.key,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final bool filledTrack;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final buttons = [
      for (var i = 0; i < labels.length; i++)
        Semantics(
          selected: i == selected,
          child: TextButton(
            key: Key('role-segment-$i'),
            onPressed: () => onSelected(i),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.standard,
              minimumSize: const Size(0, 34),
              padding: EdgeInsets.symmetric(
                horizontal: scrollable ? 20 : 7,
                vertical: 7,
              ),
              backgroundColor: i == selected
                  ? filledTrack
                        ? Theme.of(context).colorScheme.surface
                        : roleGuideTint(context)
                  : Colors.transparent,
              foregroundColor: i == selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              shape: const StadiumBorder(),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 14,
                fontWeight: i == selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            child: Text(
              labels[i],
              textAlign: TextAlign.center,
              maxLines: scrollable ? 1 : null,
              softWrap: !scrollable,
            ),
          ),
        ),
    ];
    final row = Row(
      mainAxisSize: scrollable ? MainAxisSize.min : MainAxisSize.max,
      children: [
        for (final button in buttons)
          if (scrollable) button else Expanded(child: button),
      ],
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: filledTrack ? roleGuideTint(context) : Colors.transparent,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: scrollable
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: row,
              )
            : row,
      ),
    );
  }
}

class RoleGuideAvatar extends StatelessWidget {
  const RoleGuideAvatar({
    required this.role,
    this.size = 50,
    this.borderRadius,
    super.key,
  });

  final LibraryRole role;
  final double size;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: roleGuideTint(context),
      child: Center(
        child: Text(
          role.title.isEmpty ? '?' : role.title.characters.first,
          style: TextStyle(fontSize: size * .35),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        borderRadius ?? (size >= 70 ? 20 : 15),
      ),
      child: SizedBox.square(
        dimension: size,
        child: role.avatar.isEmpty
            ? fallback
            : role.avatar.startsWith('assets/')
            ? Image.asset(role.avatar, fit: BoxFit.cover)
            : Image.network(
                role.avatar,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class RoleSelectionBadge extends StatelessWidget {
  const RoleSelectionBadge({required this.order, super.key});
  final int order;

  @override
  Widget build(BuildContext context) => Container(
    width: 20,
    height: 20,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: order > 0 ? AppColors.brand : Colors.white.withValues(alpha: .5),
      shape: BoxShape.circle,
      border: order > 0
          ? null
          : Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 4,
            ),
    ),
    child: order > 0
        ? Text(
            '$order',
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1,
              fontWeight: FontWeight.w600,
            ),
          )
        : null,
  );
}
