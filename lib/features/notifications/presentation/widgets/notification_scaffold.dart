import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_svg_icon.dart';

/// Shared framing for the inbox and its full notification content.
class NotificationScaffold extends StatelessWidget {
  const NotificationScaffold({
    required this.title,
    required this.child,
    super.key,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFF5F4FA)
        : scheme.surface;
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(height: math.max(52, MediaQuery.paddingOf(context).top)),
            SizedBox(
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 64),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: AppTypeSizes.pageTitle,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 15,
                    child: IconButton(
                      key: const Key('notification-back'),
                      tooltip: AppLocalizations.of(context)!.back,
                      onPressed: () {
                        final navigator = Navigator.of(context);
                        if (navigator.canPop()) {
                          navigator.pop();
                        } else {
                          context.go('/');
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ),
                      icon: RotatedBox(
                        quarterTurns: 1,
                        child: AppSvgIcon.asset(
                          'ip_guide_back',
                          size: 40,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
