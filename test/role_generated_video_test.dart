import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/role_guide/presentation/widgets/role_generated_video.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_video_player.dart';

import 'support/fake_video_player.dart';
import 'support/home_creation_fixtures.dart';

void main() {
  late FakeVideoPlayer platform;
  setUp(() {
    final original = VideoPlayerPlatform.instance;
    platform = FakeVideoPlayer();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = original);
  });

  Future<void> pumpVideo(WidgetTester tester, HomeCreationFixture fixture) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RoleGeneratedVideo(
              mediaId: '901',
              repository: fixture.repository,
            ),
          ),
        ),
      );

  testWidgets('media and playback failures retry with a fresh signed URL', (
    tester,
  ) async {
    final fixture = HomeCreationFixture()..failMediaOnce = true;
    await pumpVideo(tester, fixture);
    await tester.pumpAndSettle();
    expect(find.text('Could not play this video'), findsOneWidget);
    platform.failNext = true;
    await tester.tap(find.byKey(const Key('role-video-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Could not play this video'), findsOneWidget);
    await tester.tap(find.byKey(const Key('role-video-retry')));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(platform.disposed, [1]);
    expect(
      fixture.requests.where((request) => request.path.contains('/media/')),
      hasLength(3),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(platform.disposed, [1, 2]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing during initialization releases the player', (
    tester,
  ) async {
    platform.autoInitialize = false;
    await pumpVideo(tester, HomeCreationFixture());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(platform.sources, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(platform.disposed, [1]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fullscreen uses the shared preview and pauses inline playback', (
    tester,
  ) async {
    await pumpVideo(tester, HomeCreationFixture());
    await tester.pumpAndSettle();
    expect(find.byType(AppVideoPlayer), findsOneWidget);
    expect(find.text('0:00 / 1:00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('role-video-mute')));
    await tester.pumpAndSettle();
    expect(platform.volume, 0);
    await tester.tap(find.byKey(const Key('role-video-play')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('role-video-fullscreen')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('asset-preview-video')), findsOneWidget);
    expect(find.byType(AppVideoPlayer), findsNWidgets(2));
    final inline = tester.widget<VideoPlayer>(find.byType(VideoPlayer).first);
    expect(inline.controller.value.isPlaying, isFalse);
    await tester.tap(find.byKey(const Key('video-preview-close')));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(find.byKey(const Key('asset-preview-video')), findsNothing);
    expect(find.byType(VideoPlayer), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(platform.disposed, [2, 1]);
    expect(tester.takeException(), isNull);
  });
}
