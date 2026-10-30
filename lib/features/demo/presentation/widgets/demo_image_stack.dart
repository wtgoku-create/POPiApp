import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_image_preview.dart';
import '../../domain/demo_models.dart';
import '../demo_remote_media.dart';

/// A paged image deck that opens the gallery at the visible image.
class DemoImageStack extends StatefulWidget {
  const DemoImageStack({
    required this.images,
    required this.messageId,
    required this.initialIndex,
    required this.onChanged,
    super.key,
  }) : assert(images.length > 1);

  final List<DemoAsset> images;
  final String messageId;
  final int initialIndex;
  final ValueChanged<int> onChanged;

  @override
  State<DemoImageStack> createState() => _DemoImageStackState();
}

class _DemoImageStackState extends State<DemoImageStack> {
  late int _index = widget.initialIndex.clamp(0, widget.images.length - 1);
  late final _pages = PageController(initialPage: _index, keepPage: false);
  late final double _frameAspect = _resolveFrameAspect(widget.images.first);

  static double _resolveFrameAspect(DemoAsset asset) {
    if (asset.width <= 0 || asset.height <= 0) return 4 / 3;
    return (asset.width / asset.height).clamp(.75, 16 / 9).toDouble();
  }

  @override
  void didUpdateWidget(covariant DemoImageStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.images.map((asset) => asset.id).toList();
    final nextIds = widget.images.map((asset) => asset.id).toList();
    final imagesChanged =
        oldIds.length != nextIds.length ||
        Iterable<int>.generate(
          oldIds.length,
        ).any((index) => oldIds[index] != nextIds[index]);
    var nextIndex = _index.clamp(0, widget.images.length - 1);
    if (imagesChanged) {
      final oldIndex = _index.clamp(0, oldWidget.images.length - 1);
      final visibleId = oldWidget.images[oldIndex].id;
      final preservedIndex = widget.images.indexWhere(
        (asset) => asset.id == visibleId,
      );
      nextIndex = preservedIndex >= 0
          ? preservedIndex
          : widget.initialIndex.clamp(0, widget.images.length - 1);
    } else if (oldWidget.initialIndex != widget.initialIndex) {
      nextIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    }
    if (nextIndex == _index) return;
    _index = nextIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pages.hasClients) _pages.jumpToPage(nextIndex);
      widget.onChanged(nextIndex);
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _preview() => AppImagePreview.showGallery(
    context: context,
    initialIndex: _index,
    images: [
      for (final asset in widget.images)
        ImagePreviewItem(
          image: demoAssetImageProviderForContext(context, asset),
          heroTag: 'message-${widget.messageId}-${asset.id}',
          label: asset.title,
        ),
    ],
  );

  Widget _image(
    BuildContext context,
    DemoAsset asset,
    double width,
    double height,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: dark ? .5 : .36),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .2 : .1),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: DemoAssetImage(
        asset: asset,
        width: width,
        height: height,
        cacheWidth: 900,
        fit: BoxFit.contain,
        alignment: Alignment.center,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 268,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / 268;
        final width = 225 * scale;
        final height = width / _frameAspect;
        final deckHeight = height + 32 * scale;
        final captionHeight = math.max(
          28.0,
          MediaQuery.textScalerOf(context).scale(14) * (20 / 14) + 8,
        );
        return SizedBox(
          height: deckHeight + captionHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: deckHeight,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _preview,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (
                        var depth = math.min(widget.images.length - 1, 3);
                        depth > 0;
                        depth--
                      )
                        Positioned(
                          key: ValueKey('demo-image-stack-rear-$depth'),
                          left: depth * 7.5 * scale,
                          top: (3 + depth * 4) * scale,
                          child: Transform.rotate(
                            angle: depth * .018,
                            alignment: Alignment.bottomLeft,
                            child: _image(
                              context,
                              widget.images[(_index + depth) %
                                  widget.images.length],
                              width,
                              height,
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: PageView.builder(
                          controller: _pages,
                          itemCount: widget.images.length,
                          onPageChanged: (index) {
                            setState(() => _index = index);
                            widget.onChanged(index);
                          },
                          itemBuilder: (context, index) => Align(
                            alignment: Alignment.topLeft,
                            child: Padding(
                              padding: EdgeInsets.only(top: 4 * scale),
                              child: _image(
                                context,
                                widget.images[index],
                                width,
                                height,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: captionHeight,
                child: Semantics(
                  label: AppLocalizations.of(
                    context,
                  )!.mediaPreviewPosition(_index + 1, widget.images.length),
                  child: ExcludeSemantics(
                    child: Row(
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(
                              context,
                            )!.demoImageStackCount(widget.images.length),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                              height: 20 / 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_index + 1}/${widget.images.length}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                            height: 20 / 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
