import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// Shared Figma background treatment for dialogs, context menus and sheets.
class AppModalBackdrop extends StatelessWidget {
  const AppModalBackdrop({this.progress = 1, super.key})
    : assert(progress >= 0 && progress <= 1);

  // Figma background blur 20 exports as CSS blur 10px (Gaussian sigma).
  static const blurSigma = 10.0;
  static const dimColor = Color(0x33AFAFAF);
  static const enterDuration = Duration(milliseconds: 260);
  static const exitDuration = Duration(milliseconds: 180);

  final double progress;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ClipRect(
      child: BackdropFilter(
        enabled: progress > 0,
        filter: ImageFilter.blur(
          sigmaX: blurSigma * progress,
          sigmaY: blurSigma * progress,
        ),
        child: ColoredBox(
          color: dimColor.withValues(alpha: dimColor.a * progress),
        ),
      ),
    ),
  );
}
