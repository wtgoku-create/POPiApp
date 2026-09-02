import 'package:flutter/material.dart';

class AppSheet {
  const AppSheet._();

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool useSafeArea = true,
    bool isScrollControlled = false,
    bool isDismissible = true,
    bool enableDrag = true,
    bool showDragHandle = true,
    Color? backgroundColor,
    Color? barrierColor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: useSafeArea,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      showDragHandle: showDragHandle,
      backgroundColor: backgroundColor,
      barrierColor: barrierColor,
      builder: builder,
    );
  }

  static Future<T?> showDraggable<T>({
    required BuildContext context,
    required Widget Function(BuildContext, ScrollController) builder,
    double minChildSize = 0.25,
    double initialChildSize = 0.5,
    double maxChildSize = 0.9,
    bool useSafeArea = true,
    bool showDragHandle = true,
  }) {
    return show<T>(
      context: context,
      useSafeArea: useSafeArea,
      isScrollControlled: true,
      showDragHandle: showDragHandle,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        minChildSize: minChildSize,
        initialChildSize: initialChildSize,
        maxChildSize: maxChildSize,
        builder: builder,
      ),
    );
  }
}
