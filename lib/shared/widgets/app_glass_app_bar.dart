import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps the toolbar sharp over Figma's fixed, gradually fading glass surface.
class AppGlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppGlassAppBar({
    required this.child,
    this.extendBackdrop = true,
    super.key,
  });

  final PreferredSizeWidget child;
  final bool extendBackdrop;

  @override
  Size get preferredSize => child.preferredSize;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => AppGlassHeader(
      fadeExtent: extendBackdrop && constraints.maxHeight < 166
          ? 166 - constraints.maxHeight
          : 0,
      child: child,
    ),
  );
}

/// Applies the same glass to custom headers without changing their layout.
class AppGlassHeader extends StatelessWidget {
  const AppGlassHeader({required this.child, this.fadeExtent = 0, super.key});

  final Widget child;
  final double fadeExtent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overlay = theme.brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            bottom: -fadeExtent,
            child: const IgnorePointer(child: _TopBarBackdrop()),
          ),
          Theme(
            data: theme.copyWith(
              appBarTheme: theme.appBarTheme.copyWith(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                scrolledUnderElevation: 0,
                systemOverlayStyle: overlay,
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _TopBarBackdrop extends StatefulWidget {
  const _TopBarBackdrop();

  @override
  State<_TopBarBackdrop> createState() => _TopBarBackdropState();
}

class _TopBarBackdropState extends State<_TopBarBackdrop> {
  static Future<ui.FragmentProgram>? _program;
  static final _blur = ui.ImageFilter.blur(sigmaX: 9, sigmaY: 9);
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  Future<void> _loadShader() async {
    if (!ui.ImageFilter.isShaderFilterSupported) return;
    final program = await (_program ??= ui.FragmentProgram.fromAsset(
      'assets/shaders/app_top_bar_fade.frag',
    ));
    if (mounted) setState(() => _shader = program.fragmentShader());
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.brightness == Brightness.dark
        ? theme.colorScheme.surface
        : const Color(0xFFF5F4FA);
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shader = _shader;
          shader?.setFloat(
            2,
            constraints.maxHeight * MediaQuery.devicePixelRatioOf(context),
          );
          return BackdropFilter(
            filter: shader == null
                ? _blur
                : ui.ImageFilter.compose(
                    inner: _blur,
                    outer: ui.ImageFilter.shader(shader),
                  ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: .92),
                    color.withValues(alpha: .72),
                    color.withValues(alpha: 0),
                  ],
                  stops: const [.4, .6, 1],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}
