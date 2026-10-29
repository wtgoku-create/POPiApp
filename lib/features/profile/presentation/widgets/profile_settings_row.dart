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
    this.spacious = false,
    this.foregroundColor,
    this.busy = false,
    super.key,
  }) : assert(icon != null || iconWidget != null);

  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final IconData? trailing;
  final bool showChevron;
  final bool spacious;
  final Color? foregroundColor;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = foregroundColor ?? colorScheme.onSurface;
    final secondary =
        spacious && Theme.of(context).brightness == Brightness.light
        ? AppColors.textTertiary
        : colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        spacious ? AppRadii.card : AppRadii.medium,
      ),
      child: SizedBox(
        height: spacious ? 60 : 48,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: spacious ? 20 : 16),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                SizedBox.square(
                  dimension: spacious ? 30 : 20,
                  child: Center(
                    child: iconWidget == null
                        ? Icon(icon, size: 20, color: foreground)
                        : ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              foreground,
                              BlendMode.srcIn,
                            ),
                            child: iconWidget!,
                          ),
                  ),
                ),
                SizedBox(width: spacious ? 5 : 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: spacious ? 18 : 16,
                      fontWeight: spacious ? FontWeight.w600 : FontWeight.w400,
                      color: foreground,
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
                      style: TextStyle(fontSize: 16, color: secondary),
                    ),
                  ),
                ],
                if (showChevron || busy) ...[
                  SizedBox(width: spacious ? 0 : 7),
                  SizedBox.square(
                    dimension: spacious ? 30 : 20,
                    child: Center(
                      child: busy
                          ? SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: foreground,
                              ),
                            )
                          : trailing == null
                          ? AppSvgIcon.asset(
                              'profile_settings_chevron',
                              size: 13,
                              color: spacious
                                  ? colorScheme.onSurface
                                  : secondary,
                            )
                          : Icon(trailing, size: 20, color: secondary),
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
