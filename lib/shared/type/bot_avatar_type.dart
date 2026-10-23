/// The twelve source characters, each with one seamless idle animation.
enum BotAvatarCharacter {
  mouse,
  ox,
  tiger,
  rabbit,
  dragon,
  snake,
  horse,
  sheep,
  monkey,
  rooster,
  dog,
  pig;

  String get animationAsset => 'assets/animations/bot_avatars/$name.json';
  String get stillAsset => 'assets/animations/bot_avatars/$name.png';

  static BotAvatarCharacter? fromStillAsset(String asset) {
    for (final character in values) {
      if (character.stillAsset == asset) return character;
    }
    return null;
  }
}
