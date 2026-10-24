import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/media_image_repository.dart';
import '../../core/storage/app_image_cache.dart';
import '../providers/media_image_provider.dart';

export '../../core/storage/app_image_cache.dart';

/// Uses the shared disk cache without changing the page's image presentation.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.errorBuilder,
    this.loadingBuilder,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.headers = const {},
    this.cacheKey,
    this.onUnauthorized,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Map<String, String> headers;
  final String? cacheKey;
  final VoidCallback? onUnauthorized;

  @override
  Widget build(BuildContext context) =>
      MediaImageRepository.protectedMediaId(url) == null
      ? _image(url)
      : _ProtectedImage(image: this);

  Widget _image(String resolvedUrl, {bool includeAccess = true}) => Image(
    image: AppImageCache.provider(
      resolvedUrl,
      headers: includeAccess ? headers : const {},
      cacheKey: includeAccess ? cacheKey : null,
      onUnauthorized: includeAccess ? onUnauthorized : null,
    ),
    width: width,
    height: height,
    fit: fit,
    errorBuilder: errorBuilder,
    loadingBuilder: loadingBuilder,
    semanticLabel: semanticLabel,
    excludeFromSemantics: excludeFromSemantics,
  );
}

class _ProtectedImage extends ConsumerWidget {
  const _ProtectedImage({required this.image});

  final AppNetworkImage image;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(mediaImageUrlProvider(image.url))
      .when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        data: (url) => image._image(url, includeAccess: false),
        error: (error, stack) =>
            image.errorBuilder?.call(context, error, stack) ??
            SizedBox(width: image.width, height: image.height),
        loading: () {
          final child = SizedBox(width: image.width, height: image.height);
          return image.loadingBuilder?.call(
                context,
                child,
                const ImageChunkEvent(
                  cumulativeBytesLoaded: 0,
                  expectedTotalBytes: null,
                ),
              ) ??
              child;
        },
      );
}
