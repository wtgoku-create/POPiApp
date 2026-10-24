import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toastification/toastification.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/demo/data/demo_fixtures.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_assets_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_audio_detail.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/session_artifacts_sheet.dart';
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

  Future<void> pump(WidgetTester tester, Widget home, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: home,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 440.0]) {
    testWidgets('audio waveform layout and bounded seeking at $width', (
      tester,
    ) async {
      final asset = DemoFixtures.assets().firstWhere((a) => a.id == 'audio');
      await pump(
        tester,
        Scaffold(body: DemoAudioDetail(asset: asset)),
        Size(width, 838),
      );
      final player = find.byKey(const Key('demo-audio-player'));
      expect(tester.getSize(player), Size(width - 32, 208));
      expect(find.byType(Image), findsNothing);
      expect(find.text('00:00'), findsOneWidget);
      expect(platform.sources.single.asset, asset.media);
      await tester.tap(find.byKey(const Key('demo-audio-forward')));
      await tester.pumpAndSettle();
      expect(platform.positions[1], const Duration(seconds: 15));
      await tester.tap(find.byKey(const Key('demo-audio-backward')));
      await tester.pumpAndSettle();
      expect(platform.positions[1], Duration.zero);
      await tester.tap(find.byKey(const Key('demo-audio-backward')));
      await tester.pumpAndSettle();
      expect(platform.positions[1], Duration.zero);
      final seek = tester.widget<Slider>(
        find.byKey(const Key('demo-audio-seek')),
      );
      seek.onChanged!(.95);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('demo-audio-forward')));
      await tester.pumpAndSettle();
      expect(platform.positions[1], const Duration(seconds: 60));
      await tester.tap(find.byKey(const Key('demo-audio-play')));
      await tester.pumpAndSettle();
      expect(platform.playing, true);
      expect(platform.positions[1], Duration.zero);
      await tester.tap(find.byKey(const Key('demo-audio-play')));
      await tester.pumpAndSettle();
      expect(platform.playing, false);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(platform.disposed, [1]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'video opens existing detail and shared player with bundled source',
    (tester) async {
      final asset = DemoFixtures.assets().firstWhere((a) => a.id == 'weekend');
      await pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openDemoAsset(context, asset),
              child: const Text('Open'),
            ),
          ),
        ),
        const Size(390, 844),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(SessionArtifactDetailPage), findsOneWidget);
      await tester.tap(find.byKey(const Key('session-artifact-video-play')));
      await tester.pumpAndSettle();
      expect(find.byType(AppVideoPlayer), findsOneWidget);
      expect(platform.sources.single.asset, asset.media);
      expect(platform.playing, true);
      await tester.tap(find.byKey(const Key('session-artifact-video-play')));
      await tester.pumpAndSettle();
      expect(platform.playing, false);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(platform.disposed, [1]);
      expect(tester.takeException(), isNull);
    },
  );
}
