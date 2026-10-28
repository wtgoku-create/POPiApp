import 'package:flutter/widgets.dart';

/// Retains consumed side insets so nested page gutters do not add them twice.
class AppPageSafeArea extends SafeArea {
  const AppPageSafeArea({
    required super.child,
    super.key,
    super.left,
    super.top,
    super.right,
    super.bottom,
    super.minimum,
    super.maintainBottomViewPadding,
  });

  static EdgeInsets horizontalPaddingOf(
    BuildContext context, {
    double gutter = 20,
  }) {
    final insets =
        maybeConsumedInsetsOf(context) ?? MediaQuery.paddingOf(context);
    return EdgeInsets.only(
      left: (gutter - insets.left).clamp(0.0, gutter),
      right: (gutter - insets.right).clamp(0.0, gutter),
    );
  }

  /// Null when the host has not consumed any page safe area.
  static EdgeInsets? maybeConsumedInsetsOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ConsumedPageInsets>()?.insets;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    final parent = context
        .dependOnInheritedWidgetOfExactType<_ConsumedPageInsets>()
        ?.insets;
    return _ConsumedPageInsets(
      insets: EdgeInsets.only(
        left:
            (parent?.left ?? 0) +
            (left
                ? (insets.left > minimum.left ? insets.left : minimum.left)
                : 0),
        right:
            (parent?.right ?? 0) +
            (right
                ? (insets.right > minimum.right ? insets.right : minimum.right)
                : 0),
      ),
      child: super.build(context),
    );
  }
}

class _ConsumedPageInsets extends InheritedWidget {
  const _ConsumedPageInsets({required this.insets, required super.child});

  final EdgeInsets insets;

  @override
  bool updateShouldNotify(_ConsumedPageInsets oldWidget) =>
      insets != oldWidget.insets;
}
