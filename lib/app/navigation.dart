import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Switches sidebar destinations while retaining home as the base route.
class AppNavigation {
  const AppNavigation._();

  static void replaceRoot(GoRouter router, String location) {
    router.routerDelegate.navigatorKey.currentState?.popUntil(
      (route) => route.settings is Page || route.isFirst,
    );
    router.go(location);
  }
}
