import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// Loads one page near the bottom, suppressing automatic retries in a gesture.
class AppPagedScroll extends StatefulWidget {
  const AppPagedScroll({required this.onLoad, required this.child, super.key});

  final Future<void> Function() onLoad;
  final Widget child;

  @override
  State<AppPagedScroll> createState() => _AppPagedScrollState();
}

class _AppPagedScrollState extends State<AppPagedScroll> {
  bool _failed = false;
  bool _pending = false;
  ScrollMetrics? _metrics;

  Future<void> _load() async {
    if (_failed || _pending) return;
    _pending = true;
    try {
      await widget.onLoad();
    } catch (_) {
      _failed = true;
    } finally {
      _pending = false;
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerSignal: (event) {
      if (event is PointerScrollEvent &&
          event.scrollDelta.dy > 0 &&
          _metrics != null &&
          _metrics!.extentAfter < 200) {
        // An empty filtered page cannot scroll; let an unhandled wheel load it.
        GestureBinding.instance.pointerSignalResolver.register(event, (_) {
          _failed = false;
          _load();
        });
      }
    },
    child: NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        if (notification.depth == 0) _metrics = notification.metrics;
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth != 0) return false;
          _metrics = notification.metrics;
          if (notification is ScrollStartNotification) _failed = false;
          final advancing =
              notification is ScrollUpdateNotification &&
                  (notification.scrollDelta ?? 0) > 0 ||
              notification is OverscrollNotification &&
                  notification.overscroll > 0;
          if (advancing && notification.metrics.extentAfter < 200) _load();
          return false;
        },
        child: widget.child,
      ),
    ),
  );
}
