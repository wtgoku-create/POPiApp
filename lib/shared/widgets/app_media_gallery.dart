import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/storage/gallery_image_storage.dart';
import '../../core/storage/gallery_video_storage.dart';
import '../../l10n/generated/app_localizations.dart';
import '../type/media_preview_type.dart';
import '../providers/harness_access_provider.dart';
import 'app_media_preview_route.dart';
import 'app_skeleton.dart';
import 'app_svg_icon.dart';
import 'app_toast.dart';
import 'app_video_player.dart';

/// Shared gallery surface and gestures for image and video previews.
abstract final class AppMediaGallery {
  static Future<void> show({
    required BuildContext context,
    required List<MediaPreviewItem> items,
    int initialIndex = 0,
  }) {
    if (items.isEmpty) return Future.value();
    RangeError.checkValidIndex(initialIndex, items, 'initialIndex');
    final snapshot = List<MediaPreviewItem>.unmodifiable(items);
    return AppMediaPreviewRoute.show(
      context: context,
      builder: (_, animation) => _MediaGallery(
        items: snapshot,
        initialIndex: initialIndex,
        animation: animation,
      ),
    );
  }
}

class _MediaGallery extends StatefulWidget {
  const _MediaGallery({
    required this.items,
    required this.initialIndex,
    required this.animation,
  });

  final List<MediaPreviewItem> items;
  final int initialIndex;
  final Animation<double> animation;

  @override
  State<_MediaGallery> createState() => _MediaGalleryState();
}

class _MediaGalleryState extends State<_MediaGallery> {
  late final _pages = PageController(initialPage: widget.initialIndex);
  final _thumbnails = ScrollController();
  late int _index = widget.initialIndex;
  bool _zoomed = false;
  bool _closing = false;
  bool _saving = false;
  bool _sharing = false;
  double _dismissProgress = 0;
  CancelToken? _videoSaveToken;
  CancelToken? _videoShareToken;

  Map<String, String> _accessHeaders(Uri url) {
    try {
      return ProviderScope.containerOf(
        context,
        listen: false,
      ).read(harnessAccessHeadersProvider(url.toString()));
    } on StateError {
      return const {};
    }
  }

  VoidCallback? _onUnauthorized(Uri url) {
    try {
      return ProviderScope.containerOf(
        context,
        listen: false,
      ).read(harnessAccessUnauthorizedProvider(url.toString()));
    } on StateError {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealThumbnail());
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    _videoSaveToken?.cancel();
    _videoShareToken?.cancel();
    Navigator.of(context).pop();
  }

  void _revealThumbnail({bool animate = false}) {
    if (!mounted || !_thumbnails.hasClients) return;
    final position = _thumbnails.position;
    final target = (_index * 45 - (position.viewportDimension - 40) / 2).clamp(
      0.0,
      position.maxScrollExtent,
    );
    if (animate && !MediaQuery.disableAnimationsOf(context)) {
      _thumbnails.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    } else {
      _thumbnails.jumpTo(target);
    }
  }

  void _changePage(int index) {
    setState(() {
      _index = index;
      _zoomed = false;
      _dismissProgress = 0;
    });
    _revealThumbnail(animate: true);
  }

  void _select(int index) {
    if (_closing || index < 0 || index >= widget.items.length) return;
    _pages.jumpToPage(index);
  }

