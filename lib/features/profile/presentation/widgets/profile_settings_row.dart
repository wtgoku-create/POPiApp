import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../shared/widgets/app_svg_icon.dart';

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    this.icon,
    this.iconWidget,
    required this.label,
    this.value,
    this.onTap,
    this.trailing,
    this.showChevron = true,
    super.key,
  }) : assert(icon != null || iconWidget != null);

  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final IconData? trailing;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.medium),
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: Center(
                    child: iconWidget == null
                        ? Icon(icon, size: 20, color: colorScheme.onSurface)
                        : ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              colorScheme.onSurface,
                              BlendMode.srcIn,
                            ),
                            child: iconWidget!,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * .55,
                    ),
                    child: Text(
                      value!,
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                if (showChevron) ...[
                  const SizedBox(width: 7),
                  SizedBox.square(
                    dimension: 20,
                    child: Center(
                      child: trailing == null
                          ? AppSvgIcon.asset(
                              'profile_settings_chevron',
                              size: 13,
                              color: colorScheme.onSurfaceVariant,
                            )
                          : Icon(
                              trailing,
                              size: 20,
                              color: colorScheme.onSurfaceVariant,
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
