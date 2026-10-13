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
    _scroll = ScrollController(
      initialScrollOffset: saved is double ? saved : 0,
      keepScrollOffset: false,
    )..addListener(_saveOffset);
  }

  void _saveOffset() {
    if (!mounted || _scroll?.hasClients != true) return;
    _storage?.writeState(
      context,
      _scroll!.offset,
      identifier: widget.storageId,
    );
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
        child: Scrollbar(
          controller: _scroll,
          thumbVisibility: true,
          child: SingleChildScrollView(
            key: PageStorageKey(widget.storageId),
            controller: _scroll,
            primary: false,
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.only(right: 8),
            child: _CardContentScope(child: widget.child),
          ),
        ),
      ),
    );
  }
}

class _CardContentScope extends InheritedWidget {
  const _CardContentScope({required super.child});

  @override
  bool updateShouldNotify(_CardContentScope oldWidget) => false;
}
