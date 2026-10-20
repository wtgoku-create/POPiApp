import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Bounds card documents without adding another viewport to embedded cards.
class ConversationCardContent extends StatefulWidget {
  const ConversationCardContent({
    required this.storageId,
    required this.child,
    this.maxViewportHeight = maxHeight,
    this.followTail = false,
    super.key,
  }) : assert(maxViewportHeight >= 160);

  static const maxHeight = 320.0;
  final String storageId;
  final Widget child;
  final double maxViewportHeight;
  final bool followTail;

  @override
  State<ConversationCardContent> createState() =>
      _ConversationCardContentState();
}

class _ConversationCardContentState extends State<ConversationCardContent> {
  ScrollController? _scroll;
  PageStorageBucket? _storage;
  bool _followTail = false;
  bool _tailScrollScheduled = false;
  bool _adjustingTail = false;

  String get _followStorageId => '${widget.storageId}:follow-tail';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _storage = PageStorage.maybeOf(context);
    if (_scroll != null) return;
    final saved = _storage?.readState(context, identifier: widget.storageId);
    _followTail =
        widget.followTail &&
        _storage?.readState(context, identifier: _followStorageId) != false;
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
    if (widget.followTail) {
      _storage?.writeState(context, _followTail, identifier: _followStorageId);
    }
  }

  void _scheduleTailScroll() {
    if (!_followTail || _tailScrollScheduled) return;
    _tailScrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tailScrollScheduled = false;
      if (!mounted || !_followTail || _scroll?.hasClients != true) return;
      final position = _scroll!.position;
      if (position.isScrollingNotifier.value) return;
      if ((position.maxScrollExtent - position.pixels).abs() > 1) {
        _adjustingTail = true;
        try {
          _scroll!.jumpTo(position.maxScrollExtent);
        } finally {
          _adjustingTail = false;
        }
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _handleScroll(ScrollNotification notification) {
    if (!widget.followTail || notification.depth != 0) return false;
    if (notification is UserScrollNotification &&
        notification.direction == ScrollDirection.forward) {
      _followTail = false;
    } else if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      if (notification is ScrollUpdateNotification &&
          !_adjustingTail &&
          (notification.scrollDelta ?? 0) < 0) {
        _followTail = false;
      }
      if (notification.metrics.extentAfter <= 1) _followTail = true;
      if (notification is ScrollEndNotification) _scheduleTailScroll();
    }
    _saveOffset();
    return false;
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
    _scheduleTailScroll();
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
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (notification) {
              if (notification.depth == 0) _scheduleTailScroll();
              return false;
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScroll,
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
