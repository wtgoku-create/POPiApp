import 'package:flutter/material.dart';

/// Draws the POPi generation glyph with the source SVG's 1.917-second timing.
/// Native painting keeps the stroke animation working on every Flutter platform.
class AppGenerationIndicator extends StatefulWidget {
  const AppGenerationIndicator({
    required this.animated,
    this.size = 60,
    this.color,
    super.key,
  });

  final bool animated;
  final double size;
  final Color? color;

  @override
  State<AppGenerationIndicator> createState() => _AppGenerationIndicatorState();
}

class _AppGenerationIndicatorState extends State<AppGenerationIndicator>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 1917),
  );
  late final _stroke = _controller.drive(
    TweenSequence<double>([
      for (var i = 0; i < _times.length - 1; i++)
        TweenSequenceItem(
          tween: Tween(begin: _lengths[i], end: _lengths[i + 1]),
          weight: _times[i + 1] - _times[i],
        ),
    ]),
  );
  static const _times = [0.0, .130435, .26087, .391304, .513043, .782609, 1.0];
  static const _lengths = [0.0, .16667, .33333, .5, .65556, 1.0, 1.0];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(AppGenerationIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (widget.animated &&
        !reducedMotion &&
        TickerMode.valuesOf(context).enabled) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      // Stopped tasks and reduced motion always show a complete, static glyph.
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.square(widget.size),
      painter: _GenerationGlyphPainter(stroke: _stroke, color: widget.color),
    ),
  );
}

class _GenerationGlyphPainter extends CustomPainter {
  _GenerationGlyphPainter({required this.stroke, required this.color})
    : super(repaint: stroke);

  final Animation<double> stroke;
  final Color? color;

  static final _path = Path()
    ..moveTo(12.87, 12.74)
    ..lineTo(10.64, 9.67)
    ..cubicTo(8.2, 6.49, 3, 8.17, 3, 12.14)
    ..lineTo(3, 19.86)
    ..cubicTo(3, 23.83, 8.2, 25.51, 10.64, 22.33)
    ..lineTo(20.36, 9.67)
    ..cubicTo(22.8, 6.49, 28, 8.17, 28, 12.14)
    ..lineTo(28, 19.86)
    ..cubicTo(28, 23.83, 22.8, 25.51, 20.36, 22.33)
    ..lineTo(17.81, 18.89);
  static final _metric = _path.computeMetrics().single;

  @override
  void paint(Canvas canvas, Size size) {
    final fraction = stroke.value;
    // Do not draw zero-length round caps: those become detached corner dots.
    if (fraction <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (color case final tint?) {
      paint.color = tint;
    } else {
      paint.shader = const LinearGradient(
        colors: [Colors.white, Color(0x80FFFFFF)],
      ).createShader(const Rect.fromLTRB(1.77, 0, 29.23, 31));
    }
    canvas.save();
    canvas.scale(size.width / 31, size.height / 31);
    canvas.drawPath(
      fraction >= 1 ? _path : _metric.extractPath(0, _metric.length * fraction),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GenerationGlyphPainter oldDelegate) =>
      oldDelegate.stroke != stroke || oldDelegate.color != color;
}
