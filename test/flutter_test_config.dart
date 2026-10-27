import 'dart:async';

import 'package:popi_ai_app/core/storage/app_image_cache.dart';
import 'package:popi_ai_app/shared/widgets/app_bot_avatar.dart';

import 'support/memory_image_cache.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppImageCache.debugCacheManager = MemoryImageCache();
  // Most page tests settle layout; motion is exercised by app_bot_avatar_test.
  AppBotAvatar.debugAnimationsEnabled = false;
  await testMain();
}
