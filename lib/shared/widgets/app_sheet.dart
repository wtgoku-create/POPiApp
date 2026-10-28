import 'package:flutter/material.dart';

import 'app_modal_backdrop.dart';
import 'app_modal_scope.dart';
import 'app_keyboard_dismiss.dart';

class AppSheet {
  const AppSheet._();

  static const maxHeightFactor = .8;
  static const maxWidth = 480.0;

  /// Converts page-relative drag sizes to the capped sheet's available height.
  static double relativeExtent(double pageFraction) =>
      (pageFraction / maxHeightFactor).clamp(0.0, 1.0);

  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool useSafeArea = true,
    bool isScrollControlled = false,
    bool isDismissible = true,
    bool enableDrag = true,
    bool showDragHandle = true,
    double maxHeightFraction = maxHeightFactor,
    Color? backgroundColor,
    ShapeBorder? shape,
  }) {
    assert(maxHeightFraction > 0 && maxHeightFraction <= 1);
    if (!AppModalScope.isActiveOf(context)) return Future.value();
    FocusManager.instance.primaryFocus?.unfocus();
    final navigator = Navigator.of(context);
    final localizations = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    final route = _AppSheetRoute<T>(
      builder: (context) => AppKeyboardDismiss(child: builder(context)),
      capturedThemes: InheritedTheme.capture(
        from: context,
        to: navigator.context,
      ),
      barrierLabel: localizations.scrimLabel,
      barrierOnTapHint: localizations.scrimOnTapHint(
        localizations.bottomSheetLabel,
      ),
      useSafeArea: useSafeArea,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      showDragHandle: showDragHandle,
      maxHeightFraction: maxHeightFraction,
      backgroundColor: backgroundColor,
      shape: shape,
      sheetConstraints:
          theme.bottomSheetTheme.constraints ??
          const BoxConstraints(maxWidth: maxWidth),
      sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
    );
    final result = navigator.push<T>(route);
    AppModalScope.bind(context, route);
    return result;
  }

  static Future<T?> showDraggable<T>({
    required BuildContext context,
    required Widget Function(BuildContext, ScrollController) builder,
    double minChildSize = 0.25,
    double initialChildSize = 0.5,
    double maxChildSize = maxHeightFactor,
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
        minChildSize: relativeExtent(minChildSize),
        initialChildSize: relativeExtent(initialChildSize),
        maxChildSize: relativeExtent(maxChildSize),
        builder: builder,
      ),
    );
  }
}

/// Keeps Flutter sheet gestures and semantics with a full-screen blurred barrier.
class _AppSheetRoute<T> extends ModalBottomSheetRoute<T> {
  _AppSheetRoute({
    required super.builder,
    required super.capturedThemes,
    required super.barrierLabel,
    required super.barrierOnTapHint,
    required super.useSafeArea,
    required super.isScrollControlled,
    required super.isDismissible,
    required super.enableDrag,
    required super.showDragHandle,
    required this.sheetConstraints,
    required this.maxHeightFraction,
    super.backgroundColor,
    super.shape,
    super.sheetAnimationStyle,
  }) : super(
         modalBarrierColor: Colors.transparent,
         // The route constraints apply the page-relative cap for both modes.
         scrollControlDisabledMaxHeightRatio: 1,
       );

  final BoxConstraints sheetConstraints;
  final double maxHeightFraction;
  BoxConstraints? _heightConstraints;

  @override
  BoxConstraints? get constraints => _heightConstraints;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // Recalculate when the viewport changes while the sheet is open.
    _heightConstraints = sheetConstraints.enforce(
      BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * maxHeightFraction,
      ),
    );
    return super.buildPage(context, animation, secondaryAnimation);
  }

  @override
  Widget buildModalBarrier() => AnimatedBuilder(
    animation: animation!,
    child: super.buildModalBarrier(),
    builder: (context, barrier) => Stack(
      fit: StackFit.expand,
      children: [
        AppModalBackdrop(
          progress: offstage ? 0 : barrierCurve.transform(animation!.value),
        ),
        barrier!,
      ],
    ),
  );
}
