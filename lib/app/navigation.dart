import 'package:go_router/go_router.dart';

/// Switches sidebar destinations without retaining the previous page stack.
class AppNavigation {
  const AppNavigation._();

  static void replaceRoot(GoRouter router, String location) {
    router.routerDelegate.navigatorKey.currentState?.popUntil(
      (route) => route.isFirst,
    );
    router.replace(location);
  }
}
