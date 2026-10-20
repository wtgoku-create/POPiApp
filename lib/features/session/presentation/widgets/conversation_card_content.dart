import 'package:flutter/material.dart';

/// Bounds card documents without adding another viewport to embedded cards.
class ConversationCardContent extends StatefulWidget {
  const ConversationCardContent({
    required this.storageId,
    required this.child,
    this.maxViewportHeight = maxHeight,
    super.key,
  }) : assert(maxViewportHeight >= 160);

  static const maxHeight = 320.0;
  final String storageId;
  final Widget child;
  final double maxViewportHeight;

  @override
  State<ConversationCardContent> createState() =>
      _ConversationCardContentState();
}

class _ConversationCardContentState extends State<ConversationCardContent> {
  ScrollController? _scroll;
  PageStorageBucket? _storage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _storage = PageStorage.maybeOf(context);
    if (_scroll != null) return;
    final saved = _storage?.readState(context, identifier: widget.storageId);
    _scroll = _CardScrollController(
      onBoundaryFling: _forwardVelocity,
      initialScrollOffset: saved is double ? saved : 0,
    )..addListener(_saveOffset);
  }

  void _forwardVelocity(double velocity) {
    final parent = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    if (parent is! ScrollPositionWithSingleContext) return;
    final sameDirection =
        parent.axisDirection == _scroll!.position.axisDirection;
    parent.goBallistic(velocity * (sameDirection ? 1 : -1));
  }

  void _saveOffset() {
    if (!mounted || _scroll?.hasClients != true) return;
    _storage?.writeState(
      context,
      _scroll!.offset,
      identifier: widget.storageId,
    );
  }

  bool _forwardOverscroll(OverscrollNotification notification) {
    if (notification.depth != 0 || notification.overscroll == 0) return false;
    final parent = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    if (parent == null || !parent.hasContentDimensions) return false;
    final sameDirection =
        parent.axisDirection == notification.metrics.axisDirection;
    final delta = notification.overscroll * (sameDirection ? 1 : -1);
    final target = (parent.pixels + delta).clamp(
      parent.minScrollExtent,
      parent.maxScrollExtent,
    );
    if (target == parent.pixels) return false;
    // Forward only the distance the card could not consume at its boundary.
    parent.jumpTo(target);
    if (notification.dragDetails == null && notification.velocity != 0) {
      _forwardVelocity(notification.velocity);
    }
    return true;
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.dependOnInheritedWidgetOfExactType<_CardContentScope>() !=
        null) {
      return widget.child;
    }
    final height = (MediaQuery.sizeOf(context).height * .45).clamp(
      160.0,
      widget.maxViewportHeight,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: RawScrollbar(
          controller: _scroll,
          thumbVisibility: true,
          thickness: 3,
          radius: const Radius.circular(3),
          crossAxisMargin: 2,
          mainAxisMargin: 4,
          thumbColor: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: .24),
          notificationPredicate: (notification) =>
              notification.depth == 0 &&
              notification.metrics.axis == Axis.vertical,
          child: NotificationListener<OverscrollNotification>(
            onNotification: _forwardOverscroll,
            child: SingleChildScrollView(
              key: PageStorageKey(widget.storageId),
              controller: _scroll,
              primary: false,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(right: 12),
              child: _CardContentScope(child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Transfers release velocity when clamping physics stops at a card edge.
class _CardScrollController extends ScrollController {
  _CardScrollController({
    required this.onBoundaryFling,
    required super.initialScrollOffset,
  }) : super(keepScrollOffset: false);

  final ValueChanged<double> onBoundaryFling;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _CardScrollPosition(
    physics: physics,
    context: context,
    initialPixels: initialScrollOffset,
    oldPosition: oldPosition,
    onBoundaryFling: onBoundaryFling,
  );
}

class _CardScrollPosition extends ScrollPositionWithSingleContext {
  _CardScrollPosition({
    required super.physics,
    required super.context,
    required super.initialPixels,
    required super.oldPosition,
    required this.onBoundaryFling,
  }) : super(keepScrollOffset: false);

  final ValueChanged<double> onBoundaryFling;

  @override
  void goBallistic(double velocity) {
    if (hasContentDimensions &&
        ((velocity < 0 && pixels <= minScrollExtent) ||
            (velocity > 0 && pixels >= maxScrollExtent))) {
      onBoundaryFling(velocity);
      super.goBallistic(0);
      return;
    }
    super.goBallistic(velocity);
  }
}

class _CardContentScope extends InheritedWidget {
  const _CardContentScope({required super.child});

  @override
  bool updateShouldNotify(_CardContentScope oldWidget) => false;
}
