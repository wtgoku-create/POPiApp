import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_video_preview.dart';

import 'support/fake_video_player.dart';

void main() {
  const galleryChannel = MethodChannel('gal');
  late FakeVideoPlayer platform;
  setUp(() {
    final original = VideoPlayerPlatform.instance;
    platform = FakeVideoPlayer();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = original);
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(galleryChannel, null),
  );

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
    expect(platform.playing, isFalse);
    expect(find.byTooltip('Play'), findsOneWidget);
    await tester.tapAt(videoBounds.center);
    await tester.pumpAndSettle();
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

  testWidgets('denied download permission reports the error and allows retry', (
    tester,
  ) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(galleryChannel, (call) async {
          calls.add(call.method);
          return false;
        });
    await open(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('video-preview-download')));
    await tester.pumpAndSettle();
    expect(calls, ['hasAccess', 'requestAccess']);
    expect(
      find.text('Allow adding photos in system settings to save videos.'),
      findsOneWidget,
    );
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(platform.playing, isTrue);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('video-preview-download')))
          .onPressed,
      isNotNull,
    );
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'download prevents duplicate saves and can finish after closing',
    (tester) async {
      final access = Completer<bool>();
      var requests = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(galleryChannel, (call) async {
            if (call.method == 'hasAccess') {
              requests++;
              return access.future;
            }
            return false;
          });
      await open(tester);
      await tester.pumpAndSettle();
      final download = find.byKey(const Key('video-preview-download'));
      await tester.tap(download);
      await tester.pump();
      expect(tester.widget<IconButton>(download).onPressed, isNull);
      await tester.tap(download);
      await tester.pump();
      expect(requests, 1);
      await tester.tap(find.byKey(const Key('video-preview-close')));
      await tester.pumpAndSettle();
      access.complete(true);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('asset-preview-video')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (size, videoSize) in [
    (const Size(320, 568), const Size(1920, 1080)),
    (const Size(1024, 600), const Size(1920, 1080)),
    (const Size(320, 568), const Size(1080, 1920)),
    (const Size(1024, 600), const Size(1080, 1920)),
  ]) {
    testWidgets('player and floating controls fit $size / $videoSize', (
      tester,
    ) async {
      platform.videoSize = videoSize;
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
      final toolbar = tester.getRect(
        find.byKey(const Key('video-preview-controls')),
      );
      expect(video.contains(controls.topLeft), isTrue);
      expect(video.contains(controls.bottomRight), isTrue);
      expect(toolbar.bottom, closeTo(video.bottom - 8, .01));
      expect(video.contains(toolbar.topLeft), isTrue);
      expect(video.contains(toolbar.bottomRight), isTrue);
      final play = tester.getRect(find.byKey(const Key('video-preview-play')));
      expect(play.center.dx, closeTo(video.center.dx, .01));
      expect(play.center.dy, closeTo(video.center.dy, .01));
      final mute = tester.getRect(find.byKey(const Key('video-preview-mute')));
      expect(mute.center.dy, closeTo(controls.center.dy, .01));
      expect(
        tester
            .widget<SizedBox>(find.byKey(const Key('video-preview-controls')))
            .height,
        48,
      );
      final download = tester.getRect(
        find.byKey(const Key('video-preview-download')),
      );
      expect(download.right, closeTo(size.width - 20, .01));
      expect(download.bottom, closeTo(size.height - 20, .01));
      expect(download.overlaps(toolbar), isFalse);
      final button = tester.widget<IconButton>(
        find.byKey(const Key('video-preview-download')),
      );
      final shape = button.style!.shape!.resolve({})! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(12));
      expect(video.width, lessThanOrEqualTo(size.width));
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    });
  }
}
