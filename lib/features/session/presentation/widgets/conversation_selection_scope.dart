import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A reply owns its selection while edge dragging scrolls the outer timeline.
class ConversationSelectionScope extends StatelessWidget {
  const ConversationSelectionScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      SelectionArea(child: _ScrollSelection(child: child));
}

class _ScrollSelection extends StatefulWidget {
  const _ScrollSelection({required this.child});

  final Widget child;

  @override
  State<_ScrollSelection> createState() => _ScrollSelectionState();
}

class _ScrollSelectionState extends State<_ScrollSelection> {
  final _delegate = _ReplySelectionDelegate();
  ValueListenable<SelectableRegionSelectionStatus>? _status;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _delegate.scrollable = Scrollable.maybeOf(context, axis: Axis.vertical);
    final status = SelectableRegionSelectionStatusScope.maybeOf(context);
    if (_status != status) {
      _status?.removeListener(_selectionStatusChanged);
      _status = status;
      _status?.addListener(_selectionStatusChanged);
    }
  }

  void _selectionStatusChanged() {
    if (_status?.value == SelectableRegionSelectionStatus.finalized) {
      _delegate.stopScrolling();
    }
  }

  @override
  void dispose() {
    _status?.removeListener(_selectionStatusChanged);
    _delegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SelectionContainer(delegate: _delegate, child: widget.child);
}

class _ReplySelectionDelegate extends StaticSelectionContainerDelegate {
  _ReplySelectionDelegate() {
    addListener(_updateVisibleHandles);
  }

  ScrollableState? _scrollable;
  ScrollPosition? _position;
  EdgeDraggingAutoScroller? _autoScroller;
  LayerLink? _startHandle;
  LayerLink? _endHandle;
  bool _handleUpdateScheduled = false;
  bool _disposed = false;

  set scrollable(ScrollableState? value) {
    if (value == _scrollable && value?.position == _position) return;
    stopScrolling();
    _position?.removeListener(_scheduleHandleUpdate);
    _scrollable = value;
    _position = value?.position;
    _position?.addListener(_scheduleHandleUpdate);
    _autoScroller = value == null
        ? null
        : EdgeDraggingAutoScroller(value, velocityScalar: 30);
  }

  void stopScrolling() => _autoScroller?.stopAutoScroll();

  @override
  void pushHandleLayers(LayerLink? startHandle, LayerLink? endHandle) {
    _startHandle = startHandle;
    _endHandle = endHandle;
    _updateVisibleHandles();
  }

  void _scheduleHandleUpdate() {
    if (_handleUpdateScheduled || _disposed) return;
    _handleUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleUpdateScheduled = false;
      if (!_disposed) _updateVisibleHandles();
    });
  }

  void _updateVisibleHandles() {
    if (_disposed) return;
    final scrollable = _scrollable;
    if (scrollable == null || (_startHandle == null && _endHandle == null)) {
      super.pushHandleLayers(_startHandle, _endHandle);
      return;
    }
    final viewport = scrollable.context.findRenderObject()! as RenderBox;
    final transform = getTransformTo(viewport);
    final visibleBounds = Offset.zero & viewport.size;
    bool visible(SelectionPoint? point) =>
        point != null &&
        visibleBounds.contains(
          MatrixUtils.transformPoint(transform, point.localPosition),
        );
    // Handle overlays are outside the scroll view's clip. Unlink offscreen
    // handles without discarding selection geometry needed by an active drag.
    super.pushHandleLayers(
      visible(value.startSelectionPoint) ? _startHandle : null,
      visible(value.endSelectionPoint) ? _endHandle : null,
    );
  }

  @override
  SelectionResult handleSelectionEdgeUpdate(SelectionEdgeUpdateEvent event) {
    // Scrolling moves every paragraph in screen space. Refresh both anchors
    // before reversing or entering a paragraph that still has cached edges.
    didReceiveSelectionBoundaryEvents();
    for (final selectable in selectables) {
      clearInternalSelectionStateForSelectable(selectable);
    }
    final result = super.handleSelectionEdgeUpdate(event);
    final scrollable = _scrollable;
    if (scrollable == null || result == SelectionResult.pending) {
      stopScrolling();
      return result;
    }
    final viewport = scrollable.context.findRenderObject()! as RenderBox;
    final bounds = MatrixUtils.transformRect(
      getTransformTo(viewport),
      Offset.zero & containerSize,
    );
    final pointer = viewport.globalToLocal(event.globalPosition);
    // Stop at this reply's boundary instead of revealing adjacent replies.
    if (!bounds.isFinite ||
        (pointer.dy < 0 && bounds.top >= 0) ||
        (pointer.dy > viewport.size.height &&
            bounds.bottom <= viewport.size.height)) {
      stopScrolling();
      return result;
    }
    // The auto-scroller compares against screen-space viewport bounds.
    _autoScroller!.startAutoScrollIfNecessary(
      Rect.fromCenter(center: event.globalPosition, width: 1, height: 1),
    );
    // SelectableRegion replays pending edge events as the content moves.
    return _autoScroller!.scrolling ? SelectionResult.pending : result;
  }

  @override
  SelectionResult handleClearSelection(ClearSelectionEvent event) {
    stopScrolling();
    return super.handleClearSelection(event);
  }

  @override
  void dispose() {
    _disposed = true;
    _position?.removeListener(_scheduleHandleUpdate);
    removeListener(_updateVisibleHandles);
    stopScrolling();
    super.dispose();
  }
}
