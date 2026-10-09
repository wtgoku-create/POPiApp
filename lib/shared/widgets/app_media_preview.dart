import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:video_player/video_player.dart';

import '../../core/storage/gallery_image_storage.dart';
import '../../l10n/generated/app_localizations.dart';
import 'app_media_preview_route.dart';
import 'app_svg_icon.dart';
import 'app_toast.dart';

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

  Future<void> _download() async {
    if (_saving || _closing) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _saving = true);
    try {
      await GalleryImageStorage.save(
        widget.image!,
        createLocalImageConfiguration(context),
      );
      if (mounted) AppToast.success(context, l10n.imageSavedToPhotos);
    } on GalleryAccessDenied {
      if (mounted) AppToast.error(context, l10n.imageSaveAccessDenied);
    } on GalException catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          error.type == GalExceptionType.accessDenied
              ? l10n.imageSaveAccessDenied
              : l10n.imageSaveFailed,
        );
      }
    } catch (_) {
      if (mounted) AppToast.error(context, l10n.imageSaveFailed);
    } finally {
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
            if (widget.image != null)
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
                        key: const Key('asset-preview-download'),
                        tooltip: l10n.download,
                        onPressed: _saving ? null : _download,
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(4),
                        ),
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const AppSvgIcon.asset(
                                'image_preview_download',
                                size: 40,
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

class _VideoPreviewContent extends StatefulWidget {
  const _VideoPreviewContent({required this.url});

  final Uri url;

  @override
  State<_VideoPreviewContent> createState() => _VideoPreviewContentState();
}

class _VideoPreviewContentState extends State<_VideoPreviewContent>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _failed = false;
  double? _seekSeconds;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final previous = _controller;
    final controller = VideoPlayerController.networkUrl(widget.url);
    setState(() {
      _controller = controller;
      _loading = true;
      _failed = false;
      _seekSeconds = null;
    });
    try {
      await previous?.dispose();
      if (!mounted || generation != _generation) return;
      await controller.initialize();
      if (!mounted || generation != _generation) return;
      setState(() => _loading = false);
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
        await controller.play();
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _command(
    Future<void> Function(VideoPlayerController) run,
  ) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await run(controller);
    } catch (_) {
      if (mounted && identical(controller, _controller)) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _command((controller) => controller.pause());
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  String _time(Duration value) {
    final seconds = value.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = _controller!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        key: const Key('asset-preview-video'),
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final failed = _failed || value.hasError;
              final ready = !_loading && !failed && value.isInitialized;
              final total = value.duration.inMilliseconds / 1000;
              final seconds =
                  (_seekSeconds ?? value.position.inMilliseconds / 1000).clamp(
                    0.0,
                    total,
                  );
              return Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: IconButton(
                        key: const Key('video-preview-close'),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: failed
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  l10n.videoLoadFailed,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                TextButton(
                                  key: const Key('video-preview-retry'),
                                  onPressed: _load,
                                  child: Text(l10n.retry),
                                ),
                              ],
                            )
                          : !ready
                          ? const CircularProgressIndicator(color: Colors.white)
                          : AspectRatio(
                              aspectRatio: value.aspectRatio,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  VideoPlayer(controller),
                                  if (value.isBuffering)
                                    const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  if (ready)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Slider(
                            key: const Key('video-preview-seek'),
                            value: seconds,
                            max: total > 0 ? total : 1,
                            semanticFormatterCallback: (value) =>
                                '${l10n.videoSeek}: ${_time(Duration(seconds: value.toInt()))}',
                            onChanged: total > 0
                                ? (value) =>
                                      setState(() => _seekSeconds = value)
                                : null,
                            onChangeEnd: (value) async {
                              await _command(
                                (controller) => controller.seekTo(
                                  Duration(
                                    milliseconds: (value * 1000).round(),
                                  ),
                                ),
                              );
                              if (mounted) setState(() => _seekSeconds = null);
                            },
                          ),
                          Row(
                            children: [
                              IconButton(
                                key: const Key('video-preview-play'),
                                tooltip: value.isPlaying
                                    ? l10n.videoPause
                                    : l10n.videoPlay,
                                onPressed: () => _command((controller) async {
                                  if (value.isPlaying) {
                                    await controller.pause();
                                  } else {
                                    if (value.isCompleted) {
                                      await controller.seekTo(Duration.zero);
                                    }
                                    await controller.play();
                                  }
                                }),
                                icon: Icon(
                                  value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${_time(Duration(milliseconds: (seconds * 1000).round()))} / ${_time(value.duration)}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              IconButton(
                                key: const Key('video-preview-mute'),
                                tooltip: value.volume == 0
                                    ? l10n.videoUnmute
                                    : l10n.videoMute,
                                onPressed: () => _command(
                                  (controller) => controller.setVolume(
                                    value.volume == 0 ? 1 : 0,
                                  ),
                                ),
                                icon: Icon(
                                  value.volume == 0
                                      ? Icons.volume_off
                                      : Icons.volume_up,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
