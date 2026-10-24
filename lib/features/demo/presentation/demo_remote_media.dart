import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/app_image_cache.dart';
import '../../../shared/providers/harness_access_provider.dart';
import '../domain/demo_models.dart';

/// Chooses the server-owned image bytes or the bundled offline fixture.
ImageProvider demoAssetImageProvider(
  DemoAsset asset, {
  Map<String, String> headers = const {},
  String? cacheKey,
  VoidCallback? onUnauthorized,
  int? cacheWidth,
}) {
  final ImageProvider provider = asset.isRemote
      ? AppImageCache.provider(
          demoAssetImageUrl(asset),
          headers: headers,
          cacheKey: cacheKey,
          onUnauthorized: onUnauthorized,
        )
      : AssetImage(asset.cover);
  return ResizeImage.resizeIfNeeded(cacheWidth, null, provider);
}

String demoAssetImageUrl(DemoAsset asset) {
  if (asset.kind != DemoAssetKind.video) return asset.contentUrl;
  if (asset.posterUrl.isEmpty) {
    throw StateError('Remote video does not have a poster');
  }
  return asset.posterUrl;
}

/// Resolves auth at the user action that creates a full-screen preview.
ImageProvider demoAssetImageProviderForContext(
  BuildContext context,
  DemoAsset asset,
) {
  if (!asset.isRemote) return demoAssetImageProvider(asset);
  final url = demoAssetImageUrl(asset);
  try {
    final container = ProviderScope.containerOf(context, listen: false);
    return demoAssetImageProvider(
      asset,
      headers: container.read(harnessAccessHeadersProvider(url)),
      cacheKey: container.read(harnessAccessCacheKeyProvider(url)),
      onUnauthorized: container.read(harnessAccessUnauthorizedProvider(url)),
    );
  } on StateError {
    return demoAssetImageProvider(asset);
  }
}

/// Renders local and server-owned images through one stable layout.
class DemoAssetImage extends ConsumerWidget {
  const DemoAssetImage({
    required this.asset,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.cacheWidth,
    super.key,
  });

  final DemoAsset asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (asset.isRemote &&
        asset.kind == DemoAssetKind.video &&
        asset.posterUrl.isEmpty) {
      return _RemoteVideoPlaceholder(
        asset: asset,
        width: width,
        height: height,
      );
    }
    final image = asset.isRemote
        ? demoAssetImageProvider(
            asset,
            headers: ref.watch(
              harnessAccessHeadersProvider(demoAssetImageUrl(asset)),
            ),
            cacheKey: ref.watch(
              harnessAccessCacheKeyProvider(demoAssetImageUrl(asset)),
            ),
            onUnauthorized: ref.watch(
              harnessAccessUnauthorizedProvider(demoAssetImageUrl(asset)),
            ),
            cacheWidth: cacheWidth,
          )
        : demoAssetImageProvider(asset, cacheWidth: cacheWidth);
    return Image(
      image: image,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      loadingBuilder: asset.isRemote
          ? (context, child, progress) => progress == null
                ? child
                : asset.kind == DemoAssetKind.video
                ? _RemoteVideoPlaceholder(
                    asset: asset,
                    width: width,
                    height: height,
                  )
                : ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: const Center(
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
          : null,
      errorBuilder: asset.kind == DemoAssetKind.video
          ? (context, error, stackTrace) => _RemoteVideoPlaceholder(
              asset: asset,
              width: width,
              height: height,
            )
          : (context, error, stackTrace) => ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Icon(
                Icons.broken_image_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}

class _RemoteVideoPlaceholder extends StatelessWidget {
  const _RemoteVideoPlaceholder({
    required this.asset,
    required this.width,
    required this.height,
  });

  final DemoAsset asset;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('demo-remote-video-thumbnail-${asset.id}'),
    width: width,
    height: height,
    alignment: Alignment.center,
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Icon(
      Icons.play_arrow_rounded,
      size: 32,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
