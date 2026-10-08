import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../providers/safe_area_provider.dart';
import '../providers/user_provider.dart';
import 'app_svg_icon.dart';
import '../../features/projects/domain/project.dart';
import 'popi_drawer_projects.dart';

class PopiNavigationDrawer extends ConsumerStatefulWidget {
  const PopiNavigationDrawer({
    this.onNewProject,
    this.onOpenConversation,
    super.key,
  });

  final VoidCallback? onNewProject;
  final ValueChanged<ProjectSessionSelection>? onOpenConversation;

  @override
  ConsumerState<PopiNavigationDrawer> createState() =>
      _PopiNavigationDrawerState();
}

class _PopiNavigationDrawerState extends ConsumerState<PopiNavigationDrawer> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final safeArea = ref.watch(safeAreaInsetsProvider);
    final topInset = math.max(
      math.max(safeArea.top, MediaQuery.viewPaddingOf(context).top) + 8,
      53.0,
    );
    final colorScheme = Theme.of(context).colorScheme;
    final isLoggedIn = ref.watch(userProvider) != null;
    final route = GoRouter.maybeOf(context) == null
        ? '/'
        : GoRouterState.of(context).uri.path;

    return Container(
      key: const Key('popi-navigation-drawer'),
      width: math.min(360, MediaQuery.sizeOf(context).width * .9),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(30)),
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            offset: Offset(6, 0),
            blurRadius: 30,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          topInset,
          20,
          math.max(20, safeArea.bottom),
        ),
        child: Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      key: const Key('drawer-new-project'),
                      onPressed: () {
                        if (!isLoggedIn) {
                          _openRoute(context, '/login');
                        } else if (widget.onNewProject != null) {
                          Navigator.pop(context);
                          widget.onNewProject!();
                        } else {
                          _openRoute(context, '/session');
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.only(left: 20, right: 10),
                        foregroundColor: colorScheme.onSurface,
                        side: BorderSide(color: colorScheme.outline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.newIpProject,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          SizedBox.square(
                            dimension: 30,
                            child: Center(
                              child: AppSvgIcon.asset(
                                'home_drawer_project_add',
                                size: 14,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: [
                      _NavigationItem(
                        key: const Key('drawer-nav-ip-accounts'),
                        iconAsset: 'home_drawer_nav-ip-account',
                        label: l10n.myIpAccounts,
                        selected: route == '/ip-accounts',
                        onTap: () => _openProtectedRoute(
                          context,
                          isLoggedIn: isLoggedIn,
                          route: '/ip-accounts',
                        ),
                      ),
                      _NavigationItem(
                        key: const Key('drawer-nav-role'),
                        iconAsset: 'home_drawer_nav-role',
                        iconWidth: 18.4994,
                        iconHeight: 20.716,
                        flipIconVertically: true,
                        label: l10n.roles,
                        onTap: () => _openProtectedRoute(
                          context,
                          isLoggedIn: isLoggedIn,
                          route: '/assets?section=roles',
                        ),
                      ),
                      _NavigationItem(
                        key: const Key('drawer-nav-assets'),
                        iconAsset: 'home_drawer_nav-asset',
                        label: l10n.assets,
                        selected: route == '/assets',
                        onTap: () => _openProtectedRoute(
                          context,
                          isLoggedIn: isLoggedIn,
                          route: '/assets',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 9),
                  Expanded(
                    child: PopiDrawerProjects(
                      onOpenConversation: (selection) {
                        if (!isLoggedIn) {
                          _openRoute(context, '/login');
                        } else if (widget.onOpenConversation != null) {
                          Navigator.pop(context);
                          widget.onOpenConversation!(selection);
                        } else {
                          _showPending(context, selection.session.title);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _DrawerFooter(
              onNotification: () => isLoggedIn
                  ? _showPending(context, l10n.notifications)
                  : _openRoute(context, '/login'),
              onSettings: () => _openProtectedRoute(
                context,
                isLoggedIn: isLoggedIn,
                route: '/profile',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openRoute(BuildContext context, String route) {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push(route);
  }

  void _openProtectedRoute(
    BuildContext context, {
    required bool isLoggedIn,
    required String route,
  }) {
    _openRoute(context, isLoggedIn ? route : '/login');
  }

  void _showPending(BuildContext context, String label) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(label)));
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.iconAsset,
    required this.label,
    required this.onTap,
    this.iconWidth = 30,
    this.iconHeight = 30,
    this.flipIconVertically = false,
    this.selected = false,
    super.key,
  });

  final String iconAsset;
  final double iconWidth;
  final double iconHeight;
  final bool flipIconVertically;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = selected ? colorScheme.primary : colorScheme.onSurface;
    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: 0.05)
          : colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return colorScheme.primary.withValues(alpha: .12);
          }
          return Colors.transparent;
        }),
        child: SizedBox(
          height: 50,
          child: Padding(
            padding: const EdgeInsets.only(left: 10, right: 30),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 30,
                  child: Center(
                    child: Transform.flip(
                      flipY: flipIconVertically,
                      child: SizedBox(
                        width: iconWidth,
                        height: iconHeight,
                        child: AppSvgIcon.asset(iconAsset, color: color),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerFooter extends ConsumerWidget {
  const _DrawerFooter({required this.onNotification, required this.onSettings});

  final VoidCallback onNotification;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(userProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final displayName = user?.name.isNotEmpty == true ? user!.name : '--';
    final displayId = user?.code.isNotEmpty == true
        ? user!.code
        : user?.id ?? '--';

    return SizedBox(
      height: 47,
      child: Row(
        children: [
          ClipOval(
            child: user?.avatarUrl?.isNotEmpty == true
                ? Image.network(
                    user!.avatarUrl!,
                    width: 47,
                    height: 47,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _defaultAvatar(),
                  )
                : _defaultAvatar(),
          ),
          const SizedBox(width: 10),
          Expanded(
            key: const Key('drawer-user-summary'),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 22,
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 22 / 18,
                    ),
                  ),
                ),
                SizedBox(height: 5),
                SizedBox(
                  height: 15,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: Text(
                          displayId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Image(
                        image: AssetImage('assets/icons/common_user_badge.png'),
                        width: 15,
                        height: 15,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox.square(
            dimension: 40,
            child: IconButton(
              key: const Key('drawer-notification-button'),
              tooltip: l10n.notifications,
              padding: const EdgeInsets.all(5),
              onPressed: onNotification,
              icon: AppSvgIcon.asset(
                'home_drawer_notification',
                size: 30,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox.square(
            dimension: 40,
            child: IconButton(
              key: const Key('drawer-profile-button'),
              tooltip: l10n.profileSettings,
              padding: const EdgeInsets.all(5),
              onPressed: onSettings,
              icon: AppSvgIcon.asset(
                'home_drawer_profile',
                size: 30,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultAvatar() => Image.asset(
    'assets/icons/common_user_avatar.png',
    width: 47,
    height: 47,
    fit: BoxFit.cover,
  );
}
