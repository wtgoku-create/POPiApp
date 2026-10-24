import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/app_image_preview.dart';
import '../../domain/demo_models.dart';

/// An image deck that draws a card out before inserting it on the other side.
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

class _DemoImageStackState extends State<DemoImageStack>
    with SingleTickerProviderStateMixin {
  late int _index = widget.initialIndex.clamp(0, widget.images.length - 1);
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  double _drag = 0;
  int _direction = 0;
  bool _settling = false;

  int get _target => (_index - _direction).clamp(0, widget.images.length - 1);

  void _updateDrag(DragUpdateDetails details, double travel) {
    if (_settling) return;
    _drag = (_drag + details.delta.dx).clamp(-travel, travel);
    final direction = _drag < 0 ? -1 : 1;
    if (_index - direction < 0 || _index - direction >= widget.images.length) {
      setState(() {
        _drag = 0;
        _direction = 0;
        _motion.value = 0;
      });
      return;
    }
    setState(() {
      _direction = direction;
      if (!MediaQuery.disableAnimationsOf(context)) {
        _motion.value = math.asin(_drag.abs() / travel) / math.pi;
      }
    });
  }

  Future<void> _finishDrag({required bool commit}) async {
    if (_settling || _direction == 0) return;
    _settling = true;
    final target = _target;
    if (!MediaQuery.disableAnimationsOf(context)) {
      await _motion.animateTo(
        commit ? 1 : 0,
        duration: Duration(
          milliseconds: commit ? (560 * (1 - _motion.value)).round() : 180,
        ),
        curve: Curves.easeInOutCubic,
      );
      if (!mounted) return;
    }
    setState(() {
      if (commit) _index = target;
      _direction = 0;
      _drag = 0;
      _settling = false;
      _motion.value = 0;
    });
    if (commit) widget.onChanged(_index);
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _preview() {
    if (_settling) return;
    AppImagePreview.showGallery(
      context: context,
      initialIndex: _index,
      images: [
        for (final asset in widget.images)
          ImagePreviewItem(
            image: AssetImage(asset.cover),
            heroTag: 'message-${widget.messageId}-${asset.id}',
            label: asset.title,
          ),
      ],
    );
  }

  Widget _image(DemoAsset asset, double width, double height) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Image.asset(
      asset.cover,
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
        final travel = width * 1.3;
        return Listener(
          onPointerCancel: (_) => _finishDrag(commit: false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _preview,
            onHorizontalDragStart: (_) {
              if (!_settling) _drag = 0;
            },
            onHorizontalDragUpdate: (details) => _updateDrag(details, travel),
            onHorizontalDragEnd: (details) => _finishDrag(
              commit:
                  _drag.abs() > width * .22 ||
                  details.velocity.pixelsPerSecond.dx * _direction > 450,
            ),
            onHorizontalDragCancel: () => _finishDrag(commit: false),
            child: SizedBox(
              height: 315 * scale,
              child: AnimatedBuilder(
                animation: _motion,
                builder: (context, _) => _deck(width, height, scale, travel),
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _deck(double width, double height, double scale, double travel) {
    final count = widget.images.length;
    final maxDepth = math.min(count - 1, 4);
    final t = _motion.value;
    final progress = Curves.easeInOutCubic.transform(t);
    final movingIndex = _direction < 0 ? _index : _target;
    final movingBehind = _direction < 0 ? t >= .5 : t < .5;
    int depthOf(int index, int front) => (index - front + count) % count;
    final indices =
        <int>{
          for (var depth = 0; depth <= maxDepth; depth++)
            (_index + depth) % count,
          if (_direction != 0)
            for (var depth = 0; depth <= maxDepth; depth++)
              (_target + depth) % count,
        }.toList()..sort((a, b) {
          // Change paint order only after the moving card has cleared the deck.
          if (_direction != 0) {
            if (a == movingIndex) return movingBehind ? -1 : 1;
            if (b == movingIndex) return movingBehind ? 1 : -1;
          }
          return depthOf(b, _index).compareTo(depthOf(a, _index));
        });
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final index in indices)
          _card(
            index: index,
            width: width,
            height: height,
            scale: scale,
            travel: travel,
            before: depthOf(index, _index),
            after: depthOf(index, _target),
            maxDepth: maxDepth,
            progress: progress,
            lift: _direction != 0 && index == movingIndex
                ? math.sin(math.pi * t)
                : 0,
          ),
      ],
    );
  }

  Widget _card({
    required int index,
    required double width,
    required double height,
    required double scale,
    required double travel,
    required int before,
    required int after,
    required int maxDepth,
    required double progress,
    required double lift,
  }) {
    final start = math.min(before, maxDepth);
    final end = math.min(after, maxDepth);
    final depth = start + (end - start) * progress;
    final opacity =
        (before <= maxDepth ? 1.0 : 0.0) * (1 - progress) +
        (after <= maxDepth ? 1.0 : 0.0) * progress;
    return Positioned(
      key: ValueKey('deck-card-${widget.images[index].id}'),
      left: 0,
      top: 4 * scale,
      child: Transform.translate(
        offset: Offset(
          depth * 6 * scale + _direction * travel * lift,
          -16 * scale * lift,
        ),
        child: Transform.rotate(
          angle: depth * .035 + _direction * .17 * lift,
          alignment: Alignment.bottomCenter,
          child: Transform.scale(
            scale: 1 + .025 * lift,
            child: Opacity(
              opacity: opacity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .08 + .1 * lift),
                      blurRadius: 6 + 12 * lift,
                      offset: Offset(0, 2 + 6 * lift),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    _image(widget.images[index], width, height),
                    if (index == _index || index == _target)
                      Positioned(
                        top: 10 * scale,
                        right: 10 * scale,
                        child: _badge(index),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(int index) => Semantics(
    label: AppLocalizations.of(
      context,
    )!.mediaPreviewPosition(index + 1, widget.images.length),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: const ShapeDecoration(
        color: Colors.black26,
        shape: StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.copy_outlined, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(
            '${index + 1}/${widget.images.length}',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    ),
  );
}
