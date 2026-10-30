import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

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
  bool preferThumbnail = false,
}) {
  final ImageProvider provider;
  if (asset.isRemote) {
    final url = demoAssetImageUrl(asset, preferThumbnail: preferThumbnail);
    provider = AppImageCache.provider(
      url,
      headers: headers,
      cacheKey: cacheKey,
      onUnauthorized: onUnauthorized,
    );
  } else {
    provider = AssetImage(asset.cover);
  }
  return ResizeImage.resizeIfNeeded(cacheWidth, null, provider);
}

String demoAssetImageUrl(DemoAsset asset, {bool preferThumbnail = false}) {
  if (asset.kind != DemoAssetKind.video) {
    return preferThumbnail && asset.thumbnailUrl.isNotEmpty
        ? asset.thumbnailUrl
        : asset.contentUrl;
  }
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
class DemoAssetImage extends ConsumerStatefulWidget {
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
  ConsumerState<DemoAssetImage> createState() => _DemoAssetImageState();
}

class _DemoAssetImageState extends ConsumerState<DemoAssetImage> {
  bool _useOriginal = false;
  bool _fallbackScheduled = false;

  @override
  void didUpdateWidget(DemoAssetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id ||
        oldWidget.asset.contentUrl != widget.asset.contentUrl ||
        oldWidget.asset.thumbnailUrl != widget.asset.thumbnailUrl) {
      _useOriginal = false;
      _fallbackScheduled = false;
    }
  }

  void _fallbackToOriginal(Object error) {
    final asset = widget.asset;
    if (_useOriginal ||
        _fallbackScheduled ||
        asset.kind != DemoAssetKind.image ||
        asset.thumbnailUrl.isEmpty ||
        error is HttpExceptionWithStatus && error.statusCode == 401) {
      return;
    }
    _fallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _useOriginal = true;
        _fallbackScheduled = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    if (asset.isRemote &&
        asset.kind == DemoAssetKind.video &&
        asset.posterUrl.isEmpty) {
      return _RemoteVideoPlaceholder(
        asset: asset,
        width: widget.width,
        height: widget.height,
      );
    }
    final imageUrl = asset.isRemote
        ? demoAssetImageUrl(asset, preferThumbnail: !_useOriginal)
        : null;
    final image = imageUrl != null
        ? demoAssetImageProvider(
            asset,
            headers: ref.watch(harnessAccessHeadersProvider(imageUrl)),
            cacheKey: ref.watch(harnessAccessCacheKeyProvider(imageUrl)),
            onUnauthorized: ref.watch(
              harnessAccessUnauthorizedProvider(imageUrl),
            ),
            cacheWidth: widget.cacheWidth,
            preferThumbnail: !_useOriginal,
          )
        : demoAssetImageProvider(asset, cacheWidth: widget.cacheWidth);
    return Image(
      image: image,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      alignment: widget.alignment,
      loadingBuilder: asset.isRemote
          ? (context, child, progress) => progress == null
                ? child
                : asset.kind == DemoAssetKind.video
                ? _RemoteVideoPlaceholder(
                    asset: asset,
                    width: widget.width,
                    height: widget.height,
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
      errorBuilder: (context, error, stackTrace) {
        if (asset.kind == DemoAssetKind.video) {
          return _RemoteVideoPlaceholder(
            asset: asset,
            width: widget.width,
            height: widget.height,
          );
        }
        _fallbackToOriginal(error);
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Icon(
            Icons.broken_image_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      },
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
