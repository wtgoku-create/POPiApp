# Bot avatar Lottie

## Conversion

The source is a 512px PNG on a Three.js plane. GLSL replaces the original eyes
with animated capsules and applies small transforms. It is not a rigged 3D model.
Lottie cannot execute those shaders or the source pointer-following JavaScript.

The export bakes the shader's surrounding-skin sampling into an eye-free PNG,
embeds that PNG in the JSON, and reconstructs the two eyes as vector capsules.
Each character has one eight-second, 30fps idle loop: two natural blinks,
subtle gaze motion, floating, and a small rotation. The endpoints match.
Random blinking and live pointer tracking become a deterministic animation.
The original shading remains raster artwork, so these are hybrid Lottie files,
not fully vector illustrations. The other source expressions are not exported.

## Assets and Flutter

- `assets/animations/bot_avatars/{character}.json`: standalone Lottie, no external images.
- `assets/animations/bot_avatars/{character}.png`: static fallback with matching framing.
- `BotAvatarCharacter`: twelve character identifiers.
- `AppBotAvatar`: defaults to tiger; accepts `character`, `size`, and `animated`.

The avatar is used in the session welcome, session toolbar, and Demo's default
POPi member avatar. User photos and custom member artwork retain their own images.
The member editor offers all twelve characters; its thumbnails stay static while
the selected preview and saved avatar animate. The work-mode editor was removed.
Reduced motion shows a still. Inactive routes stop ticking through TickerMode.
Loading and decode failures show the still without changing layout.

```dart
const AppBotAvatar(character: BotAvatarCharacter.rabbit, size: 48)
```

## Rebuild

Requires Python 3 and Pillow. Keep the source PNGs and `eye-metadata.json` together:

```sh
python3 tool/convert_bot_avatars.py /path/to/POPi-ThreeJS-avatar-motion-v4-expressions
flutter pub get
flutter analyze
flutter test
```

For a native Flutter contact sheet, run:

```sh
BOT_AVATAR_QA_DIR=build/bot-avatar-qa flutter test test/app_bot_avatar_test.dart
```

The test loads all embedded images, renders every character, checks nonblank
frames, blink changes and matching loop endpoints, and exercises reduced motion
and character switching. The contact sheet is `build/bot-avatar-qa/all-characters.png`.
