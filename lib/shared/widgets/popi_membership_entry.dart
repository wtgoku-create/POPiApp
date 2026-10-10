import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'app_svg_icon.dart';

/// Shared balance and membership entry for home and creation sessions.
class PopiMembershipEntry extends StatelessWidget {
  const PopiMembershipEntry({
    required this.points,
    required this.showPoints,
    required this.label,
    required this.onTap,
    this.fontSize = 14,
    this.height = 36,
    super.key,
  });

  final int points;
  final bool showPoints;
  final String label;
  final VoidCallback onTap;
  final double fontSize;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('home-membership-entry'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: Ink(
            key: const Key('home-membership-surface'),
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surfaceContainerHighest
                  : Colors.white.withValues(alpha: .5),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: isDark
                  ? Border.all(color: colorScheme.outlineVariant)
                  : Border.all(color: Colors.white),
            ),
            child: Center(
              widthFactor: 1,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showPoints) ...[
                      SizedBox.square(
                        dimension: 16,
                        child: Center(
                          child: SizedBox(
                            width: 12,
                            height: 7.94,
                            child: const AppSvgIcon.asset(
                              'membership_points',
                              key: Key('home-membership-icon'),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '$points',
                        key: const Key('home-membership-points'),
                        style: TextStyle(
                          color: AppColors.brand,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 7),
                      SizedBox(
                        width: 1,
                        height: 12,
                        child: ColoredBox(color: colorScheme.outline),
                      ),
                      const SizedBox(width: 7),
                    ] else ...[
                      const Icon(
                        Icons.login_rounded,
                        key: Key('home-login-entry-icon'),
                        size: 16,
                        color: AppColors.brand,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      label,
                      key: const Key('home-membership-label'),
                      style: TextStyle(
                        color: showPoints
                            ? colorScheme.onSurface
                            : AppColors.brand,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    if (!showPoints) ...[
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.chevron_right_rounded,
                        key: Key('home-login-entry-chevron'),
                        size: 17,
                        color: AppColors.brand,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
