import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/providers/safe_area_provider.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/widgets/app_sheet.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/popi_membership_entry.dart';
import '../../../shared/widgets/popi_navigation_drawer.dart';
import '../../assets/domain/library_role.dart';
import '../../assets/presentation/role_detail_page.dart';
import '../data/role_guide_examples.dart';
import '../domain/role_guide_draft.dart';
import 'widgets/role_generation_sheet.dart';
import 'widgets/role_guide_controls.dart';
import 'widgets/role_guide_picker.dart';
import 'widgets/role_guide_summary.dart';

/// Character selection, casting, story selection, and video configuration.
class RoleGuidePage extends ConsumerStatefulWidget {
  const RoleGuidePage({super.key});

  @override
  ConsumerState<RoleGuidePage> createState() => _RoleGuidePageState();
}

class _RoleGuidePageState extends ConsumerState<RoleGuidePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _scroll = ScrollController();
  final _draft = RoleGuideDraft();
  String _category = 'official';
  bool _drawerOpen = false;
  bool _sheetOpen = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _step(RoleGuideStep step) {
    setState(() => _draft.step = step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _back() {
    if (_draft.step != RoleGuideStep.roles) {
      _step(RoleGuideStep.values[_draft.step.index - 1]);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _toggleRole(LibraryRole role) {
    final changed = _draft.toggleRole(role);
    if (changed) {
      setState(() {});
    } else {
      AppToast.info(context, AppLocalizations.of(context)!.roleProjectLimit);
    }
  }

  void _toggleCast(LibraryRole role) {
    if (_draft.toggleCast(role)) {
      setState(() {});
    } else {
      AppToast.info(context, AppLocalizations.of(context)!.roleCastLimit);
    }
  }

  bool _startProject() {
    if (!_draft.startProject()) {
      AppToast.info(
        context,
        AppLocalizations.of(context)!.roleSelectProjectFirst,
      );
      return false;
    }
    _step(RoleGuideStep.cast);
    return true;
  }

  void _matchStories() {
    if (!_draft.matchStories()) {
      AppToast.info(context, AppLocalizations.of(context)!.roleSelectCastFirst);
      return;
    }
    _step(RoleGuideStep.story);
  }

  Future<void> _details(LibraryRole role) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => RoleDetailPage(
          role: role,
          category: role.canEdit ? 'personal' : 'official',
          onRoleUpdated: (updated) {
            if (!mounted) return;
            setState(() => _draft.updateRole(updated));
          },
        ),
      ),
    );
  }

  void _createRole() => context.push(
    Uri(
      path: '/session',
      queryParameters: {
        'prompt': AppLocalizations.of(context)!.createNewRolePrompt,
      },
    ).toString(),
  );

  Future<void> _library() async {
    setState(() => _sheetOpen = true);
    try {
      await AppSheet.show<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: false,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        barrierColor: const Color(0x22000000),
        builder: (sheetContext) => DraggableScrollableSheet(
          initialChildSize: .845,
          minChildSize: .5,
          maxChildSize: .96,
          expand: false,
          builder: (context, controller) => Material(
            key: const Key('role-guide-library-sheet'),
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(44)),
            clipBehavior: Clip.antiAlias,
            child: StatefulBuilder(
              builder: (context, updateSheet) {
                final l10n = AppLocalizations.of(context)!;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Text(
                        l10n.roleLibrary,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: controller,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: RoleGuidePicker(
                          fullLibrary: true,
                          initialCategory: _category,
                          selected: () => _draft.roles,
                          onToggle: (role) {
                            _toggleRole(role);
                            updateSheet(() {});
                          },
                          onDetails: _details,
                          onCategoryChanged: (category) =>
                              setState(() => _category = category),
                          onCreate: () {
                            Navigator.of(sheetContext).pop();
                            _createRole();
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        15,
                        20,
                        math.max(20, MediaQuery.paddingOf(context).bottom),
                      ),
                      child: RoleGuideAction(
                        key: const Key('role-library-create-project'),
                        label: l10n.roleCreateProject,
                        count: _draft.roles.length,
                        onPressed: () {
                          if (_startProject()) Navigator.of(sheetContext).pop();
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sheetOpen = false);
    }
  }

  Future<void> _configure() async {
    setState(() => _sheetOpen = true);
    try {
      final settings = await AppSheet.show<RoleGenerationSettings>(
        context: context,
        isScrollControlled: true,
        useSafeArea: false,
        showDragHandle: false,
        backgroundColor: Colors.transparent,
        barrierColor: const Color(0x22000000),
        builder: (_) => RoleGenerationSheet(initialSettings: _draft.settings),
      );
      if (settings != null && mounted) {
        setState(() => _draft.settings = settings);
      }
    } finally {
      if (mounted) setState(() => _sheetOpen = false);
    }
  }

  void _produce() {
    final l10n = AppLocalizations.of(context)!;
    final settings = _draft.settings;
    if (settings == null) {
      AppToast.info(context, l10n.roleChooseParametersFirst);
      _configure();
      return;
    }
    final story = roleGuideStories(l10n, _draft.storyBatch)[_draft.storyIndex];
    String roles(List<LibraryRole> items) =>
        items.map((role) => '${role.title} [${role.id}]').join(', ');
    final prompt = l10n.roleVideoPlanPrompt(
      l10n.roleProjectName(_draft.roles.first.title),
      roles(_draft.roles),
      roles(_draft.cast),
      story.title,
      story.summary,
      settings.model.label,
      '${settings.videoResolution}P / ${settings.videoRatio.label}',
      '${settings.imageResolution}P / ${settings.imageRatio.label}',
      settings.quantity,
    );
    context.push(
      Uri(path: '/session', queryParameters: {'prompt': prompt}).toString(),
    );
  }

  Widget _blur(Widget child) => _drawerOpen || _sheetOpen
      ? ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 6.5, sigmaY: 6.5),
          child: child,
        )
      : child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final safeArea = ref.watch(safeAreaInsetsProvider);
    final user = ref.watch(userProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (title, description) = switch (_draft.step) {
      RoleGuideStep.roles => (l10n.roleGuideTitle, l10n.roleGuideDescription),
      RoleGuideStep.cast => (l10n.roleCastTitle, l10n.roleCastDescription),
      RoleGuideStep.story => (l10n.roleTopicTitle, l10n.roleTopicDescription),
      RoleGuideStep.production => (
        l10n.roleProductionTitle,
        l10n.roleProductionDescription,
      ),
    };

    return PopScope(
      canPop: _draft.step == RoleGuideStep.roles,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: DecoratedBox(
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
          drawer: const PopiNavigationDrawer(),
          onDrawerChanged: (open) => setState(() => _drawerOpen = open),
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(safeArea.top + 56),
            child: Padding(
              padding: EdgeInsets.only(top: safeArea.top),
              child: _blur(
                AppBar(
                  primary: false,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  toolbarHeight: 56,
                  leadingWidth: 60,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 15),
                    child: IconButton(
                      key: const Key('role-guide-menu'),
                      tooltip: l10n.openNavigation,
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                      padding: const EdgeInsets.all(5),
                      icon: AppSvgIcon.asset(
                        'common_navigation_menu',
                        size: 30,
                        color: colors.onSurface,
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
                        fontSize: MediaQuery.sizeOf(context).width < 380
                            ? 14
                            : 18,
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
          body: _blur(
            SingleChildScrollView(
              key: const Key('role-guide-scroll'),
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(20, 10, 20, safeArea.bottom + 30),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _RoleGuideHeader(
                        title: title,
                        description: description,
                        reading: _draft.step.index >= 2,
                      ),
                      Container(
                        key: const Key('role-guide-panel'),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: _content(l10n),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(AppLocalizations l10n) {
    if (_draft.step == RoleGuideStep.roles) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RoleGuidePicker(
            initialCategory: _category,
            selected: () => _draft.roles,
            onToggle: _toggleRole,
            onDetails: _details,
            onCreate: _createRole,
            onCategoryChanged: (category) =>
                setState(() => _category = category),
            onMore: _library,
          ),
          const SizedBox(height: 20),
          RoleGuideAction(
            key: const Key('role-guide-create-project'),
            label: l10n.roleCreateProject,
            count: _draft.roles.length,
            onPressed: _startProject,
          ),
        ],
      );
    }
    if (_draft.step == RoleGuideStep.cast) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RoleProjectSummary(roles: _draft.roles),
          const SizedBox(height: 20),
          RoleGuideGrid(
            roles: _draft.roles,
            selected: _draft.cast,
            onToggle: _toggleCast,
            onDetails: _details,
          ),
          const SizedBox(height: 20),
          RoleGuideAction(
            key: const Key('role-guide-confirm-cast'),
            label: l10n.roleChooseCast,
            count: _draft.cast.length,
            onPressed: _matchStories,
          ),
        ],
      );
    }
    final production = _draft.step == RoleGuideStep.production;
    final stories = roleGuideStories(l10n, _draft.storyBatch);
    final story = stories[_draft.storyIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RoleProjectSummary(roles: _draft.roles),
        const SizedBox(height: 20),
        RoleCastSummary(
          cast: _draft.cast,
          onEdit: () => _step(RoleGuideStep.cast),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                story.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!production) ...[
              _storyArrow(l10n.rolePreviousStory, -1, stories.length),
              _storyArrow(l10n.roleNextStory, 1, stories.length),
            ],
          ],
        ),
        const SizedBox(height: 20),
        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
        const SizedBox(height: 20),
        if (production)
          Text(
            l10n.roleStoryOverview,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.375,
            ),
          ),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: production ? 154 : 176),
          child: Text(
            story.summary,
            style: const TextStyle(fontSize: 16, height: 1.375),
          ),
        ),
        const SizedBox(height: 20),
        if (production) ...[
          TextButton(
            key: const Key('role-guide-configure'),
            onPressed: _configure,
            style: TextButton.styleFrom(
              backgroundColor: roleGuideTint(context),
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: const StadiumBorder(),
            ),
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 24,
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 1,
                      child: SizedBox(
                        width: 19.2,
                        height: 17.4,
                        child: AppSvgIcon.asset('role_guide_model'),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _draft.settings == null
                        ? l10n.roleModelPending
                        : '${_draft.settings!.model.label} / ${_draft.settings!.videoResolution}P / ${_draft.settings!.videoRatio.label}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 8),
                const RotatedBox(
                  quarterTurns: 1,
                  child: SizedBox(
                    width: 6,
                    height: 12,
                    child: AppSvgIcon.asset(
                      'role_guide_chevron',
                      color: AppColors.brand,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.roleEstimatedPoints(675 * (_draft.settings?.quantity ?? 1)),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 20),
        ],
        RoleGuideAction(
          key: Key(
            production ? 'role-guide-produce' : 'role-guide-choose-story',
          ),
          label: l10n.roleChooseStory,
          onPressed: production
              ? _produce
              : () => _step(RoleGuideStep.production),
        ),
        const SizedBox(height: 10),
        RoleGuideAction(
          key: const Key('role-guide-refresh-stories'),
          label: l10n.roleRefreshStories,
          secondary: true,
          showArrow: false,
          onPressed: () {
            _draft.refreshStories();
            _step(RoleGuideStep.story);
          },
        ),
      ],
    );
  }

  Widget _storyArrow(String tooltip, int direction, int count) {
    final target = _draft.storyIndex + direction;
    return SizedBox.square(
      dimension: 26,
      child: IconButton(
        key: Key(
          direction < 0 ? 'role-guide-previous-story' : 'role-guide-next-story',
        ),
        tooltip: tooltip,
        onPressed: target < 0 || target >= count
            ? null
            : () => setState(() => _draft.storyIndex = target),
        padding: const EdgeInsets.all(8),
        icon: RotatedBox(
          quarterTurns: direction < 0 ? 2 : 0,
          child: SizedBox(
            width: 6,
            height: 12,
            child: AppSvgIcon.asset(
              'role_guide_chevron',
              color: target < 0 || target >= count
                  ? Theme.of(context).disabledColor
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleGuideHeader extends StatelessWidget {
  const _RoleGuideHeader({
    required this.title,
    required this.description,
    required this.reading,
  });
  final String title;
  final String description;
  final bool reading;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scaler = MediaQuery.textScalerOf(context);
      const titleStyle = TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );
      const descriptionStyle = TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );
      double measure(String text, TextStyle style, double width) =>
          (TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: scaler,
          )..layout(maxWidth: width)).height;
      final titleHeight = measure(title, titleStyle, constraints.maxWidth - 30);
      final artworkWidth = reading
          ? math.min(136.0, constraints.maxWidth * .34)
          : math.min(105.0, constraints.maxWidth * .30);
      final artworkRight = constraints.maxWidth < 360
          ? 12.0
          : reading
          ? 30.0
          : 48.0;
      final descriptionWidth =
          constraints.maxWidth - artworkWidth - artworkRight - 25;
      final descriptionTop = math.max(62.0, titleHeight + 16);
      final height = math.max(
        154.0,
        descriptionTop +
            measure(description, descriptionStyle, descriptionWidth) +
            30,
      );
      return SizedBox(
        height: height,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned(
                right: artworkRight,
                top: titleHeight > 60 ? titleHeight + 8 : 29,
                child: Image.asset(
                  reading
                      ? 'assets/images/role_guide_story_character.png'
                      : 'assets/images/role_guide_select_character.png',
                  width: artworkWidth,
                  height: reading ? 140 : 155,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
              Positioned(
                left: 15,
                right: 15,
                top: 0,
                child: Text(title, style: titleStyle),
              ),
              Positioned(
                left: 15,
                top: descriptionTop,
                width: descriptionWidth,
                child: Text(description, style: descriptionStyle),
              ),
            ],
          ),
        ),
      );
    },
  );
}
