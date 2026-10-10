import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import 'app_svg_icon.dart';

/// Shared activity entry for the home and conversation app bars.
class PopiActivityButton extends StatelessWidget {
  const PopiActivityButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return SizedBox.square(
      dimension: 42,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (dark ? theme.colorScheme.surface : Colors.white).withValues(
            alpha: .5,
          ),
        ),
        child: IconButton(
          key: const Key('popi-open-activity'),
          tooltip: AppLocalizations.of(context)!.activities,
          padding: const EdgeInsets.all(6),
          onPressed: () => context.push('/activities'),
          icon: AppSvgIcon.asset(
            'appbar_activity',
            size: 30,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
