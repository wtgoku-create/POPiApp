import 'dart:collection';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
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
  static ImageProvider provider(
    String url, {
    Map<String, String> headers = const {},
    String? cacheKey,
    VoidCallback? onUnauthorized,
  }) {
    final resolvedUrl = resolveUrl(url);
    final uri = Uri.tryParse(resolvedUrl);
    // 公开 CDN 未开放 CORS 时交给浏览器图片元素；私有图片保留鉴权和缓存隔离。
    if (kIsWeb &&
        headers.isEmpty &&
        cacheKey == null &&
        onUnauthorized == null &&
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.origin != Uri.base.origin) {
      return NetworkImage(
        resolvedUrl,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      );
    }
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
      // HtmlImage 会忽略 headers；私有素材必须经过支持鉴权头的 HTTP 加载器。
      imageRenderMethodForWeb: headers.isNotEmpty
          ? ImageRenderMethodForWeb.HttpGet
          : ImageRenderMethodForWeb.HtmlImage,
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
    final credentialDigest = sha256.convert(
      utf8.encode(
        '${headers['Cookie'] ?? ''}\n${headers['Authorization'] ?? ''}',
      ),
    );
    return '$url\n$credentialDigest\n${headers['Origin'] ?? ''}';
  }

  static void _notifyUnauthorized(String url, Map<String, String> headers) =>
      _unauthorizedCallbacks.remove(_accessKey(url, headers))?.call();
}
