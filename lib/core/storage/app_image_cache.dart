import 'dart:collection';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../utils/app_url.dart';
import 'app_image_file_service.dart';

/// Shares downloaded images between thumbnails, covers and full-size previews.
abstract final class AppImageCache {
  static final _manager = CacheManager(
    Config(
      'popi_images_v1',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 300,
      fileService: createAppImageFileService(
        onUnauthorized: _notifyUnauthorized,
      ),
    ),
  );

  @visibleForTesting
  static BaseCacheManager? debugCacheManager;

  static BaseCacheManager get manager => debugCacheManager ?? _manager;

  static final LinkedHashMap<String, VoidCallback> _unauthorizedCallbacks =
      LinkedHashMap();
  static const _maxUnauthorizedCallbacks = 512;

  static String resolveUrl(String url) => AppUrl.resolve(url);

  // Keep the complete URL so content versions and signed URLs stay distinct.
  // Authenticated callers must supply a non-sensitive cache key namespace,
  // because CachedNetworkImageProvider equality intentionally ignores headers.
  static CachedNetworkImageProvider provider(
    String url, {
    Map<String, String> headers = const {},
    String? cacheKey,
    VoidCallback? onUnauthorized,
  }) {
    final resolvedUrl = resolveUrl(url);
    if (headers.isNotEmpty && onUnauthorized != null) {
      final key = _accessKey(resolvedUrl, headers);
      _unauthorizedCallbacks
        ..remove(key)
        ..[key] = onUnauthorized;
      while (_unauthorizedCallbacks.length > _maxUnauthorizedCallbacks) {
        _unauthorizedCallbacks.remove(_unauthorizedCallbacks.keys.first);
      }
    }
    return CachedNetworkImageProvider(
      resolvedUrl,
      cacheManager: manager,
      headers: headers.isEmpty ? null : headers,
      cacheKey: cacheKey,
    );
  }

  static Future<void> evict(
    String url, {
    Map<String, String> headers = const {},
    String? cacheKey,
    VoidCallback? onUnauthorized,
  }) async {
    await provider(
      url,
      headers: headers,
      cacheKey: cacheKey,
      onUnauthorized: onUnauthorized,
    ).evict();
    await manager.removeFile(cacheKey ?? resolveUrl(url));
  }

  static String _accessKey(String url, Map<String, String> headers) {
    final cookieDigest = sha256.convert(utf8.encode(headers['Cookie'] ?? ''));
    return '$url\n$cookieDigest\n${headers['Origin'] ?? ''}';
  }

  static void _notifyUnauthorized(String url, Map<String, String> headers) =>
      _unauthorizedCallbacks.remove(_accessKey(url, headers))?.call();
}
