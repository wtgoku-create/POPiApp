import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_bot_avatar.dart';

/// Empty conversation content stays above the composer and system keyboard.
class SessionWelcome extends StatelessWidget {
  const SessionWelcome({required this.keyboardVisible, super.key});

  final bool keyboardVisible;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: const Key('popi-home-scroll'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              key: const Key('session-welcome'),
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppBotAvatar(
                  key: const Key('popi-welcome-mascot'),
                  size: keyboardVisible
                      ? math.min(150, math.max(0, constraints.maxHeight - 40))
                      : 150,
                ),
                if (!keyboardVisible) ...[
                  const SizedBox(height: 5),
                  Text(
                    l10n.sessionWelcomeTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    l10n.sessionWelcomeBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.onSurface, fontSize: 18),
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