  Future<void> _download() async {
    if (_saving || _closing) return;
    final l10n = AppLocalizations.of(context)!;
    final item = widget.items[_index];
    final video = item is VideoPreviewItem;
    setState(() => _saving = true);
    try {
      switch (item) {
        case ImagePreviewItem():
          await GalleryImageStorage.save(
            item.image,
            createLocalImageConfiguration(context),
          );
        case VideoPreviewItem():
          final token = _videoSaveToken = CancelToken();
          await GalleryVideoStorage.save(
            item.url,
            cancelToken: token,
            headers: _accessHeaders(item.url),
            onUnauthorized: _onUnauthorized(item.url),
          );
      }
      if (mounted && !_closing) {
        AppToast.success(
          context,
          video
              ? kIsWeb
                    ? l10n.sessionArtifactSaved
                    : l10n.videoSavedToPhotos
              : kIsWeb
              ? l10n.sessionArtifactSaved
              : l10n.imageSavedToPhotos,
        );
      }
    } on GalleryAccessDenied {
      if (mounted && !_closing) {
        AppToast.error(
          context,
          video ? l10n.videoSaveAccessDenied : l10n.imageSaveAccessDenied,
        );
      }
    } on GalException catch (error) {
      if (mounted && !_closing) {
        AppToast.error(
          context,
          error.type == GalExceptionType.accessDenied
              ? (video
                    ? l10n.videoSaveAccessDenied
                    : l10n.imageSaveAccessDenied)
              : (video ? l10n.videoSaveFailed : l10n.imageSaveFailed),
        );
      }
    } catch (error) {
      if (mounted &&
          !_closing &&
          !(error is DioException && CancelToken.isCancel(error))) {
        AppToast.error(
          context,
          video ? l10n.videoSaveFailed : l10n.imageSaveFailed,
        );
      }
    } finally {
      _videoSaveToken = null;
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _share(BuildContext buttonContext) async {
    if (_sharing || _closing) return;
    final l10n = AppLocalizations.of(context)!;
    final item = widget.items[_index];
    final box = buttonContext.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _sharing = true);
    try {
      switch (item) {
        case ImagePreviewItem():
          final bytes = await GalleryImageStorage.readPng(
            item.image,
            createLocalImageConfiguration(context),
          );
          if (!mounted || _closing) return;
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile.fromData(bytes, mimeType: 'image/png')],
              fileNameOverrides: ['POPi_image.png'],
              sharePositionOrigin: origin,
            ),
          );
        case VideoPreviewItem():
          final token = _videoShareToken = CancelToken();
          if (kIsWeb) {
            final video = await GalleryVideoStorage.downloadForShare(
              item.url,
              cancelToken: token,
              headers: _accessHeaders(item.url),
              onUnauthorized: _onUnauthorized(item.url),
            );
            if (!mounted || _closing || token.isCancelled) return;
            await SharePlus.instance.share(
              ShareParams(
                files: [
                  XFile.fromData(
                    video.bytes,
                    name: video.name,
                    mimeType: video.mimeType,
                  ),
                ],
                fileNameOverrides: [video.name],
                sharePositionOrigin: origin,
              ),
            );
          } else {
            await GalleryVideoStorage.withDownloadedVideo(
              item.url,
              (path) async {
                if (!mounted || _closing) return;
                await SharePlus.instance.share(
                  ShareParams(
                    files: [XFile(path)],
                    sharePositionOrigin: origin,
                  ),
                );
              },
              cancelToken: token,
              headers: _accessHeaders(item.url),
              onUnauthorized: _onUnauthorized(item.url),
            );
          }
      }
    } catch (error) {
      if (mounted &&
          !_closing &&
          !(error is DioException && CancelToken.isCancel(error))) {
        AppToast.error(
          context,
          item is VideoPreviewItem
              ? l10n.mediaShareFailed
              : l10n.imageShareFailed,
        );
      }
    } finally {
      _videoShareToken = null;
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  void dispose() {
    _videoSaveToken?.cancel();
    _videoShareToken?.cancel();
    _pages.dispose();
    _thumbnails.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _close,
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              _select(_index - 1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              _select(_index + 1),
        },
        child: Focus(
          autofocus: true,
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedBuilder(
                  animation: widget.animation,
                  builder: (_, __) {
                    final intensity =
                        Curves.easeOutCubic.transform(widget.animation.value) *
                        (1 - _dismissProgress * .85);
                    return ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 6.5 * intensity,
                          sigmaY: 6.5 * intensity,
                        ),
                        child: ColoredBox(
                          key: const Key('image-preview-backdrop'),
                          color: const Color(
                            0x80333333,
                          ).withValues(alpha: .5 * intensity),
                        ),
                      ),
                    );
                  },
                ),
                PageView.builder(
                  key: const Key('asset-preview-gallery'),
                  controller: _pages,
                  itemCount: widget.items.length,
                  scrollBehavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      ...ScrollConfiguration.of(context).dragDevices,
                      PointerDeviceKind.mouse,
                    },
                  ),
                  physics: _zoomed || _dismissProgress > 0
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  onPageChanged: _changePage,
                  itemBuilder: (context, index) => HeroMode(
                    enabled: index == _index,
                    child: switch (widget.items[index]) {
                      ImagePreviewItem item => _ImagePage(
                        key: ValueKey(item.heroTag),
                        item: item,
                        active: index == _index,
                        onClose: _close,
                        onZoomChanged: (zoomed) {
                          if (index == _index) setState(() => _zoomed = zoomed);
                        },
                        onDismissProgress: (progress) {
                          if (index == _index) {
                            setState(() => _dismissProgress = progress);
                          }
                        },
                      ),
                      VideoPreviewItem item => _VideoGalleryPage(
                        key: ValueKey(item.heroTag),
                        item: item,
                        active: index == _index && !_closing,
                      ),
                    },
                  ),
                ),
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: SafeArea(
                    bottom: false,
                    child: Opacity(
                      opacity: 1 - _dismissProgress,
                      child: Row(
                        children: [
                          _PreviewButton(
                            buttonKey: const Key('asset-preview-close'),
                            tooltip: MaterialLocalizations.of(
                              context,
                            ).closeButtonTooltip,
                            asset: 'preview_close',
                            circular: true,
                            onPressed: _close,
                          ),
                          const Spacer(),
                          _PreviewButton(
                            buttonKey: const Key('asset-preview-download'),
                            tooltip: l10n.download,
                            asset: 'preview_download',
                            busy: _saving,
                            onPressed: _saving ? null : _download,
                          ),
                          const SizedBox(width: 10),
                          Builder(
                            builder: (buttonContext) => _PreviewButton(
                              buttonKey: const Key('asset-preview-share'),
                              tooltip: l10n.shareAction,
                              asset: 'preview_share',
                              busy: _sharing,
                              onPressed: _sharing
                                  ? null
                                  : () => _share(buttonContext),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.items.length > 1)
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: SafeArea(
                      top: false,
                      child: Center(
                        child: Opacity(
                          opacity: 1 - _dismissProgress,
                          child: SizedBox(
                            width: math.min(310, widget.items.length * 45 - 5),
                            height: 40,
                            child: ListView.builder(
                              key: const Key('asset-preview-thumbnails'),
                              controller: _thumbnails,
                              scrollDirection: Axis.horizontal,
                              itemExtent: 45,
                              itemCount: widget.items.length,
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.only(right: 5),
                                child: Semantics(
                                  button: true,
                                  selected: index == _index,
                                  label: l10n.mediaPreviewPosition(
                                    index + 1,
                                    widget.items.length,
                                  ),
                                  child: Tooltip(
                                    message: l10n.mediaPreviewPosition(
                                      index + 1,
                                      widget.items.length,
                                    ),
                                    child: InkWell(
                                      key: Key(
                                        'asset-preview-thumbnail-$index',
                                      ),
                                      onTap: () => _select(index),
                                      borderRadius: BorderRadius.circular(10),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: index == _index
                                                ? Colors.white
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        position: DecorationPosition.foreground,
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: _MediaThumbnail(
                                            item: widget.items[index],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaThumbnail extends StatelessWidget {
  const _MediaThumbnail({required this.item});
  final MediaPreviewItem item;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      if (item.previewImage case final image?)
        Image(
          image: image,
          fit: BoxFit.cover,
          frameBuilder: (_, child, frame, synchronous) =>
              frame != null || synchronous
              ? child
              : const AppSkeletonBox(width: 40, height: 40, radius: 10),
          errorBuilder: (_, __, ___) =>
              const ColoredBox(color: Color(0x80333333)),
        )
      else
        const ColoredBox(color: Color(0x80333333)),
      if (item is VideoPreviewItem)
        const Center(
          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
        ),
    ],
  );
}

class _VideoGalleryPage extends StatelessWidget {
  const _VideoGalleryPage({
    required this.item,
    required this.active,
    super.key,
  });
  final VideoPreviewItem item;
  final bool active;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    key: active ? const Key('asset-preview-video') : null,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 80, bottom: 80),
        child: Center(
          // Offscreen pages show only a poster, releasing their video player.
          child: active
              ? AppVideoPlayer(
                  url: item.url,
                  autoplay: true,
                  controlsKeyPrefix: 'video-preview',
                )
              : item.thumbnail != null
              ? Image(
                  image: item.thumbnail!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.play_circle_outline,
                    size: 64,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.play_circle_outline,
                  size: 64,
                  color: Colors.white,
                ),
        ),
      ),
    ),
  );
}

class _PreviewButton extends StatelessWidget {
  const _PreviewButton({
    required this.buttonKey,
    required this.tooltip,
    required this.asset,
    required this.onPressed,
    this.circular = false,
    this.busy = false,
  });

  final String tooltip;
  final Key buttonKey;
  final String asset;
  final VoidCallback? onPressed;
  final bool circular;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 40,
    child: IconButton(
      key: buttonKey,
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        padding: const EdgeInsets.all(10),
        backgroundColor: const Color(0x80333333),
        shape: circular
            ? const CircleBorder()
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : AppSvgIcon.asset(
              asset,
              size: circular ? 16 : 20,
              color: Colors.white,
            ),
    ),
  );
}

class _ImagePage extends StatefulWidget {
  const _ImagePage({
    required this.item,
    required this.active,
    required this.onClose,
    required this.onZoomChanged,
    required this.onDismissProgress,
    super.key,
  });

  final ImagePreviewItem item;
  final bool active;
  final VoidCallback onClose;
  final ValueChanged<bool> onZoomChanged;
  final ValueChanged<double> onDismissProgress;

  @override
  State<_ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<_ImagePage>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  final _pointers = <int>{};
  Drag? _pageDrag;
  ImageStream? _imageStream;
  Size? _imageSize;
  late final _imageListener = ImageStreamListener(
    (info, _) {
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      info.dispose();
      if (mounted && size != _imageSize) setState(() => _imageSize = size);
    },
    onError: (_, __) {}, // The image widget renders the failure state.
  );
  late final AnimationController _returnController;
  Offset _offset = Offset.zero;
  Offset _returnFrom = Offset.zero;
  Offset _pointerTravel = Offset.zero;
  Offset? _doubleTapPosition;
  bool _zoomed = false;
  bool _closing = false;
  bool _canDragDismiss = false;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    _returnController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 200),
        )..addListener(
          () => _setOffset(
            Offset.lerp(
              _returnFrom,
              Offset.zero,
              Curves.easeOutCubic.transform(_returnController.value),
            )!,
          ),
        );
    _transform.addListener(_onTransform);
  }

  void _setOffset(Offset offset) {
    setState(() => _offset = offset);
    widget.onDismissProgress(
      (offset.dy.abs() / MediaQuery.sizeOf(context).height).clamp(0.0, 1.0),
    );
  }

  void _onTransform() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) {
      setState(() {
        _zoomed = zoomed;
        _offset = Offset.zero;
      });
      widget.onZoomChanged(zoomed);
    }
  }

  @override
  void didUpdateWidget(_ImagePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) {
      _returnController.stop();
      _transform.removeListener(_onTransform);
      _transform.value = Matrix4.identity();
      _transform.addListener(_onTransform);
      _offset = Offset.zero;
      _zoomed = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = widget.item.image.resolve(
      createLocalImageConfiguration(context),
    );
    if (_imageStream?.key == stream.key) return;
    _imageStream?.removeListener(_imageListener);
    _imageStream = stream..addListener(_imageListener);
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    _returnController.stop();
    widget.onClose();
  }

  void _pointerDown(PointerDownEvent event) {
    _returnController.stop();
    _pointers.add(event.pointer);
    if (_pointers.length == 1) {
      _canDragDismiss = !_zoomed;
      _dragging = false;
      _pointerTravel = Offset.zero;
    } else {
      _canDragDismiss = false;
      _setOffset(Offset.zero);
    }
  }

  void _pointerMove(PointerMoveEvent event) {
    if (_closing || _zoomed || !_canDragDismiss || _pointers.length != 1) {
      return;
    }
    _pointerTravel += event.delta;
    if (!_dragging) {
      // Lock the gesture axis before moving the page, so swiping never dismisses it.
      if (_pointerTravel.dx.abs() > 8 &&
          _pointerTravel.dx.abs() >= _pointerTravel.dy.abs()) {
        _canDragDismiss = false;
        return;
      }
      if (_pointerTravel.dy.abs() <= 8 ||
          _pointerTravel.dy.abs() <= _pointerTravel.dx.abs()) {
        return;
      }
      _dragging = true;
      _setOffset(_pointerTravel);
    } else {
      _setOffset(_offset + event.delta);
    }
  }

  void _pointerEnd(PointerEvent event, {bool cancelled = false}) {
    _pointers.remove(event.pointer);
    if (_pointers.isNotEmpty || _zoomed || _offset == Offset.zero) return;
    if (!cancelled && _offset.dy > 100) {
      _close();
    } else {
      _returnFrom = _offset;
      if (MediaQuery.disableAnimationsOf(context)) {
        _setOffset(Offset.zero);
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
    _pageDrag?.cancel();
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
    return Listener(
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
              key: widget.active ? const Key('asset-preview-image') : null,
              transformationController: _transform,
              panEnabled: _zoomed,
              minScale: 1,
              maxScale: 4,
              child: GestureDetector(
                // The viewer's scale recognizer otherwise consumes mouse drags.
                supportedDevices: const {PointerDeviceKind.mouse},
                onHorizontalDragStart: _zoomed
                    ? null
                    : (details) {
                        _pageDrag = Scrollable.of(
                          context,
                          axis: Axis.horizontal,
                        ).position.drag(details, () => _pageDrag = null);
                      },
                onHorizontalDragUpdate: _zoomed
                    ? null
                    : (details) => _pageDrag?.update(details),
                onHorizontalDragEnd: _zoomed
                    ? null
                    : (details) => _pageDrag?.end(details),
                onHorizontalDragCancel: _zoomed
                    ? null
                    : () => _pageDrag?.cancel(),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = _imageSize == null
                        ? constraints.biggest
                        : applyBoxFit(
                            BoxFit.contain,
                            _imageSize!,
                            constraints.biggest,
                          ).destination;
                    return Center(
                      child: Hero(
                        tag: widget.item.heroTag,
                        child: Image(
                          image: widget.item.image,
                          width: size.width,
                          height: size.height,
                          fit: BoxFit.contain,
                          semanticLabel: widget.item.label ?? l10n.assetPreview,
                          frameBuilder: (_, child, frame, synchronous) =>
                              frame != null || synchronous
                              ? child
                              : const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white,
                              size: 32,
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
    );
  }
}
