import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

import '../../core/storage/gallery_image_storage.dart';
import '../../core/storage/gallery_video_storage.dart';
import '../../l10n/generated/app_localizations.dart';
import 'app_media_preview_route.dart';
import 'app_toast.dart';
import 'app_video_player.dart';

/// Displays images and videos on one preview page above the current screen.
abstract final class AppMediaPreview {
  static Future<void> showImage({
    required BuildContext context,
    required ImageProvider image,
    required Object heroTag,
    String? label,
  }) => AppMediaPreviewRoute.show(
    context: context,
    builder: (_, animation) => _MediaPreview.image(
      image: image,
      heroTag: heroTag,
      label: label,
      animation: animation,
    ),
  );
  static Future<void> showVideo({
    required BuildContext context,
    required Uri url,
  }) => AppMediaPreviewRoute.show(
    context: context,
    builder: (_, animation) =>
        _MediaPreview.video(url: url, animation: animation),
  );
}

class _MediaPreview extends StatefulWidget {
  const _MediaPreview.image({
    required this.image,
    required this.heroTag,
    required this.animation,
    this.label,
  }) : url = null;

  const _MediaPreview.video({required this.url, required this.animation})
    : image = null,
      heroTag = null,
      label = null;

  final ImageProvider? image;
  final Object? heroTag;
  final Uri? url;
  final String? label;
  final Animation<double> animation;

  @override
  State<_MediaPreview> createState() => _MediaPreviewState();
}

