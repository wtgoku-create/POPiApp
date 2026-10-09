import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_video_preview.dart';

import 'support/fake_video_player.dart';

void main() {
  late FakeVideoPlayer platform;
  setUp(() {
    final original = VideoPlayerPlatform.instance;
    platform = FakeVideoPlayer();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = original);
  });

  Future<void> open(WidgetTester tester, {bool reduceMotion = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            key: const Key('underlying-screen'),
            body: TextButton(
              onPressed: () => AppVideoPreview.show(
                context: context,
                url: Uri.parse('https://example.test/video.mp4'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
  }

  testWidgets('opens above the current screen on a preview overlay', (
    tester,
  ) async {
    await open(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('underlying-screen')), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
    final videoBounds = tester.getRect(find.byType(VideoPlayer));
    await tester.tapAt(videoBounds.center);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('asset-preview-video')), findsOneWidget);
    expect(platform.playing, isTrue);
    expect(tester.getRect(find.byType(VideoPlayer)), videoBounds);
    final route = ModalRoute.of(
      tester.element(find.byKey(const Key('asset-preview-video'))),
    )!;
    expect(route.opaque, isFalse);
    expect(route.transitionDuration, const Duration(milliseconds: 300));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 220));
    await tester.tap(find.byKey(const Key('video-preview-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('underlying-screen')), findsOneWidget);
  });

  testWidgets('preview respects reduced motion', (tester) async {
    await open(tester, reduceMotion: true);
    await tester.pumpAndSettle();
    final route = ModalRoute.of(
      tester.element(find.byKey(const Key('asset-preview-video'))),
    )!;
    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  });

  testWidgets('loads, plays, seeks, mutes and releases video on close', (
    tester,
  ) async {
    platform.autoInitialize = false;
    await open(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(platform.sources.single.uri, 'https://example.test/video.mp4');
    platform.initialize(1);
    await tester.pumpAndSettle();
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(platform.playing, isTrue);
    await tester.tap(find.byKey(const Key('video-preview-play')));
    await tester.pumpAndSettle();
    expect(platform.playing, isFalse);
    await tester.tap(find.byKey(const Key('video-preview-mute')));
    await tester.pumpAndSettle();
    expect(platform.volume, 0);
    final slider = tester.widget<Slider>(
      find.byKey(const Key('video-preview-seek')),
    );
    slider.onChanged!(30);
    slider.onChangeEnd!(30);
    await tester.pumpAndSettle();
    expect(platform.positions[1], const Duration(seconds: 30));
    await tester.tap(find.byKey(const Key('video-preview-play')));
    await tester.pumpAndSettle();
    expect(platform.playing, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(platform.playing, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.tap(find.byKey(const Key('video-preview-close')));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(find.byKey(const Key('asset-preview-video')), findsNothing);
    expect(platform.disposed, [1]);
    expect(find.byKey(const Key('asset-preview-video')), findsNothing);
  });

  testWidgets(
    'playback failure can retry and platform back disposes the player',
    (tester) async {
      platform.failNext = true;
      await open(tester);
      await tester.pumpAndSettle();
      expect(find.text('Could not play this video'), findsOneWidget);
      await tester.tap(find.byKey(const Key('video-preview-retry')));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.byType(VideoPlayer), findsOneWidget);
      expect(platform.disposed, [1]);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(platform.disposed, [1, 2]);
    },
  );

  testWidgets('closing while initializing releases the native player', (
    tester,
  ) async {
    platform.autoInitialize = false;
    await open(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const Key('video-preview-close')));
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(platform.disposed, [1]);
    expect(platform.playing, isFalse);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(1024, 600)]) {
    testWidgets('player and controls fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester);
      await tester.pumpAndSettle();
      final video = tester.getRect(
        find.byKey(const Key('native-video-surface')),
      );
      final controls = tester.getRect(
        find.byKey(const Key('video-preview-seek')),
      );
      expect(video.bottom, lessThanOrEqualTo(controls.top));
      expect(video.width, lessThanOrEqualTo(size.width));
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    });
  }
}
