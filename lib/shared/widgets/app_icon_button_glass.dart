import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Figma's circular glass surface, independent of the button's tap target.
class AppIconButtonGlass extends StatelessWidget {
  const AppIconButtonGlass({required this.child, super.key});

  final Widget child;
  static final _blur = ImageFilter.blur(sigmaX: 25, sigmaY: 25);

  static Widget backgroundBuilder(
    BuildContext context,
    Set<WidgetState> states,
    Widget? child,
  ) {
    if (child == null) return const SizedBox.shrink();
    final button = context.widget;
    final style = button is ButtonStyleButton ? button.style : null;
    final shape = style?.shape?.resolve(states);
    final fill = style?.backgroundColor?.resolve(states);
    if (states.contains(WidgetState.disabled) ||
        (shape != null && shape is! CircleBorder) ||
        (fill != null && fill.a > 0)) {
      return child;
    }
    return AppIconButtonGlass(child: child);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: SizedBox.square(
                dimension: 40,
                child: ClipOval(
                  child: BackdropFilter(
                    filter: _blur,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: dark
                            ? theme.colorScheme.surfaceContainerHigh.withValues(
                                alpha: .65,
                              )
                            : Colors.white.withValues(alpha: .5),
                        border: Border.all(
                          color: dark
                              ? Colors.white.withValues(alpha: .22)
                              : Colors.white,
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
