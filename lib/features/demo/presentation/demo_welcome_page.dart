import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_menu.dart';
import '../data/demo_repository.dart';
import '../domain/demo_models.dart';
import 'widgets/demo_widgets.dart';
import 'widgets/demo_welcome_character.dart';

typedef DemoCreateIntent = ({String title, DemoSessionKind kind});

class DemoWelcomePage extends StatelessWidget {
  const DemoWelcomePage({required this.repository, super.key});
  final DemoRepository repository;
  void _select(BuildContext context, String title, DemoSessionKind kind) =>
      Navigator.of(context).pop<DemoCreateIntent>((title: title, kind: kind));

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
    final contentWidth = math.min(400.0, MediaQuery.sizeOf(context).width - 32);
    final characterWidth = math.min(184.0, math.max(90.0, contentWidth - 208));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? colors.surface : null,
        gradient: dark
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEDE9FD), demoBackground],
              ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          leadingWidth: 70,
          leading: Padding(
            padding: const EdgeInsets.only(left: 15),
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              padding: const EdgeInsets.all(5),
              onPressed: () => Navigator.of(context).pop(),
              icon: const RotatedBox(
                quarterTurns: 1,
                child: DemoIcon('back', size: 40),
              ),
            ),
          ),
        ),
        body: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  MediaQuery.paddingOf(context).top + kToolbarHeight,
                  16,
                  20,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 108),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
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
                                      child: const DemoWelcomeCharacter(),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: 15,
                                      right: characterWidth + 8,
                                      bottom: 9,
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
                                  padding: const EdgeInsets.all(14),
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
                                          onTap: () => _select(
                                            context,
                                            options[i],
                                            i == 0
                                                ? DemoSessionKind.project
                                                : i == 2
                                                ? DemoSessionKind.workflow
                                                : DemoSessionKind.conversation,
                                          ),
                                        ),
                                        if (i < options.length - 1)
                                          const SizedBox(height: 6),
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
      await demoPerform(context, repository.reset);
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
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 360;
    final iconSize = compact ? 36.0 : 40.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Material(
          color: demoSurface(context),
          child: InkWell(
            key: Key('demo-welcome-entry-$index'),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 54),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 10,
                  vertical: compact ? 9 : 7,
                ),
                child: Row(
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
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
                    SizedBox(width: compact ? 8 : 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 15 : 16,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? 4 : 10),
                    SizedBox.square(
                      dimension: compact ? 24 : 40,
                      child: const Center(
                        child: AppSvgIcon.asset(
                          'home_welcome_chevron',
                          size: 13,
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
    );
  }
}
