import 'dart:math' as math;

import 'package:cupertino_context_menu_plus/cupertino_context_menu_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../type/menu_type.dart';
import 'app_modal_backdrop.dart';

export '../type/menu_type.dart';

const _menuIconSize = 20.0;

/// Displays a lifted preview with our shared menu on long press or right click.
class AppContextMenu extends StatefulWidget {
  const AppContextMenu({
    required this.label,
    required this.entries,
    required this.child,
    this.preview,
    this.enabled = true,
    super.key,
  });

  final String label;
  final List<AppMenuEntry> entries;
  final Widget child;
  final Widget? preview;
  final bool enabled;

  @override
  State<AppContextMenu> createState() => _AppContextMenuState();
}

class _AppContextMenuState extends State<AppContextMenu> {
  final _controller = CupertinoContextMenuPlusController();
  final _focusNode = FocusNode();
  final _sourceKey = GlobalKey();
  Size? _sourceSize;
  VoidCallback? _pendingAction;

  bool get _enabled => widget.enabled && widget.entries.isNotEmpty;

  void _measureSource() {
    final box = _sourceKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    _sourceSize = box.size;
  }

  void _open() {
    if (!_enabled || _controller.isOpen) return;
    _measureSource();
    _controller.open();
  }

  void _select(VoidCallback action) {
    if (_pendingAction != null) return;
    _pendingAction = action;
    _controller.close();
  }

