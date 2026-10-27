import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

import '../../core/storage/gallery_image_storage.dart';
import '../../core/storage/gallery_video_storage.dart';
import '../../l10n/generated/app_localizations.dart';
import '../type/media_preview_type.dart';
import '../providers/harness_access_provider.dart';
import 'app_media_gallery.dart';
import 'app_media_preview_route.dart';
import 'app_toast.dart';
import 'app_video_player.dart';

export '../type/media_preview_type.dart';

/// Displays images and videos above the current screen.
abstract final class AppMediaPreview {
  static Future<void> showGallery({
    required BuildContext context,
    required List<MediaPreviewItem> items,
    int initialIndex = 0,
  }) => AppMediaGallery.show(
    context: context,
    items: items,
    initialIndex: initialIndex,
  );

  static Future<void> showImage({
    required BuildContext context,
    required ImageProvider image,
    required Object heroTag,
    String? label,
  }) => showGallery(
    context: context,
    items: [ImagePreviewItem(image: image, heroTag: heroTag, label: label)],
  );

  static Future<void> showVideo({
    required BuildContext context,
    required Uri url,
  }) => AppMediaPreviewRoute.show(
    context: context,
    builder: (_, animation) => _VideoPreview(url: url, animation: animation),
  );
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.url, required this.animation});

  final Uri url;
  final Animation<double> animation;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  bool _saving = false;
  CancelToken? _downloadCancellation;

  Map<String, String> _accessHeaders() {
    try {
      return ProviderScope.containerOf(
        context,
        listen: false,
      ).read(harnessAccessHeadersProvider(widget.url.toString()));
    } on StateError {
      return const {};
    }
  }

  VoidCallback? _onUnauthorized() {
    try {
      return ProviderScope.containerOf(
        context,
        listen: false,
      ).read(harnessAccessUnauthorizedProvider(widget.url.toString()));
    } on StateError {
      return null;
    }
  }

  Future<void> _download() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    final cancellation = CancelToken();
    _downloadCancellation = cancellation;
    try {
      await GalleryVideoStorage.save(
        widget.url,
        cancelToken: cancellation,
        headers: _accessHeaders(),
        onUnauthorized: _onUnauthorized(),
      );
      if (mounted) {
        AppToast.success(
          context,
          kIsWeb ? l10n.sessionArtifactSaved : l10n.videoSavedToPhotos,
        );
      }
    } on GalleryAccessDenied {
      if (mounted) AppToast.error(context, l10n.videoSaveAccessDenied);
    } on GalException catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          error.type == GalExceptionType.accessDenied
              ? l10n.videoSaveAccessDenied
              : l10n.videoSaveFailed,
        );
      }
    } on DioException catch (error) {
      if (mounted && !CancelToken.isCancel(error)) {
        AppToast.error(context, l10n.videoSaveFailed);
      }
    } catch (_) {
      if (mounted) AppToast.error(context, l10n.videoSaveFailed);
    } finally {
      _downloadCancellation = null;
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _downloadCancellation?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: widget.animation,
            builder: (_, __) => ColoredBox(
              color: Colors.black.withValues(
                alpha: Curves.easeOutCubic.transform(widget.animation.value),
              ),
            ),
          ),
          _VideoPreviewContent(url: widget.url),
          Positioned(
            bottom: 20,
            right: 20,
            child: SafeArea(
              top: false,
              left: false,
              child: SizedBox.square(
                dimension: 48,
                child: IconButton(
                  key: const Key('video-preview-download'),
                  tooltip: AppLocalizations.of(context)!.download,
                  onPressed: _saving ? null : _download,
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                    backgroundColor: const Color(0x80333333),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.file_download_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _VideoPreviewContent extends StatelessWidget {
  const _VideoPreviewContent({required this.url});
  final Uri url;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      key: const Key('asset-preview-video'),
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 88),
              child: Center(
                child: AppVideoPlayer(
                  url: url,
                  autoplay: true,
                  controlsKeyPrefix: 'video-preview',
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                key: const Key('video-preview-close'),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
