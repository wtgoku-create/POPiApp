import 'package:flutter/foundation.dart';

/// Runtime capabilities, independent of the current window's layout width.
@immutable
class AppPlatform {
  const AppPlatform({required this.isWeb, required this.targetPlatform});

  static AppPlatform get current =>
      AppPlatform(isWeb: kIsWeb, targetPlatform: defaultTargetPlatform);

  final bool isWeb;

  /// Flutter's target platform; on Web this is a UI hint, not device detection.
  final TargetPlatform targetPlatform;

  /// Includes phones and tablets. Mobile browsers remain Web runtimes.
  bool get isNativeMobile =>
      !isWeb &&
      (targetPlatform == TargetPlatform.android ||
          targetPlatform == TargetPlatform.iOS);

  bool get isNativeDesktop =>
      !isWeb &&
      (targetPlatform == TargetPlatform.macOS ||
          targetPlatform == TargetPlatform.windows ||
          targetPlatform == TargetPlatform.linux);
}
