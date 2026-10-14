import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../utils/app_url.dart';

/// Shares downloaded images between thumbnails, covers and full-size previews.
abstract final class AppImageCache {
  static final _manager = CacheManager(
    Config(
      'popi_images_v1',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 300,
    ),
  );

  @visibleForTesting
  static BaseCacheManager? debugCacheManager;

  static BaseCacheManager get manager => debugCacheManager ?? _manager;

  static String resolveUrl(String url) => AppUrl.resolve(url);

  // Keep the complete URL so content versions and signed URLs stay distinct.
  static CachedNetworkImageProvider provider(String url) =>
      CachedNetworkImageProvider(resolveUrl(url), cacheManager: manager);

  static Future<void> evict(String url) async {
    await provider(url).evict();
    await manager.removeFile(resolveUrl(url));
  }
}
