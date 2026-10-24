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

  Widget _image(DemoAsset asset, double width, double height) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: DemoAssetImage(
      asset: asset,
      width: width,
      height: height,
      cacheWidth: 900,
      fit: BoxFit.cover,
      alignment: Alignment.centerRight,
    ),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 268,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / 268;
        final width = 225 * scale;
        final height = 300 * scale;
        return SizedBox(
          height: 315 * scale,
          child: Stack(
            children: [
              for (
                var depth = math.min(widget.images.length - 1, 4);
                depth > 0;
                depth--
              )
                Positioned(
                  left: depth * 6 * scale,
                  top: 4 * scale,
                  child: Transform.rotate(
                    angle: depth * .035,
                    alignment: Alignment.bottomCenter,
                    child: _image(
                      widget.images[(_index + depth) % widget.images.length],
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
                      child: GestureDetector(
                        onTap: _preview,
                        child: _image(widget.images[index], width, height),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 14 * scale,
                left: width - 66,
                child: IgnorePointer(
                  child: Semantics(
                    label: AppLocalizations.of(
                      context,
                    )!.mediaPreviewPosition(_index + 1, widget.images.length),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: const ShapeDecoration(
                        color: Colors.black26,
                        shape: StadiumBorder(),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.copy_outlined,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_index + 1}/${widget.images.length}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
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
