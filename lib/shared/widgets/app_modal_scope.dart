import 'package:flutter/material.dart';

import '../../core/platform/app_platform.dart';

/// Owns native transient routes in panes whose hidden pages stay mounted.
class AppModalScope extends StatefulWidget {
  const AppModalScope({required this.active, required this.child, super.key});

  final bool active;
  final Widget child;

  /// Web overlays belong to the app window, independently of retained panes.
  static bool get useGlobalOverlays => AppPlatform.current.isWeb;

  static NavigatorState navigatorOf(
    BuildContext context, {
    bool useRootNavigator = false,
  }) => Navigator.of(
    context,
    rootNavigator: useGlobalOverlays || useRootNavigator,
  );

  static bool isActiveOf(BuildContext context) =>
      useGlobalOverlays ||
      (context.dependOnInheritedWidgetOfExactType<_ModalScope>()?.active ??
          true);

  /// Native overlays also close when the source route is removed externally.
  static void bind(BuildContext context, Route<dynamic> route) {
    if (useGlobalOverlays) return;
    final scope = context.getInheritedWidgetOfExactType<_ModalScope>()?.state;
    scope?._routes.add(route);
    route.popped.whenComplete(() => scope?._routes.remove(route));
    if (scope != null && !scope.widget.active) _dismiss([route]);

    final owner = ModalRoute.of(context);
    if (owner == null) return;
    Future.any([
      owner.popped.then((_) => true),
      route.popped.then((_) => false),
    ]).then((ownerRemoved) {
      if (ownerRemoved) _dismiss([route]);
    });
  }

  static void _dismiss(Iterable<Route<dynamic>> routes) {
    final pending = routes.toList().reversed.toList();
    if (pending.isEmpty) return;
    // Navigator notifications and pane visibility updates can occur mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final route in pending) {
        final navigator = route.navigator;
        if (navigator != null && navigator.mounted && route.isActive) {
          navigator.removeRoute(route);
        }
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  State<AppModalScope> createState() => _AppModalScopeState();
}

class _AppModalScopeState extends State<AppModalScope> {
  final _routes = <Route<dynamic>>{};

  @override
  void didUpdateWidget(AppModalScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) AppModalScope._dismiss(_routes);
  }

  @override
  void dispose() {
    AppModalScope._dismiss(_routes);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ModalScope(state: this, active: widget.active, child: widget.child);
}

class _ModalScope extends InheritedWidget {
  const _ModalScope({
    required this.state,
    required this.active,
    required super.child,
  });

  final _AppModalScopeState state;
  final bool active;

  @override
  bool updateShouldNotify(_ModalScope oldWidget) => active != oldWidget.active;
}

/// Tracks popups, with source-page lifecycle dismissal on native platforms.
class AppModalObserver extends NavigatorObserver {
  AppModalObserver({this.onChanged});

  final VoidCallback? onChanged;
  final _owners = <Route<dynamic>, Route<dynamic>?>{};

  bool get hasPopups => _owners.keys.any((route) => route.isActive);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) {
      _owners[route] = AppModalScope.useGlobalOverlays ? null : previousRoute;
      onChanged?.call();
    } else if (route is PageRoute && !AppModalScope.useGlobalOverlays) {
      AppModalScope._dismiss(_owners.keys);
    }
  }

  void _removed(Route<dynamic> route) {
    final removed = <Route<dynamic>>{route};
    // Include sheets/dialogs opened by another transient route.
    for (final entry in _owners.entries) {
      if (removed.contains(entry.value)) removed.add(entry.key);
    }
    AppModalScope._dismiss(removed.where((item) => item != route));
    final wasPopup = _owners.containsKey(route);
    _owners.remove(route);
    if (wasPopup) onChanged?.call();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _removed(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _removed(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _removed(oldRoute);
    if (newRoute is PageRoute && !AppModalScope.useGlobalOverlays) {
      AppModalScope._dismiss(_owners.keys);
    }
  }
}
