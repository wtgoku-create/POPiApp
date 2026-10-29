import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_menu.dart';
import '../../../shared/widgets/app_modal_scope.dart';
import '../../../shared/widgets/app_svg_icon.dart';
import '../../v2_shared/data/v2_repository.dart';
import '../../v2_shared/domain/v2_models.dart';
import '../../v2_assets/presentation/v2_assets_page.dart';
import '../../v2_session/presentation/v2_chat_page.dart';
import 'widgets/v2_create_popi_sheet.dart';
import '../../v2_shared/presentation/widgets/v2_widgets.dart';

class V2HomePage extends StatefulWidget {
  const V2HomePage({
    required this.repository,
    this.routedContent,
    this.routeActive = false,
    this.initialSessionId,
    super.key,
  });
  final V2Repository repository;
  final Widget? routedContent;
  final bool routeActive;
  final String? initialSessionId;
  @override
  State<V2HomePage> createState() => _V2HomePageState();
}

class _V2HomePageState extends State<V2HomePage> {
  final _libraryNavigator = GlobalKey<NavigatorState>();
  final _detailNavigator = GlobalKey<NavigatorState>();
  final _assetsNavigator = GlobalKey<NavigatorState>();
  late final _libraryModals = AppModalObserver(onChanged: _modalsChanged);
  final _detailModals = AppModalObserver();
  final _assetsModals = AppModalObserver();
  late final _detailObserver = _DetailObserver(_detailChanged);
  int _tab = 0;
  bool _bottomVisible = true;
  bool _detailActive = false;
  String? _selectedSessionId;
  String _query = '';
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSessionId case final id?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _open(widget.repository.session(id));
      });
    }
  }

  void _modalsChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _detailChanged(bool active, String? sessionId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          (_detailActive == active && _selectedSessionId == sessionId)) {
        return;
      }
      setState(() {
        _detailActive = active;
        _selectedSessionId = sessionId;
      });
    });
  }

  bool _onScroll(Notification notification) {
    if (notification is ScrollMetricsNotification &&
        notification.depth == 0 &&
        notification.metrics.axis == Axis.vertical &&
        notification.metrics.maxScrollExtent <=
            notification.metrics.minScrollExtent) {
      _showBottom(true);
    } else if (notification is UserScrollNotification &&
        notification.depth == 0 &&
        notification.metrics.axis == Axis.vertical &&
        notification.direction != ScrollDirection.idle) {
      _showBottom(notification.direction == ScrollDirection.forward);
    }
    return false;
  }

  void _showBottom(bool visible) {
    if (visible != _bottomVisible) {
      setState(() => _bottomVisible = visible);
    }
  }

  void _open(V2Session s) {
    _returnHome();
    setState(() {
      _tab = 0;
      _detailActive = true;
      _selectedSessionId = s.id;
    });
    _detailNavigator.currentState!.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        settings: RouteSettings(name: '/v2/chat', arguments: s.id),
        builder: (_) =>
            V2ChatPage(repository: widget.repository, sessionId: s.id),
      ),
      (route) => route.isFirst,
    );
  }

  Future<void> _newConversation(BuildContext sheetContext) async {
    if (_creating) return;
    _creating = true;
    final id = await V2Sheet.show<String>(
      context: sheetContext,
      enableDrag: false,
      builder: (_) => V2CreatePopiSheet(repository: widget.repository),
    );
    _creating = false;
    if (mounted && id != null) _open(widget.repository.session(id));
  }

  void _returnHome() {
    if (widget.routeActive) context.go('/');
  }

  void _profile() {
    if (widget.routeActive) {
      context.go('/profile');
    } else {
      context.push('/profile');
    }
  }

  void _notifications() {
    if (widget.routeActive) {
      context.go('/notifications');
    } else {
      context.push('/notifications');
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final split = constraints.maxWidth >= 840;
      final sidebarWidth = split ? 320.0 : constraints.maxWidth;
      final media = MediaQuery.of(context);

      // Panes keep their parents and state while switching tabs or resizing.
      Widget pane({
        required Key key,
        required double left,
        required double width,
        required bool visible,
        required Widget child,
      }) => Positioned(
        key: key,
        left: left,
        top: 0,
        bottom: 0,
        width: width,
        child: Offstage(
          offstage: !visible,
          child: TickerMode(
            enabled: visible,
            child: ClipRect(
              // Keep backdrop filters inside this pane's compositing surface.
              clipBehavior: split ? Clip.antiAliasWithSaveLayer : Clip.hardEdge,
              child: MediaQuery(
                data: media.copyWith(
                  size: Size(width, constraints.maxHeight),
                  padding: media.padding.copyWith(
                    left: left > 0 ? 0 : media.padding.left,
                    right: split && left == 0 ? 0 : media.padding.right,
                  ),
                  viewPadding: media.viewPadding.copyWith(
                    left: left > 0 ? 0 : media.viewPadding.left,
                    right: split && left == 0 ? 0 : media.viewPadding.right,
                  ),
                ),
                child: AppModalScope(active: visible, child: child),
              ),
            ),
          ),
        ),
      );

      return Stack(
        fit: StackFit.expand,
        children: [
          pane(
            key: const Key('v2-library-pane'),
            left: 0,
            width: sidebarWidth,
            visible:
                split || (!widget.routeActive && _tab == 0 && !_detailActive),
            child: NavigatorPopHandler<void>(
              enabled:
                  split || (!widget.routeActive && _tab == 0 && !_detailActive),
              onPopWithResult: (_) =>
                  _libraryNavigator.currentState!.maybePop(),
              child: Navigator(
                key: _libraryNavigator,
                observers: [_libraryModals],
                onGenerateRoute: (_) =>
                    MaterialPageRoute<void>(builder: _library),
              ),
            ),
          ),
          pane(
            key: const Key('v2-detail-pane'),
            left: split ? sidebarWidth : 0,
            width: constraints.maxWidth - (split ? sidebarWidth : 0),
            visible:
                !widget.routeActive && _tab == 0 && (split || _detailActive),
            child: NavigatorPopHandler<void>(
              enabled:
                  !widget.routeActive &&
                  (_detailActive || _detailModals.hasPopups) &&
                  _tab == 0 &&
                  !_libraryModals.hasPopups,
              onPopWithResult:
                  !widget.routeActive && _tab == 0 && !_libraryModals.hasPopups
                  ? (_) => _detailNavigator.currentState!.maybePop()
                  : null,
              child: Navigator(
                key: _detailNavigator,
                observers: [_detailObserver, _detailModals],
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  settings: const RouteSettings(name: '/'),
                  builder: (context) {
                    final l = AppLocalizations.of(context)!;
                    return V2Scaffold(
                      title: Text(l.demoPopi),
                      child: CustomScrollView(
                        slivers: [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const V2Avatar(size: 96),
                                const SizedBox(height: 20),
                                Text(
                                  l.v2NoConversationSelected,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  onPressed: () => _newConversation(context),
                                  icon: const Icon(Icons.add),
                                  label: Text(l.demoNew),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          pane(
            key: const Key('v2-assets-pane'),
            left: split ? sidebarWidth : 0,
            width: constraints.maxWidth - (split ? sidebarWidth : 0),
            visible: !widget.routeActive && _tab == 1,
            child: NavigatorPopHandler<void>(
              enabled:
                  !widget.routeActive && _tab == 1 && !_libraryModals.hasPopups,
              onPopWithResult:
                  !widget.routeActive && _tab == 1 && !_libraryModals.hasPopups
                  ? (_) => _assetsNavigator.currentState!.maybePop()
                  : null,
              child: Navigator(
                key: _assetsNavigator,
                observers: [_assetsModals],
                pages: [
                  MaterialPage<void>(
                    child: Builder(
                      builder: (context) => _assets(context, split: split),
                    ),
                  ),
                ],
                onDidRemovePage: (_) {},
              ),
            ),
          ),
          if (widget.routedContent != null)
            pane(
              key: const Key('v2-account-pane'),
              left: split ? sidebarWidth : 0,
              width: constraints.maxWidth - (split ? sidebarWidth : 0),
              visible: widget.routeActive,
              child: widget.routedContent!,
            ),
          if (split)
            Positioned(
              left: sidebarWidth - 1,
              top: 0,
              bottom: 0,
              child: VerticalDivider(
                width: 1,
                thickness: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
        ],
      );
    },
  );

  Widget _library(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return V2Scaffold(
      floatingBottom: true,
      floatingBottomVisible: _bottomVisible,
      title: Text(l.demoConversations),
      leading: IconButton(
        tooltip: l.demoProfile,
        padding: EdgeInsets.zero,
        onPressed: _profile,
        icon: const V2Avatar(size: 40),
      ),
      actionsSpacing: 10,
      actions: [
        IconButton(
          key: const Key('v2-notifications'),
          tooltip: l.notifications,
          padding: EdgeInsets.zero,
          onPressed: _notifications,
          icon: const AppSvgIcon.asset('v2_notifications', size: 40),
        ),
        IconButton(
          key: const Key('demo-create'),
          tooltip: l.demoNew,
          onPressed: () => _newConversation(context),
          icon: const V2Icon('plus', color: AppColors.brand),
        ),
      ],
      bottom: _bottomTabs(context),
      child: _conversations(context),
    );
  }

  Widget _assets(BuildContext context, {required bool split}) {
    final l = AppLocalizations.of(context)!;
    return V2Scaffold(
      contentMaxWidth: 1200,
      floatingBottom: !split,
      floatingBottomVisible: _bottomVisible,
      title: Text(l.demoAssets),
      leading: split
          ? null
          : IconButton(
              tooltip: l.demoProfile,
              padding: EdgeInsets.zero,
              onPressed: _profile,
              icon: const V2Avatar(size: 40),
            ),
      actions: [
        IconButton(
          key: const Key('demo-upload'),
          tooltip: l.demoUpload,
          onPressed: () => showV2Import(context, widget.repository),
          icon: const V2Icon('upload', size: 24, color: AppColors.brand),
        ),
      ],
      bottom: split ? null : _bottomTabs(context),
      child: NotificationListener<Notification>(
        onNotification: _onScroll,
        child: V2AssetsView(repository: widget.repository),
      ),
    );
  }

  Widget _bottomTabs(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Center(
          heightFactor: 1,
          child: ClipRRect(
            key: const Key('demo-bottom-tabs'),
            borderRadius: BorderRadius.circular(27),
            child: BackdropFilter(
              key: const Key('demo-bottom-tabs-glass'),
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                width: 144,
                height: 54,
                padding: const EdgeInsets.all(5),
                color: v2Surface(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < 2; i++)
                      Semantics(
                        selected: _tab == i,
                        child: Container(
                          decoration: ShapeDecoration(
                            color: _tab == i ? v2Tint : Colors.transparent,
                            shape: const CircleBorder(),
                          ),
                          child: IconButton(
                            key: Key('demo-tab-$i'),
                            tooltip: i == 0
                                ? l.demoConversations
                                : l.demoAssets,
                            onPressed: () {
                              _returnHome();
                              setState(() => _tab = i);
                            },
                            icon: V2Icon(
                              i == 0 ? 'chat' : 'folder',
                              color: _tab == i
                                  ? AppColors.brand
                                  : AppColors.textSecondary,
                            ),
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

  Widget _conversations(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final horizontalPadding = v2HorizontalPagePadding(context);
    return NotificationListener<Notification>(
      onNotification: _onScroll,
      child: Column(
        children: [
          Padding(
            padding: horizontalPadding.copyWith(top: 10, bottom: 10),
            child: V2Search(
              hint: l.demoSearchHistory,
              onChanged: (q) => setState(() {
                _query = q;
                _bottomVisible = true;
              }),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: widget.repository,
              builder: (context, _) {
                final sessions = widget.repository.sessions
                    .where(
                      (s) => '${s.title} ${s.messages.lastOrNull?.text ?? ''}'
                          .toLowerCase()
                          .contains(_query.trim().toLowerCase()),
                    )
                    .toList();
                if (sessions.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isEmpty
                          ? l.demoEmptyConversations
                          : l.demoNoResults,
                    ),
                  );
                }
                return ListView.separated(
                  key: const PageStorageKey('demo-conversations'),
                  padding: horizontalPadding.copyWith(bottom: 140),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final s = sessions[index];
                    return AppContextMenu(
                      key: ValueKey(s.id),
                      label: s.title,
                      entries: [
                        AppMenuItem(
                          label: l.renameProjectItem,
                          icon: const Icon(Icons.edit_outlined),
                          onSelected: () => v2EditText(
                            context,
                            title: l.demoRename,
                            useRootNavigator: true,
                            label: l.demoSessionName,
                            value: s.title,
                            onSave: (title) => widget.repository.updateSession(
                              s.id,
                              (s) => s.copyWith(title: title),
                            ),
                          ),
                        ),
                        AppMenuItem(
                          label: l.delete,
                          destructive: true,
                          icon: const Icon(Icons.delete_outline),
                          onSelected: () async {
                            final yes = await AppDialog.confirm(
                              context: context,
                              title: l.delete,
                              useRootNavigator: true,
                              description: l.demoDeleteDescription,
                              cancelLabel: l.cancel,
                              confirmLabel: l.confirm,
                              destructive: true,
                            );
                            if (yes == true && context.mounted) {
                              if (_selectedSessionId == s.id) {
                                _detailNavigator.currentState!.popUntil(
                                  (route) => route.isFirst,
                                );
                              }
                              await v2Perform(
                                context,
                                () => widget.repository.deleteSession(s.id),
                              );
                            }
                          },
                        ),
                      ],
                      child: Material(
                        color:
                            (_selectedSessionId == null
                                ? index == 0 && _query.isEmpty
                                : s.id == _selectedSessionId)
                            ? v2Tint
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _open(s),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
                            child: Row(
                              children: [
                                V2Avatar(
                                  members: s.members,
                                  memberAvatars: s.memberAvatars,
                                  memberColors: s.memberColors,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    s.title,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                if (s.id != 'campus') ...[
                                                  const SizedBox(width: 5),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 9,
                                                          vertical: 3,
                                                        ),
                                                    decoration:
                                                        const ShapeDecoration(
                                                          color: v2Tint,
                                                          shape:
                                                              StadiumBorder(),
                                                        ),
                                                    child: Text(
                                                      switch (s.kind) {
                                                        V2SessionKind
                                                            .conversation =>
                                                          l.demoConversation,
                                                        V2SessionKind.project =>
                                                          l.demoProject,
                                                        V2SessionKind
                                                            .workflow =>
                                                          l.demoWorkflow,
                                                      },
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            s.kind ==
                                                                V2SessionKind
                                                                    .conversation
                                                            ? AppColors
                                                                  .textPrimary
                                                            : AppColors.brand,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            s.time.isEmpty ? l.demoNow : s.time,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textTertiary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              s.messages.lastOrNull?.text
                                                      .replaceAll('\n', ' ') ??
                                                  l.demoGreetingDetail,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                          if (s.unread > 0)
                                            Container(
                                              width: 20,
                                              height: 20,
                                              alignment: Alignment.center,
                                              decoration: const BoxDecoration(
                                                color: AppColors.brand,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                '${s.unread}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(height: 5),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailObserver extends NavigatorObserver {
  _DetailObserver(this.onChanged);

  final void Function(bool active, String? sessionId) onChanged;
  final _routes = <Route<dynamic>>[];

  void _notify() => onChanged(
    _routes.length > 1,
    _routes
            .where((route) => route.settings.name == '/v2/chat')
            .lastOrNull
            ?.settings
            .arguments
        as String?,
  );

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute) return;
    _routes.add(route);
    _notify();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute) return;
    _routes.remove(route);
    _notify();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute) return;
    _routes.remove(route);
    _notify();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute is! PageRoute || newRoute is! PageRoute) return;
    final index = _routes.indexOf(oldRoute);
    if (index >= 0) _routes[index] = newRoute;
    _notify();
  }
}
