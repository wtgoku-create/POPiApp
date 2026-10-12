import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_video_player.dart';

import 'support/fake_video_player.dart';

void main() {
  late FakeVideoPlayer platform;
  setUp(() {
    final original = VideoPlayerPlatform.instance;
    platform = FakeVideoPlayer();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = original);
  });

  Future<void> pumpPlayer(
    WidgetTester tester, {
    String path = 'video.mp4',
    bool autoplay = false,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AppVideoPlayer(
          url: Uri.parse('https://example.test/$path'),
          autoplay: autoplay,
        ),
      ),
    ),
  );

  testWidgets('playback controls hide, reveal and stay visible when paused', (
    tester,
  ) async {
    await pumpPlayer(tester, autoplay: true);
    await tester.pumpAndSettle();
    final play = find.byKey(const Key('video-player-play'));
    final controls = find.byKey(const Key('video-player-controls'));
    final surface = find.byKey(const Key('video-player-surface'));
    final bounds = tester.getRect(surface);
    expect(platform.playing, isTrue);
    expect(play, findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(play, findsNothing);
    expect(controls, findsNothing);
    expect(find.byType(VideoPlayer), findsOneWidget);
    await tester.tap(surface);
    await tester.pump();
    expect(platform.playing, isTrue);
    expect(play, findsOneWidget);
    expect(controls, findsOneWidget);
    // Tapping away from controls hides them without changing playback.
    await tester.tapAt(bounds.topLeft + const Offset(20, 20));
    await tester.pump();
    expect(play, findsNothing);
    expect(platform.playing, isTrue);
    await tester.tap(surface);
    await tester.pump();
    await tester.tap(play);
    await tester.pumpAndSettle();
    expect(platform.playing, isFalse);
    await tester.pump(const Duration(seconds: 4));
    expect(play, findsOneWidget);
    expect(controls, findsOneWidget);
    await tester.tap(play);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(play, findsNothing);
    expect(platform.playing, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('seeking keeps controls visible until the drag finishes', (
    tester,
  ) async {
    await pumpPlayer(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('video-player-play')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    final slider = tester.widget<Slider>(
      find.byKey(const Key('video-player-seek')),
    );
    slider.onChangeStart!(20);
    slider.onChanged!(30);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(const Key('video-player-controls')), findsOneWidget);
    slider.onChangeEnd!(30);
    await tester.pumpAndSettle();
    expect(platform.positions[1], const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const Key('video-player-controls')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing URL releases the previous player and resets playback', (
    tester,
  ) async {
    await pumpPlayer(tester, path: 'first.mp4');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('video-player-play')));
    await tester.pumpAndSettle();
    expect(platform.playing, isTrue);
    await pumpPlayer(tester, path: 'second.mp4');
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(platform.sources.map((source) => source.uri), [
      'https://example.test/first.mp4',
      'https://example.test/second.mp4',
    ]);
    expect(platform.disposed, [1]);
    expect(platform.playing, isFalse);
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(find.text('0:00 / 1:00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(platform.disposed, [1, 2]);
    expect(tester.takeException(), isNull);
  });
}
