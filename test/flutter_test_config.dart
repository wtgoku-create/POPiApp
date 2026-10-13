import 'dart:async';

import 'package:popi_ai_app/core/storage/app_image_cache.dart';

import 'support/memory_image_cache.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  AppImageCache.debugCacheManager = MemoryImageCache();
  await testMain();
}
