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
          child: Row(
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
                  style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
                ),
              ),
              if (value != null)
                Flexible(
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (showChevron) ...[
                const SizedBox(width: 7),
                if (trailing == null)
                  AppSvgIcon.asset(
                    'profile_settings_chevron',
                    size: 13,
                    color: colorScheme.onSurfaceVariant,
                  )
                else
                  Icon(trailing, size: 21, color: colorScheme.onSurfaceVariant),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
