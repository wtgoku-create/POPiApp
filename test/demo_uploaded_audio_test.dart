import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/demo/data/demo_media_exporter.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_audio_detail.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/fake_video_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const remoteAudio = DemoAsset(
    id: 'uploaded-audio',
    title: '采访/原声',
    kind: DemoAssetKind.audio,
    cover: '',
    media: 'https://example.test/owned/audio?id=1',
    contentUrl: 'https://example.test/owned/audio?id=1',
    mimeType: 'audio/mpeg',
    sizeBytes: 3 * 1024 * 1024,
    durationSeconds: 95,
  );

  late FakeVideoPlayer platform;
  setUp(() {
    final original = VideoPlayerPlatform.instance;
    platform = FakeVideoPlayer();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = original);
    DemoMediaExporter.debugShare = null;
    addTearDown(() => DemoMediaExporter.debugShare = null);
  });

  testWidgets(
    'remote audio streams its owned URL without reading export bytes',
    (tester) async {
      var reads = 0;
      await tester.pumpWidget(
        ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: DemoAudioDetail(
                asset: remoteAudio,
                readBytes: () async {
                  reads++;
                  return Uint8List.fromList(const [1, 2, 3]);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(platform.sources.single.sourceType, DataSourceType.network);
      expect(platform.sources.single.uri, remoteAudio.contentUrl);
      expect(find.text('MP3 · 01:35 · 3.0 MB'), findsOneWidget);
      expect(reads, 0);

      await tester.tap(find.byKey(const Key('demo-audio-play')));
      await tester.pumpAndSettle();
      expect(platform.playing, isTrue);
      await tester.tap(find.byKey(const Key('demo-audio-forward')));
      await tester.pumpAndSettle();
      expect(platform.positions[1], const Duration(seconds: 15));
      await tester.tap(find.byKey(const Key('demo-audio-play')));
      await tester.pumpAndSettle();
      expect(platform.playing, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(platform.disposed, [1]);
      expect(reads, 0);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'remote export reads once and preserves bytes, MIME and safe name',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final bytes = Uint8List.fromList(const [0, 1, 2, 3, 254, 255]);
      final shared = <ShareParams>[];
      DemoMediaExporter.debugShare = (params) async => shared.add(params);

      for (final entry in const [
        ('audio/mpeg', 'mp3'),
        ('audio/wav', 'wav'),
        ('audio/mp4', 'm4a'),
      ]) {
        var reads = 0;
        final asset = DemoAsset(
          id: entry.$2,
          title: '采访/原声',
          kind: DemoAssetKind.audio,
          cover: '',
          contentUrl: 'https://example.test/audio/file',
          mimeType: entry.$1,
          sizeBytes: bytes.length,
        );
        expect(
          await DemoMediaExporter.size(
            asset,
            readBytes: () async {
              reads++;
              return bytes;
            },
          ),
          bytes.length,
        );
        expect(reads, 0);

        expect(
          await DemoMediaExporter.save(
            asset,
            const Rect.fromLTWH(1, 2, 30, 40),
            readBytes: () async {
              reads++;
              return bytes;
            },
          ),
          isFalse,
        );
        expect(reads, 1);
        final params = shared.removeAt(0);
        expect(params.fileNameOverrides, ['采访_原声.${entry.$2}']);
        expect(params.sharePositionOrigin, const Rect.fromLTWH(1, 2, 30, 40));
        expect(params.files!.single.mimeType, entry.$1);
        expect(await params.files!.single.readAsBytes(), bytes);
      }
    },
  );
}
