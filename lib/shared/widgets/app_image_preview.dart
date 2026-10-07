import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

import '../../core/storage/gallery_image_storage.dart';
import '../../l10n/generated/app_localizations.dart';
import 'app_toast.dart';

/// Displays an image above the current screen with a shared thumbnail transition.
abstract final class AppImagePreview {
  static Future<void> show({
    required BuildContext context,
    required ImageProvider image,
    required Object heroTag,
    String? label,
  }) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 300),
        reverseTransitionDuration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 220),
        pageBuilder: (_, animation, __) => _ImagePreview(
          image: image,
          heroTag: heroTag,
          label: label,
          animation: animation,
        ),
        transitionsBuilder: (_, __, ___, child) => child,
      ),
    );
  }
}

class _ImagePreview extends StatefulWidget {
  const _ImagePreview({
    required this.image,
    required this.heroTag,
    required this.animation,
    this.label,
  });
  final ImageProvider image;
  final Object heroTag;
  final String? label;
  final Animation<double> animation;

  @override
  State<_ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<_ImagePreview>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  final _pointers = <int>{};
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
        widget.image,
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

  void _close() {
    if (_closing) return;
    _closing = true;
    _returnController.stop();
    _transform.value = Matrix4.identity();
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
                      child: Hero(
                        tag: widget.heroTag,
                        child: Image(
                          image: widget.image,
                          fit: BoxFit.contain,
                          semanticLabel: widget.label ?? l10n.assetPreview,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              l10n.networkRequestFailed,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
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
                      key: const Key('asset-preview-download'),
                      tooltip: l10n.download,
                      onPressed: _saving ? null : _download,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: .15),
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
                              Icons.download_outlined,
                              color: Colors.white,
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