class _MediaPreviewState extends State<_MediaPreview>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  final _pointers = <int>{};
  ImageStream? _imageStream;
  Size? _imageSize;
  late final _imageListener = ImageStreamListener((info, _) {
    final size = Size(
      info.image.width.toDouble(),
      info.image.height.toDouble(),
    );
    info.dispose();
    if (mounted && size != _imageSize) setState(() => _imageSize = size);
  });
  late final AnimationController _returnController;
  Offset _offset = Offset.zero;
  Offset _returnFrom = Offset.zero;
  Offset? _doubleTapPosition;
  bool _zoomed = false;
  bool _closing = false;
  bool _canDragDismiss = false;
  bool _saving = false;
  CancelToken? _downloadCancellation;

  Future<void> _download() async {
    if (_saving || _closing) return;
    final l10n = AppLocalizations.of(context)!;
    final video = widget.url != null;
    final accessDenied = video
        ? l10n.videoSaveAccessDenied
        : l10n.imageSaveAccessDenied;
    final failed = video ? l10n.videoSaveFailed : l10n.imageSaveFailed;
    setState(() => _saving = true);
    try {
      if (video) {
        final cancellation = CancelToken();
        _downloadCancellation = cancellation;
        await GalleryVideoStorage.save(widget.url!, cancelToken: cancellation);
      } else {
        await GalleryImageStorage.save(
          widget.image!,
          createLocalImageConfiguration(context),
        );
      }
      if (mounted) {
        AppToast.success(
          context,
          video ? l10n.videoSavedToPhotos : l10n.imageSavedToPhotos,
        );
      }
    } on GalleryAccessDenied {
      if (mounted) AppToast.error(context, accessDenied);
    } on GalException catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          error.type == GalExceptionType.accessDenied ? accessDenied : failed,
        );
      }
    } on DioException catch (error) {
      if (mounted && !CancelToken.isCancel(error)) {
        AppToast.error(context, failed);
      }
    } catch (_) {
      if (mounted) AppToast.error(context, failed);
    } finally {
      _downloadCancellation = null;
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _returnController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 200),
        )..addListener(() {
          setState(
            () => _offset = Offset.lerp(
              _returnFrom,
              Offset.zero,
              Curves.easeOutCubic.transform(_returnController.value),
            )!,
          );
        });
    _transform.addListener(_onTransform);
  }

  void _onTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) {
      setState(() {
        _zoomed = zoomed;
        _offset = Offset.zero;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final image = widget.image;
    if (image == null) return;
    final stream = image.resolve(createLocalImageConfiguration(context));
    if (_imageStream?.key == stream.key) return;
    _imageStream?.removeListener(_imageListener);
    _imageStream = stream..addListener(_imageListener);
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    _returnController.stop();
    Navigator.of(context).pop();
  }

  void _pointerDown(PointerDownEvent event) {
    _returnController.stop();
    _pointers.add(event.pointer);
    if (_pointers.length == 1) _canDragDismiss = !_zoomed;
    if (_pointers.length > 1) {
      _canDragDismiss = false;
      setState(() => _offset = Offset.zero);
    }
  }

  void _pointerMove(PointerMoveEvent event) {
    if (_closing || _zoomed || !_canDragDismiss || _pointers.length != 1) {
      return;
    }
    if (_offset == Offset.zero &&
        event.delta.dy.abs() <= event.delta.dx.abs()) {
      return;
    }
    setState(() => _offset += event.delta);
  }

  void _pointerEnd(PointerEvent event, {bool cancelled = false}) {
    _pointers.remove(event.pointer);
    if (_pointers.isNotEmpty || _zoomed || _offset == Offset.zero) return;
    if (!cancelled && _offset.dy > 100) {
      _close();
    } else {
      _returnFrom = _offset;
      if (MediaQuery.disableAnimationsOf(context)) {
        setState(() => _offset = Offset.zero);
      } else {
        _returnController.forward(from: 0);
      }
    }
  }

  void _doubleTap() {
    if (_zoomed) {
      _transform.value = Matrix4.identity();
    } else {
      final point = _doubleTapPosition ?? Offset.zero;
      _transform.value = Matrix4.identity()
        ..translateByDouble(-point.dx * 1.5, -point.dy * 1.5, 0, 1)
        ..scaleByDouble(2.5, 2.5, 1, 1);
    }
  }

  @override
  void dispose() {
    _downloadCancellation?.cancel();
    _imageStream?.removeListener(_imageListener);
    _transform.removeListener(_onTransform);
    _transform.dispose();
    _returnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final progress = (_offset.dy.abs() / MediaQuery.sizeOf(context).height)
        .clamp(0.0, 1.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
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
                  alpha:
                      Curves.easeOutCubic.transform(widget.animation.value) *
                      (1 - progress * .85),
                ),
              ),
            ),
            if (widget.url != null)
              _VideoPreviewContent(url: widget.url!)
            else
              Listener(
                onPointerDown: _pointerDown,
                onPointerMove: _pointerMove,
                onPointerUp: (event) => _pointerEnd(event),
                onPointerCancel: (event) => _pointerEnd(event, cancelled: true),
                child: GestureDetector(
                  onTap: _close,
                  onDoubleTapDown: (details) =>
                      _doubleTapPosition = details.localPosition,
                  onDoubleTap: _doubleTap,
                  child: Transform.translate(
                    offset: _offset,
                    child: Transform.scale(
                      scale: math.max(.7, 1 - progress * .4),
                      child: InteractiveViewer(
                        key: const Key('asset-preview-image'),
                        transformationController: _transform,
                        panEnabled: _zoomed,
                        minScale: 1,
                        maxScale: 4,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final imageSize = _imageSize;
                            final size = imageSize == null
                                ? constraints.biggest
                                : applyBoxFit(
                                    BoxFit.contain,
                                    imageSize,
                                    constraints.biggest,
                                  ).destination;
                            // The Hero must enclose the painted image, not its letterboxing.
                            return Center(
                              child: Hero(
                                tag: widget.heroTag!,
                                child: Image(
                                  image: widget.image!,
                                  width: size.width,
                                  height: size.height,
                                  fit: BoxFit.contain,
                                  semanticLabel:
                                      widget.label ?? l10n.assetPreview,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Text(
                                      l10n.networkRequestFailed,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 20,
              right: 20,
              child: SafeArea(
                top: false,
                left: false,
                child: Opacity(
                  opacity: 1 - progress,
                  child: SizedBox.square(
                    dimension: 48,
                    child: IconButton(
                      key: Key(
                        widget.url == null
                            ? 'asset-preview-download'
                            : 'video-preview-download',
                      ),
                      tooltip: l10n.download,
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
            ),
          ],
        ),
      ),
    );
  }
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
