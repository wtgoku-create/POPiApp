import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:popi_ai_app/shared/type/bot_avatar_type.dart';
import 'package:popi_ai_app/shared/widgets/app_bot_avatar.dart';

void main() {
  testWidgets(
    'all twelve portable animations render and blink without warnings',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(const Color(0xFFF1F3F4), BlendMode.src);
        for (final (index, character) in BotAvatarCharacter.values.indexed) {
          final animation =
              jsonDecode(await rootBundle.loadString(character.animationAsset))
                  as Map<String, Object?>;
          _expectClosedTracks(
            animation,
            character.name,
            (animation['op'] as num).toDouble(),
          );
          final composition = await AssetLottie(
            character.animationAsset,
          ).load();
          expect(composition.duration, const Duration(seconds: 8));
          expect(composition.frameRate, 30);
          expect(composition.images.values.single.loadedImage, isNotNull);
          expect(composition.warnings, isEmpty, reason: character.name);
          final drawable = LottieDrawable(composition);
          final first = await _render(drawable, 0);
          final blink = await _render(drawable, 2.8 / 8);
          final loop = await _render(drawable, 1);
          expect(first, isNot(orderedEquals(blink)), reason: character.name);
          expect(loop.length, first.length);
          var maxChannelDelta = 0;
          for (var i = 0; i < first.length; i++) {
            final delta = (first[i] - loop[i]).abs();
            if (delta > maxChannelDelta) maxChannelDelta = delta;
          }
          // Rasterizers can round identical keyframes to adjacent 8-bit values.
          expect(
            maxChannelDelta,
            lessThanOrEqualTo(1),
            reason: '${character.name} loop channel delta',
          );
          final opaquePixels = first.where((byte) => byte > 0).length;
          expect(opaquePixels, greaterThan(10000), reason: character.name);
          drawable.setProgress(0);
          canvas.save();
          canvas.translate((index % 4) * 256, (index ~/ 4) * 256);
          drawable.draw(canvas, const Rect.fromLTWH(0, 0, 256, 256));
          canvas.restore();
        }
        final picture = recorder.endRecording();
        final image = await picture.toImage(1024, 768);
        final qaDirectory = Platform.environment['BOT_AVATAR_QA_DIR'];
        if (qaDirectory != null) {
          final output = File('$qaDirectory/all-characters.png');
          await output.parent.create(recursive: true);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await output.writeAsBytes(data!.buffer.asUint8List());
        }
        image.dispose();
        picture.dispose();
      });
    },
  );

  testWidgets('default tiger keeps its size and respects reduced motion', (
    tester,
  ) async {
    AppBotAvatar.debugAnimationsEnabled = true;
    addTearDown(() => AppBotAvatar.debugAnimationsEnabled = false);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(child: AppBotAvatar(size: 64)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AppBotAvatar)), const Size.square(64));
    expect(find.byType(LottieBuilder), findsNothing);
    expect(
      (tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName,
      BotAvatarCharacter.tiger.stillAsset,
    );
  });

  testWidgets('character switching and inactive routes retain bounded layout', (
    tester,
  ) async {
    AppBotAvatar.debugAnimationsEnabled = true;
    addTearDown(() => AppBotAvatar.debugAnimationsEnabled = false);
    Widget host(BotAvatarCharacter character, bool enabled) => MaterialApp(
      home: TickerMode(
        enabled: enabled,
        child: Center(child: AppBotAvatar(character: character, size: 48)),
      ),
    );
    await tester.pumpWidget(host(BotAvatarCharacter.tiger, true));
    expect(
      tester.widget<LottieBuilder>(find.byType(LottieBuilder)).animate,
      true,
    );
    await tester.pumpWidget(host(BotAvatarCharacter.rabbit, false));
    final lottie = tester.widget<LottieBuilder>(find.byType(LottieBuilder));
    expect(
      (lottie.lottie as AssetLottie).assetName,
      BotAvatarCharacter.rabbit.animationAsset,
    );
    expect(lottie.animate, false);
    expect(tester.getSize(find.byType(AppBotAvatar)), const Size.square(48));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}

void _expectClosedTracks(Object? node, String path, double endFrame) {
  if (node is Map<String, Object?>) {
    if (node['a'] == 1 && node['k'] is List<Object?>) {
      final frames = node['k'] as List<Object?>;
      expect(frames.length, greaterThanOrEqualTo(2), reason: path);
      final first = frames.first as Map<String, Object?>;
      final last = frames.last as Map<String, Object?>;
      final held = frames[frames.length - 2] as Map<String, Object?>;
      expect(last['s'], first['s'], reason: '$path endpoints');
      expect(held['s'], first['s'], reason: '$path final hold');
      expect(
        (held['t'] as num).toDouble(),
        lessThanOrEqualTo(endFrame - 1),
        reason: '$path holds through the final displayed frame',
      );
      return;
    }
    for (final entry in node.entries) {
      _expectClosedTracks(entry.value, '$path.${entry.key}', endFrame);
    }
  } else if (node is List<Object?>) {
    for (var i = 0; i < node.length; i++) {
      _expectClosedTracks(node[i], '$path[$i]', endFrame);
    }
  }
}

Future<List<int>> _render(LottieDrawable drawable, double progress) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  drawable.setProgress(progress);
  drawable.draw(canvas, const Rect.fromLTWH(0, 0, 128, 128));
  final picture = recorder.endRecording();
  final image = await picture.toImage(128, 128);
  final bytes = await image.toByteData();
  final result = bytes!.buffer.asUint8List().toList();
  image.dispose();
  picture.dispose();
  return result;
}
