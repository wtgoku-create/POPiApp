import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/safe_area_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/popi_membership_entry.dart';
import '../../../shared/widgets/popi_navigation_drawer.dart';
import 'widgets/home_banner_carousel.dart';
import 'widgets/home_creation_welcome.dart';

/// Welcome home and entry points into a creation session.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _drawerOpen = false;

  void _startSession(String prompt) {
    if (ref.read(userProvider) == null) {
      context.push('/login');
      return;
    }
    if (prompt == AppLocalizations.of(context)!.homeStartIp) {
      context.push('/ip-guide');
      return;
    }
    if (prompt == AppLocalizations.of(context)!.homeStartRole) {
      context.push('/role-guide');
      return;
    }
    context.push(
      Uri(path: '/session', queryParameters: {'prompt': prompt}).toString(),
    );
  }

  Widget _blurBehindDrawer(Widget child) => _drawerOpen
      ? ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 6.5, sigmaY: 6.5),
          child: child,
        )
      : child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final safeArea = ref.watch(safeAreaInsetsProvider);
    final user = ref.watch(userProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? colors.surface : null,
        gradient: dark
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEDE9FD), Colors.white],
              ),
      ),
      child: Scaffold(
        key: _scaffoldKey,
        // The app bar already includes the stored status-bar inset.
        primary: false,
        backgroundColor: Colors.transparent,
        drawerScrimColor: const Color(0x33333333),
        drawer: PopiNavigationDrawer(
          onNewProject: () => _startSession(l10n.homeStartIp),
        ),
        onDrawerChanged: (open) => setState(() => _drawerOpen = open),
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(safeArea.top + 56),
          child: Padding(
            padding: EdgeInsets.only(top: safeArea.top),
            child: _blurBehindDrawer(
              AppBar(
                primary: false,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                toolbarHeight: 56,
                leadingWidth: 80,
                leading: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 15),
                    child: SizedBox.square(
                      dimension: 40,
                      child: IconButton(
                        key: const Key('popi-open-navigation'),
                        tooltip: l10n.openNavigation,
                        padding: const EdgeInsets.all(5),
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                        icon: AppSvgIcon.asset(
                          'common_navigation_menu',
                          size: 30,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 15),
                    child: PopiMembershipEntry(
                      points: user?.allCoins ?? 0,
                      showPoints: user != null,
                      label: user == null
                          ? l10n.goToLogin
                          : l10n.upgradeMembership,
                      fontSize: 18,
                      height: 40,
                      onTap: () => context.push(
                        user == null ? '/login' : '/profile/membership',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: _blurBehindDrawer(
          SingleChildScrollView(
            key: const Key('home-welcome-scroll'),
            padding: EdgeInsets.only(top: 12, bottom: safeArea.bottom + 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    const HomeBannerCarousel(),
                    const SizedBox(height: 27),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: HomeCreationWelcome(
                        name: user?.name.trim() ?? '',
                        onStart: _startSession,
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
