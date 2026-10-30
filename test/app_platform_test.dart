import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/platform/app_platform.dart';

void main() {
  for (final target in TargetPlatform.values) {
    test('Web on $target never selects native capabilities', () {
      final platform = AppPlatform(isWeb: true, targetPlatform: target);
      expect(platform.isWeb, isTrue);
      expect(platform.isNativeMobile, isFalse);
      expect(platform.isNativeDesktop, isFalse);
    });

    test('native $target selects the appropriate capability family', () {
      final platform = AppPlatform(isWeb: false, targetPlatform: target);
      expect(platform.isWeb, isFalse);
      expect(
        platform.isNativeMobile,
        {TargetPlatform.android, TargetPlatform.iOS}.contains(target),
      );
      expect(
        platform.isNativeDesktop,
        {
          TargetPlatform.macOS,
          TargetPlatform.windows,
          TargetPlatform.linux,
        }.contains(target),
      );
    });
  }

  test('current reads Flutter platform overrides without caching', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(AppPlatform.current.targetPlatform, TargetPlatform.iOS);
    expect(AppPlatform.current.isWeb, kIsWeb);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(AppPlatform.current.targetPlatform, TargetPlatform.windows);
    expect(AppPlatform.current.isNativeDesktop, !kIsWeb);
  });
}
