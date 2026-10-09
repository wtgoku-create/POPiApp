import 'package:flutter/material.dart';

import 'app_modal_backdrop.dart';

class AppSheet {
  const AppSheet._();

  static const maxHeightFactor = .8;

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
    Color? backgroundColor,
    ShapeBorder? shape,
  }) {
    final navigator = Navigator.of(context);
    final localizations = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    return navigator.push<T>(
      _AppSheetRoute<T>(
        builder: builder,
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
        backgroundColor: backgroundColor,
        shape: shape,
        sheetConstraints:
            theme.bottomSheetTheme.constraints ??
            BoxConstraints(
              maxWidth: theme.useMaterial3 ? 640 : double.infinity,
            ),
        sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : null,
      ),
    );
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
    super.backgroundColor,
    super.shape,
    super.sheetAnimationStyle,
  }) : super(
         modalBarrierColor: Colors.transparent,
         // The route constraints apply the page-relative cap for both modes.
         scrollControlDisabledMaxHeightRatio: 1,
       );

  final BoxConstraints sheetConstraints;
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
        maxHeight: MediaQuery.sizeOf(context).height * AppSheet.maxHeightFactor,
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
