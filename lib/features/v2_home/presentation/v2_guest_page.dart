import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_svg_icon.dart';

/// Signed-out home from Figma 3714:1667.
class V2GuestPage extends StatelessWidget {
  const V2GuestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    void login() => context.push('/login');
    return Scaffold(
      key: const Key('v2-guest-page'),
      backgroundColor: dark ? colors.surface : AppColors.profileBackground,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Align(
                      alignment: const Alignment(0, -.17),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/demo_welcome.png',
                              width: 150,
                              height: 150,
                              cacheWidth: 450,
                              excludeFromSemantics: true,
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'POPi',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              l.guestTagline,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: 216,
                              height: 42,
                              child: FilledButton(
                                key: const Key('v2-guest-login'),
                                onPressed: login,
                                child: Text(
                                  l.guestStartCreating,
                                  style: const TextStyle(fontSize: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Material(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(30),
                      child: InkWell(
                        key: const Key('v2-guest-composer'),
                        borderRadius: BorderRadius.circular(30),
                        onTap: login,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              SizedBox.square(
                                dimension: 40,
                                child: IconButton(
                                  tooltip: l.demoAttachments,
                                  onPressed: login,
                                  style: IconButton.styleFrom(
                                    fixedSize: const Size.square(40),
                                    backgroundColor: colors.primary.withValues(
                                      alpha: .05,
                                    ),
                                  ),
                                  icon: const AppSvgIcon.asset(
                                    'home_composer_add',
                                    size: 16,
                                    color: AppColors.brand,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  l.composerPlaceholder,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Container(
                                width: 40,
                                height: 40,
                                foregroundDecoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.outlineVariant,
                                  ),
                                ),
                                child: IconButton(
                                  tooltip: l.guestVoiceInput,
                                  onPressed: login,
                                  icon: const AppSvgIcon.asset(
                                    'guest_microphone',
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l.aiDisclaimer,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
