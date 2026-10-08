import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_svg_icon.dart';

/// Personalized welcome and the three creation entry points.
class HomeCreationWelcome extends StatelessWidget {
  const HomeCreationWelcome({
    required this.name,
    required this.onStart,
    super.key,
  });

  final String name;
  final ValueChanged<String> onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final entries = [
      (l10n.homeStartIp, 'home_start_ip', const Color(0xFFEDE7FD)),
      (l10n.homeStartRole, 'home_start_role', const Color(0xFFFEEEF6)),
      (l10n.homeStartContent, 'home_start_content', const Color(0xFFE5FBFA)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => Padding(
            padding: EdgeInsets.symmetric(
              horizontal: constraints.maxWidth < 330 ? 0 : 15,
            ),
            child: Text(
              name.isEmpty ? l10n.homeWelcomeGuest : l10n.homeWelcomeUser(name),
              key: const Key('home-personal-greeting'),
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 30,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        LayoutBuilder(
          builder: (context, constraints) {
            final characterWidth = math.min(
              184.0,
              math.max(90.0, constraints.maxWidth - 208),
            );
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: 8,
                  bottom: -81 * characterWidth / 184,
                  child: Image.asset(
                    'assets/images/home_welcome_character.png',
                    key: const Key('home-welcome-character'),
                    width: characterWidth,
                    height: characterWidth * 222 / 184,
                    fit: BoxFit.fill,
                    excludeFromSemantics: true,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    left: 15,
                    right: characterWidth + 8,
                    bottom: 42,
                  ),
                  child: Text(
                    '${l10n.homeWelcomeBody}\n${l10n.homePromptIntro}\n${l10n.homePromptQuestion}',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        Container(
          key: const Key('home-creation-panel'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: dark ? colors.surfaceContainerLow : Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Stack(
            children: [
              if (!dark)
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/home_prompt_background.png',
                    fit: BoxFit.fill,
                    excludeFromSemantics: true,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
                child: Column(
                  children: [
                    for (var i = 0; i < entries.length; i++) ...[
                      _CreationEntry(
                        index: i,
                        label: entries[i].$1,
                        icon: entries[i].$2,
                        iconBackground: entries[i].$3,
                        onTap: () => onStart(entries[i].$1),
                      ),
                      if (i < entries.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CreationEntry extends StatelessWidget {
  const _CreationEntry({
    required this.index,
    required this.label,
    required this.icon,
    required this.iconBackground,
    required this.onTap,
  });

  final int index;
  final String label;
  final String icon;
  final Color iconBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark
          ? colors.surfaceContainerHigh
          : Colors.white.withValues(alpha: .5),
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        key: Key('home-start-$index'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: AppSvgIcon.asset(icon, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox.square(
                  dimension: 40,
                  child: Center(
                    child: AppSvgIcon.asset(
                      'home_welcome_chevron',
                      size: 13,
                      color: colors.onSurface,
                    ),
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
