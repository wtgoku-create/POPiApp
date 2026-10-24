import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/demo_models.dart';
import 'demo_widgets.dart';

/// Glass chat controls with a centered member title and fixed side anchors.
class DemoChatHeader extends StatelessWidget implements PreferredSizeWidget {
  const DemoChatHeader({
    required this.session,
    required this.onBack,
    required this.onSettings,
    this.toolbarHeight = kToolbarHeight,
    this.desktopLayout = false,
    super.key,
  });

  final DemoSession session;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final double toolbarHeight;
  final bool desktopLayout;

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final memberId = session.members.isNotEmpty
        ? session.members.first
        : session.activeMemberId;
    final resolvedMemberId = memberId.isEmpty ? 'popi' : memberId;
    final configuredName = session.memberNames[resolvedMemberId]?.trim();
    final title = desktopLayout
        ? session.title
        : session.members.length <= 1
        ? configuredName == null || configuredName.isEmpty
              ? demoMemberName(localizations, resolvedMemberId)
              : configuredName
        : localizations.demoBotGroupTitle(session.members.length);

    return AppBar(
      automaticallyImplyLeading: false,
      forceMaterialTransparency: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: toolbarHeight,
      leadingWidth: 56,
      leading: desktopLayout
          ? const SizedBox(width: 56)
          : Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Center(
                child: _HeaderIconButton(
                  buttonKey: const Key('demo-chat-back'),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: onBack,
                  icon: const RotatedBox(
                    quarterTurns: 1,
                    child: DemoIcon('back', size: 40),
                  ),
                ),
              ),
            ),
      title: Tooltip(
        message: title,
        child: _GlassSurface(
          borderRadius: BorderRadius.circular(999),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: const Key('demo-chat-title'),
              borderRadius: BorderRadius.circular(999),
              onTap: onSettings,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: desktopLayout ? 40 : 50),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: desktopLayout ? 6 : 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeaderAvatars(
                        session: session,
                        avatarSize: desktopLayout ? 24 : 30,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: desktopLayout ? 14 : 16,
                            fontWeight: desktopLayout
                                ? FontWeight.w500
                                : FontWeight.w400,
                            height: 1.2,
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
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: _HeaderIconButton(
              buttonKey: const Key('demo-settings'),
              tooltip: localizations.demoSettings,
              onPressed: onSettings,
              icon: const DemoIcon('profile', size: 22),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderAvatars extends StatelessWidget {
  const _HeaderAvatars({required this.session, this.avatarSize = 30});

  final DemoSession session;
  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final source = session.members.isEmpty
        ? [session.activeMemberId.isEmpty ? 'popi' : session.activeMemberId]
        : session.members;
    final members = source.take(3).toList(growable: false);
    final overlapOffset = avatarSize * 17 / 30;

    return SizedBox(
      key: const Key('demo-chat-header-avatars'),
      width: avatarSize + overlapOffset * (members.length - 1),
      height: avatarSize,
      child: Stack(
        children: [
          // Paint from right to left so the leading avatar stays in front.
          for (var index = members.length - 1; index >= 0; index--)
            Positioned(
              left: overlapOffset * index,
              child: DemoAvatar(
                key: ValueKey(
                  'demo-chat-header-avatar-${members[index]}-$index',
                ),
                members: [members[index]],
                size: avatarSize,
                memberAvatars: session.memberAvatars,
                memberColors: session.memberColors,
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.buttonKey,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final Key buttonKey;
  final String tooltip;
  final VoidCallback onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 40,
    child: IconButton(
      key: buttonKey,
      tooltip: tooltip,
      onPressed: onPressed,
      padding: const EdgeInsets.all(2),
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      icon: _GlassSurface(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox.square(dimension: 36, child: Center(child: icon)),
      ),
    ),
  );
}

class _GlassSurface extends StatelessWidget {
  const _GlassSurface({required this.borderRadius, required this.child});

  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final fill = dark
        ? theme.colorScheme.surface.withValues(alpha: .68)
        : Colors.white.withValues(alpha: .50);
    final border = dark
        ? Colors.white.withValues(alpha: .12)
        : Colors.white.withValues(alpha: .72);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .18 : .06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: borderRadius,
              border: Border.all(color: border),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
