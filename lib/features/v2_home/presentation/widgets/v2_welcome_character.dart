import 'package:flutter/material.dart';

/// The visible 2560:6666 body-sway track exported from the Figma welcome page.
class V2WelcomeCharacter extends StatefulWidget {
  const V2WelcomeCharacter({super.key});
  @override
  State<V2WelcomeCharacter> createState() => _V2WelcomeCharacterState();
}

class _V2WelcomeCharacterState extends State<V2WelcomeCharacter>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  static const _angles = <double>[
    0,
    0,
    0,
    .001,
    .001,
    .002,
    .003,
    .004,
    .006,
    .007,
    .009,
    .010,
    .012,
    .013,
    .014,
    .015,
    .016,
    .017,
    .017,
    .017,
    .017,
    .017,
    .017,
    .016,
    .015,
    .014,
    .013,
    .011,
    .009,
    .007,
    .004,
    .002,
    -.001,
    -.003,
    -.005,
    -.007,
    -.009,
    -.011,
    -.012,
    -.013,
    -.014,
    -.015,
    -.015,
    -.015,
    -.015,
    -.014,
    -.013,
    -.012,
    -.011,
    -.009,
    -.007,
    -.006,
    -.003,
    -.001,
    .001,
    .003,
    .004,
    .006,
    .007,
    .008,
    .009,
    .009,
    .009,
    .009,
    .010,
    .009,
    .009,
    .008,
    .007,
    .006,
    .006,
    .005,
    .004,
    .003,
    .002,
    .002,
    .001,
    .001,
    0,
    0,
    0,
  ];
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: ClipRect(
      child: FractionallySizedBox(
        widthFactor: 204 / 184,
        heightFactor: 232 / 222,
        child: Image.asset(
          'assets/images/demo_new_character.png',
          fit: BoxFit.fill,
          excludeFromSemantics: true,
          cacheWidth: 612,
        ),
      ),
    ),
    builder: (_, child) {
      final frame = _controller.value * 80;
      final index = frame.floor().clamp(0, 79);
      final angle =
          _angles[index] +
          (_angles[index + 1] - _angles[index]) * (frame - index);
      return Transform.rotate(angle: angle, child: child);
    },
  );
}