  void _onMenuChanged() {
    if (_controller.isOpen) return;
    final action = _pendingAction;
    _pendingAction = null;
    if (action == null) return;
    // Finish removing the preview route before opening dialogs or changing rows.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _enabled) action();
    });
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onMenuChanged);
  }

  @override
  void didUpdateWidget(AppContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled && _controller.isOpen) _controller.close();
  }

  @override
  void dispose() {
    _controller.removeListener(_onMenuChanged);
    _pendingAction = null;
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    // The library requires positive durations even when motion is disabled.
    const instantTransition = Duration(microseconds: 1);
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.contextMenu): _open,
        const SingleActivator(LogicalKeyboardKey.f10, shift: true): _open,
      },
      child: Focus(
        focusNode: _focusNode,
        child: Semantics(
          tooltip: widget.label,
          onLongPress: _enabled ? _open : null,
          child: Listener(
            onPointerDown: _enabled ? (_) => _measureSource() : null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onLongPressStart: _enabled ? (_) => _open() : null,
              onSecondaryTapDown: _enabled ? (_) => _open() : null,
              child: SizedBox(
                key: _sourceKey,
                child: CupertinoContextMenuPlus.builder(
                  controller: _controller,
                  openGestureEnabled: _enabled,
                  showGrowAnimation: !reduceMotion,
                  previewLongPressTimeout: const Duration(milliseconds: 500),
                  backdropBlurSigma: AppModalBackdrop.blurSigma,
                  barrierColor: AppModalBackdrop.dimColor.withValues(alpha: .1),
                  modalTransitionDuration: reduceMotion
                      ? instantTransition
                      : AppModalBackdrop.enterDuration,
                  modalReverseTransitionDuration: reduceMotion
                      ? instantTransition
                      : AppModalBackdrop.exitDuration,
                  builder: (_, animation) => animation.value == 0
                      ? Material(
                          type: MaterialType.transparency,
                          child: widget.child,
                        )
                      : Material(
                          key: const Key('app-context-menu-preview'),
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          clipBehavior: Clip.antiAlias,
                          // Scale the original layout instead of reflowing it.
                          child: FittedBox(
                            child: SizedBox(
                              width: _sourceSize?.width,
                              height: _sourceSize?.height,
                              child: IgnorePointer(
                                child: widget.preview ?? widget.child,
                              ),
                            ),
                          ),
                        ),
                  bottomWidgetBuilder: (menuContext) => Theme(
                    data: theme,
                    child: AppMenuPanel(
                      entries: widget.entries,
                      maxHeight: math.max(
                        44,
                        size.height -
                            padding.vertical -
                            (_sourceSize?.height ?? 42) -
                            100,
                      ),
                      onSelected: _select,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders the same menu surface inside preview overlays and other menu hosts.
class AppMenuPanel extends StatelessWidget with _AppMenuAppearance {
  const AppMenuPanel({
    required this.entries,
    required this.onSelected,
    required this.maxHeight,
    super.key,
  });

  final List<AppMenuEntry> entries;
  final ValueChanged<VoidCallback> onSelected;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final maxWidth = _maxWidth(context);
    final style = _menuStyle(context, maxWidth);
    return Material(
      key: const Key('app-context-menu-panel'),
      color: _surfaceColor(context),
      surfaceTintColor: Colors.transparent,
      shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: .1),
      elevation: 3,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: maxWidth),
        child: SizedBox(
          width: _rootWidth(context, maxWidth, entries),
          child: SingleChildScrollView(
            primary: false,
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _buildEntries(
                context,
                entries,
                style,
                maxWidth,
                onSelected: onSelected,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Apple-inspired POPi menus with opaque surfaces and immediate interactions.
class AppMenuButton extends StatefulWidget {
  const AppMenuButton({
    required this.tooltip,
    required this.entries,
    this.icon = const Icon(Icons.more_horiz),
    this.size = 40,
    this.enabled = true,
    super.key,
  }) : assert(size > 0);

  final String tooltip;
  final List<AppMenuEntry> entries;
  final Widget icon;
  final double size;
  final bool enabled;

  @override
  State<AppMenuButton> createState() => _AppMenuButtonState();
}

class _AppMenuButtonState extends State<AppMenuButton> with _AppMenuAppearance {
  final _controller = MenuController();
  final _focusNode = FocusNode();
  LocalHistoryEntry? _historyEntry;
  bool _disposing = false;

  void _onOpen() {
    final route = ModalRoute.of(context);
    if (route == null) return;

    // Platform back closes the menu before navigating or closing the drawer.
    _historyEntry = LocalHistoryEntry(
      impliesAppBarDismissal: false,
      onRemove: () {
        _historyEntry = null;
        if (!_disposing && _controller.isOpen) _controller.close();
      },
    );
    route.addLocalHistoryEntry(_historyEntry!);
  }

  void _onClose() {
    final entry = _historyEntry;
    _historyEntry = null;
    entry?.remove();
  }

  @override
  void dispose() {
    _disposing = true;
    _onClose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = _maxWidth(context);
    final rootWidth = _rootWidth(context, maxWidth, widget.entries);
    final menuStyle = _menuStyle(context, maxWidth);

    return MenuAnchor(
      controller: _controller,
      childFocusNode: _focusNode,
      style: menuStyle.copyWith(
        alignment: AlignmentDirectional.bottomStart,
        fixedSize: WidgetStatePropertyAll(Size.fromWidth(rootWidth)),
      ),
      alignmentOffset: Offset(widget.size - rootWidth, 4),
      consumeOutsideTap: true,
      crossAxisUnconstrained: false,
      animated: false,
      onOpen: _onOpen,
      onClose: _onClose,
      menuChildren: _buildEntries(context, widget.entries, menuStyle, maxWidth),
      builder: (context, controller, child) => SizedBox.square(
        dimension: widget.size,
        child: IconButton(
          focusNode: _focusNode,
          tooltip: widget.tooltip,
          padding: EdgeInsets.zero,
          style: const ButtonStyle(
            animationDuration: Duration.zero,
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStatePropertyAll(Colors.transparent),
          ),
          constraints: BoxConstraints.tightFor(
            width: widget.size,
            height: widget.size,
          ),
          onPressed: widget.enabled && widget.entries.isNotEmpty
              ? () => controller.isOpen ? controller.close() : controller.open()
              : null,
          icon: widget.icon,
        ),
      ),
    );
  }
}

mixin _AppMenuAppearance {
  Color _surfaceColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHigh
        : theme.colorScheme.surface;
  }

  double _maxWidth(BuildContext context) =>
      math.min(320.0, math.max(0.0, MediaQuery.sizeOf(context).width - 32));

  MenuStyle _menuStyle(BuildContext context, double maxWidth) {
    final colors = Theme.of(context).colorScheme;
    return MenuStyle(
      backgroundColor: WidgetStatePropertyAll(_surfaceColor(context)),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shadowColor: WidgetStatePropertyAll(colors.shadow.withValues(alpha: .1)),
      elevation: const WidgetStatePropertyAll(3),
      padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
      minimumSize: WidgetStatePropertyAll(Size(math.min(120, maxWidth), 0)),
      maximumSize: WidgetStatePropertyAll(Size(maxWidth, double.infinity)),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
        ),
      ),
      visualDensity: VisualDensity.standard,
    );
  }

  double _rootWidth(
    BuildContext context,
    double maxWidth,
    List<AppMenuEntry> entries,
  ) {
    var width = 200.0;
    final selectionGutter = _hasSelection(entries) ? 32 : 0;
    for (final entry in entries) {
      final (label, icon, trailing) = switch (entry) {
        AppMenuItem() => (entry.label, entry.icon, false),
        AppSubmenu() => (entry.label, entry.icon, true),
        AppMenuDivider() => ('', null, false),
      };
      final painter = TextPainter(
        text: TextSpan(text: label, style: _textStyle(context)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      width = math.max(
        width,
        painter.width +
            40 +
            selectionGutter +
            (icon == null ? 0 : 32) +
            (trailing ? 30 : 0),
      );
      painter.dispose();
    }
    return math.min(width.ceilToDouble(), maxWidth);
  }

  bool _hasSelection(List<AppMenuEntry> entries) =>
      entries.any((entry) => entry is AppMenuItem && entry.selected);

  List<Widget> _buildEntries(
    BuildContext context,
    List<AppMenuEntry> entries,
    MenuStyle menuStyle,
    double maxWidth, {
    ValueChanged<VoidCallback>? onSelected,
  }) {
    final colors = Theme.of(context).colorScheme;
    final selectionGutter = _hasSelection(entries);
    return [
      for (final entry in entries)
        // Submenu panels use unconstrained intrinsic sizing internally.
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: math.max(0, maxWidth - 16)),
          child: switch (entry) {
            AppMenuItem() => Semantics(
              selected: entry.selected,
              child: MenuItemButton(
                key: entry.key,
                onPressed: entry.enabled && entry.onSelected != null
                    ? () {
                        if (onSelected == null) {
                          entry.onSelected!();
                        } else {
                          onSelected(entry.onSelected!);
                        }
                      }
                    : null,
                style: _itemStyle(
                  context,
                  selected: entry.selected,
                  destructive: entry.destructive,
                  foregroundColor: entry.foregroundColor,
                ),
                leadingIcon: selectionGutter
                    ? SizedBox.square(
                        dimension: _menuIconSize,
                        child: entry.selected
                            ? const Icon(Icons.check, size: _menuIconSize)
                            : null,
                      )
                    : null,
                trailingIcon: entry.icon == null
                    ? null
                    : SizedBox.square(
                        dimension: _menuIconSize,
                        child: entry.icon,
                      ),
                overflowAxis: Axis.vertical,
                child: Text(entry.label),
              ),
            ),
            AppSubmenu() => SubmenuButton(
              key: entry.key,
              style: _itemStyle(context),
              menuStyle: menuStyle,
              leadingIcon: selectionGutter
                  ? const SizedBox.square(dimension: _menuIconSize)
                  : null,
              trailingIcon: entry.icon == null
                  ? null
                  : SizedBox.square(
                      dimension: _menuIconSize,
                      child: entry.icon,
                    ),
              animated: false,
              submenuIcon: const WidgetStatePropertyAll(
                Icon(Icons.chevron_right, size: 18),
              ),
              menuChildren: entry.enabled
                  ? _buildEntries(
                      context,
                      entry.entries,
                      menuStyle,
                      maxWidth,
                      onSelected: onSelected,
                    )
                  : const [],
              child: Text(entry.label),
            ),
            AppMenuDivider() => Divider(
              key: entry.key,
              height: 13,
              thickness: .5,
              color: entry.color ?? colors.outlineVariant,
            ),
          },
        ),
    ];
  }

  TextStyle _textStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge!.copyWith(
        fontSize: 16,
        height: 22 / 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      );

  ButtonStyle _itemStyle(
    BuildContext context, {
    bool selected = false,
    bool destructive = false,
    Color? foregroundColor,
  }) {
    final colors = Theme.of(context).colorScheme;
    final foreground =
        foregroundColor ?? (destructive ? colors.error : colors.onSurface);
    final resolvedForeground = WidgetStateProperty.resolveWith<Color>(
      (states) => states.contains(WidgetState.disabled)
          ? colors.onSurface.withValues(alpha: .38)
          : foreground,
    );
    return ButtonStyle(
      foregroundColor: resolvedForeground,
      iconColor: resolvedForeground,
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) =>
            !states.contains(WidgetState.disabled) &&
                (selected ||
                    states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused) ||
                    states.contains(WidgetState.pressed))
            ? colors.onSurface.withValues(alpha: .06)
            : Colors.transparent,
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      animationDuration: Duration.zero,
      splashFactory: NoSplash.splashFactory,
      textStyle: WidgetStatePropertyAll(_textStyle(context)),
      iconSize: const WidgetStatePropertyAll(_menuIconSize),
      minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      alignment: AlignmentDirectional.centerStart,
      visualDensity: VisualDensity.standard,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
