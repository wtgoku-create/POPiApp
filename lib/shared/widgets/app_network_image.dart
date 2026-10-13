import 'package:flutter/material.dart';

import '../../core/storage/app_image_cache.dart';

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
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;
  final String? semanticLabel;
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) => Image(
    image: AppImageCache.provider(url),
    width: width,
    height: height,
    fit: fit,
    errorBuilder: errorBuilder,
    loadingBuilder: loadingBuilder,
    semanticLabel: semanticLabel,
    excludeFromSemantics: excludeFromSemantics,
  );
}
