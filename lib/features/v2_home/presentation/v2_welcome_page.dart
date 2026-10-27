import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_glass_app_bar.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_menu.dart';
import '../../v2_shared/data/v2_repository.dart';
import '../../v2_shared/domain/v2_models.dart';
import '../../v2_session/presentation/v2_chat_page.dart';
import '../../v2_shared/presentation/widgets/v2_widgets.dart';
import 'widgets/v2_welcome_character.dart';

class V2WelcomePage extends StatelessWidget {
  const V2WelcomePage({required this.repository, super.key});
  final V2Repository repository;
  Future<void> _create(
    BuildContext context,
    String title,
    V2SessionKind kind,
  ) async {
    await v2Perform(context, () async {
      final id = await repository.createSession(title, kind);
      if (context.mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            settings: RouteSettings(name: '/v2/chat', arguments: id),
            builder: (_) => V2ChatPage(repository: repository, sessionId: id),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final options = [
      l.demoStartIp,
      l.demoStartRole,
      l.demoStartIdea,
      l.demoStartChat,
    ];
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final contentWidth = math.min(400.0, MediaQuery.sizeOf(context).width - 40);
    final characterWidth = math.min(184.0, math.max(90.0, contentWidth - 208));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? colors.surface : null,
        gradient: dark
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEDE9FD), v2Background],
              ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppGlassAppBar(
          child: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            leadingWidth: 80,
            leading: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: SizedBox.square(
                  dimension: 40,
                  child: IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const RotatedBox(
                      quarterTurns: 1,
                      child: V2Icon('back', size: 40),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: MediaQuery.paddingOf(context).top + kToolbarHeight,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                              ),
                              child: AppContextMenu(
                                label: l.demoWelcomeTitle,
                                entries: [
                                  AppMenuItem(
                                    label: l.demoReset,
                                    icon: const Icon(Icons.restart_alt),
                                    onSelected: () => _reset(context),
                                  ),
                                ],
                                child: Text(
                                  l.demoWelcomeTitle,
                                  key: const Key('demo-welcome-greeting'),
                                  style: const TextStyle(
                                    fontSize: 30,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  right: 8,
                                  bottom: -81 * characterWidth / 184,
                                  child: SizedBox(
                                    key: const Key('demo-welcome-character'),
                                    width: characterWidth,
                                    height: characterWidth * 222 / 184,
                                    child: const V2WelcomeCharacter(),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: 15,
                                    right: characterWidth + 8,
                                    bottom: 42,
                                  ),
                                  child: Text(
                                    l.demoWelcomeCopy,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      height: 1.4,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          key: const Key('demo-welcome-options'),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: dark
                                ? colors.surfaceContainerLow
                                : Colors.white,
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
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    for (
                                      var i = 0;
                                      i < options.length;
                                      i++
                                    ) ...[
                                      _WelcomeEntry(
                                        index: i,
                                        label: options[i],
                                        onTap: () => _create(
                                          context,
                                          options[i],
                                          i == 0
                                              ? V2SessionKind.project
                                              : i == 2
                                              ? V2SessionKind.workflow
                                              : V2SessionKind.conversation,
                                        ),
                                      ),
                                      if (i < options.length - 1)
                                        const SizedBox(height: 10),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reset(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final yes = await AppDialog.confirm(
      context: context,
      title: l.demoReset,
      description: l.demoResetDescription,
      cancelLabel: l.cancel,
      confirmLabel: l.confirm,
    );
    if (yes == true && context.mounted) {
      await v2Perform(context, repository.reset);
    }
  }
}

class _WelcomeEntry extends StatelessWidget {
  const _WelcomeEntry({
    required this.index,
    required this.label,
    required this.onTap,
  });

  final int index;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(100),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Material(
        color: v2Surface(context),
        child: InkWell(
          key: Key('demo-welcome-entry-$index'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const [
                        Color(0xFFEDE7FD),
                        Color(0xFFFEEEF6),
                        Color(0xFFFFEFDE),
                        Color(0xFFE5FBFA),
                      ][index],
                    ),
                    child: AppSvgIcon.asset(
                      const [
                        'home_start_ip',
                        'home_start_role',
                        'home_start_content',
                        'demo_start_chat',
                      ][index],
                      size: 20,
                      color: index == 2 ? const Color(0xFFFF8D24) : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const SizedBox.square(
                    dimension: 40,
                    child: Center(
                      child: AppSvgIcon.asset('home_welcome_chevron', size: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
