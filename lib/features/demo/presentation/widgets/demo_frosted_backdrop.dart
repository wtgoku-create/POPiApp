import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Fades one native blur continuously, without slicing the backdrop into bands.
class DemoFrostedBackdrop extends StatefulWidget {
  const DemoFrostedBackdrop({super.key});

  static Future<ui.FragmentProgram>? _program;

  static Future<void> precache() async {
    if (ui.ImageFilter.isShaderFilterSupported) {
      await (_program ??= ui.FragmentProgram.fromAsset(
        'assets/shaders/demo_backdrop_fade.frag',
      ));
    }
  }

  @override
  State<DemoFrostedBackdrop> createState() => _DemoFrostedBackdropState();
}

class _DemoFrostedBackdropState extends State<DemoFrostedBackdrop> {
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!ui.ImageFilter.isShaderFilterSupported) return;
    await DemoFrostedBackdrop.precache();
    if (!mounted) return;
    final program = await DemoFrostedBackdrop._program!;
    if (!mounted) return;
    setState(() => _shader = program.fragmentShader());
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final shader = _shader;
        final blur = ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18);
        if (shader != null) {
          // The engine supplies texture size and sampler; height uses physical pixels.
          shader.setFloat(
            2,
            constraints.maxHeight * MediaQuery.devicePixelRatioOf(context),
          );
        }
        final color = Theme.of(context).scaffoldBackgroundColor;
        return BackdropFilter(
          filter: shader == null
              ? blur
              : ui.ImageFilter.compose(
                  inner: blur,
                  outer: ui.ImageFilter.shader(shader),
                ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0),
                  color.withValues(alpha: .08),
                  color.withValues(alpha: .28),
                  color.withValues(alpha: .5),
                  color.withValues(alpha: .55),
                ],
                stops: const [0, .25, .5, .75, 1],
              ),
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    ),
  );
}
