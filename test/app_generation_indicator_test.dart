import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/shared/widgets/app_generation_indicator.dart';

Future<Uint8List> _pixels(WidgetTester tester, GlobalKey key) async =>
    (await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      try {
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        return bytes!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    }))!;

// Every visible frame should be one continuous stroke, without detached dots.
int _components(Uint8List rgba, int width) {
  final pixels = <int>{
    for (var i = 0; i < rgba.length ~/ 4; i++)
      if (rgba[i * 4 + 3] > 32) i,
  };
  var count = 0;
  while (pixels.isNotEmpty) {
    count++;
    final pending = [pixels.first];
    pixels.remove(pending.single);
    while (pending.isNotEmpty) {
      final pixel = pending.removeLast();
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final x = pixel % width + dx;
          if (x < 0 || x >= width) continue;
          final neighbor = pixel + dy * width + dx;
          if (pixels.remove(neighbor)) pending.add(neighbor);
        }
      }
    }
  }
  return count;
}

void main() {
  testWidgets('stroke animates without dots, stops, and resumes', (
    tester,
  ) async {
    final boundary = GlobalKey();
    Future<void> pump(bool animated, {bool reducedMotion = false}) =>
        tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(disableAnimations: reducedMotion),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: RepaintBoundary(
                  key: boundary,
                  child: AppGenerationIndicator(animated: animated, size: 124),
                ),
              ),
            ),
          ),
        );

    await pump(true);
    final empty = await _pixels(tester, boundary);
    expect(_components(empty, 124), 0);
    Uint8List previous = empty;
    for (final duration in [250, 500, 250, 700]) {
      await tester.pump(Duration(milliseconds: duration));
      final current = await _pixels(tester, boundary);
      expect(current, isNot(orderedEquals(previous)));
      expect(_components(current, 124), 1);
      previous = current;
    }

    await pump(false);
    final stopped = await _pixels(tester, boundary);
    await tester.pump(const Duration(seconds: 3));
    expect(await _pixels(tester, boundary), orderedEquals(stopped));
    expect(tester.binding.hasScheduledFrame, isFalse);

    await pump(true);
    await tester.pump(const Duration(milliseconds: 250));
    expect(await _pixels(tester, boundary), isNot(orderedEquals(stopped)));
    await pump(true, reducedMotion: true);
    expect(await _pixels(tester, boundary), orderedEquals(stopped));
    await tester.pump(const Duration(seconds: 3));
    expect(await _pixels(tester, boundary), orderedEquals(stopped));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('capture animated glyph on task surface', (tester) async {
    if (!const bool.fromEnvironment('CAPTURE_GENERATION_INDICATOR')) return;
    final boundary = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: boundary,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFE0D2E5),
                    Color(0xFF579ED1),
                    Color(0xFFA764E3),
                  ],
                ),
              ),
              child: SizedBox(
                width: 360,
                height: 200,
                child: Center(child: AppGenerationIndicator(animated: true)),
              ),
            ),
          ),
        ),
      ),
    );
    for (final (index, duration) in [250, 500, 250, 700].indexed) {
      await tester.pump(Duration(milliseconds: duration));
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          'build/conversation-ux/generation-indicator-$index.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
