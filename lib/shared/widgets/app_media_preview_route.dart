import 'package:flutter/material.dart';

/// Keeps image and video previews on the same overlay route above the screen.
abstract final class AppMediaPreviewRoute {
  static Future<void> show({
    required BuildContext context,
    required Widget Function(BuildContext, Animation<double>) builder,
  }) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 300),
        reverseTransitionDuration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 220),
        pageBuilder: (context, animation, _) => builder(context, animation),
        transitionsBuilder: (_, __, ___, child) => child,
      ),
    );
  }
}
