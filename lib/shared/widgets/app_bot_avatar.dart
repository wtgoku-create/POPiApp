import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../type/bot_avatar_type.dart';

/// Portable idle avatar with static rendering for reduced motion and failures.
class AppBotAvatar extends StatelessWidget {
  const AppBotAvatar({
    this.character = BotAvatarCharacter.tiger,
    this.size = 40,
    this.animated = true,
    super.key,
  });

  final BotAvatarCharacter character;
  final double size;
  final bool animated;

  @visibleForTesting
  static bool debugAnimationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    var animate = animated && !MediaQuery.disableAnimationsOf(context);
    assert(() {
      animate = animate && debugAnimationsEnabled;
      return true;
    }());
    Widget still() => Image.asset(
      character.stillAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      gaplessPlayback: true,
    );

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: !animate
            ? still()
            : Lottie.asset(
                character.animationAsset,
                key: ValueKey(character),
                width: size,
                height: size,
                fit: BoxFit.contain,
                frameRate: FrameRate.composition,
                repeat: true,
                animate: TickerMode.valuesOf(context).enabled,
                frameBuilder: (context, child, composition) =>
                    composition == null ? still() : child,
                errorBuilder: (context, error, stackTrace) => still(),
              ),
      ),
    );
  }
}
