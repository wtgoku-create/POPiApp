import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_assets_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_remote_media.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_settings_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/harness_access_provider.dart';
import 'package:popi_ai_app/core/storage/app_image_cache.dart';
import 'package:popi_ai_app/shared/widgets/app_video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/fake_video_player.dart';

const _remoteAsset = DemoAsset(
  id: 'owned-image-1',
  title: '南极猫角色图',
  kind: DemoAssetKind.image,
  cover: 'http://127.0.0.1:3084/api_agent/v2/assets/owned-image-1/content',
  contentUrl: 'http://127.0.0.1:3084/api_agent/v2/assets/owned-image-1/content',
  thumbnailUrl:
      'http://127.0.0.1:3084/api_agent/v2/assets/owned-image-1/thumbnail',
  sessionId: 'server-session',
  jobId: 'job-1',
  runId: 'run-1',
  memberId: 'writer',
  configRevision: 4,
  mimeType: 'image/png',
  width: 1024,
  height: 1024,
);

const _remoteVideoAsset = DemoAsset(
  id: 'owned-video-1',
  title: '南极猫角色短片',
  kind: DemoAssetKind.video,
  cover: '',
  contentUrl: 'http://127.0.0.1:3084/api_agent/v2/assets/owned-video-1/content',
  sessionId: 'server-session',
  jobId: 'job-video-1',
  runId: 'run-video-1',
  memberId: 'writer',
  configRevision: 5,
  mimeType: 'video/mp4',
  width: 480,
  height: 854,
  durationSeconds: 29.97,
  hasAudio: true,
);

const _remoteVideoPosterAsset = DemoAsset(
  id: 'owned-video-poster-1',
  title: '南极猫角色短片',
  kind: DemoAssetKind.video,
  cover: '',
  contentUrl:
      'http://127.0.0.1:3084/api_agent/v2/assets/owned-video-poster-1/content',
  posterUrl:
      'http://127.0.0.1:3084/api_agent/v2/assets/owned-video-poster-1/poster',
  mimeType: 'video/mp4',
  width: 480,
  height: 854,
  durationSeconds: 29.97,
  hasAudio: true,
);

DemoSession _session() => const DemoSession(
  id: 'server-session',
  title: '南极猫创作',
  kind: DemoSessionKind.project,
  members: ['popi', 'writer'],
  roles: ['alice'],
  messages: [
    DemoMessage(
      id: 'assistant-1',
      text: '角色图已完成。',
      assetIds: ['owned-image-1'],
    ),
  ],
  capabilities: ['character', 'script', 'image'],
  memberCapabilities: {
    'popi': ['character', 'script', 'image'],
    'writer': ['character', 'script', 'image'],
  },
  activeMemberId: 'popi',
  roleProfiles: {'alice': DemoRoleProfile(name: '爱丽丝')},
  configRevision: 4,
  configurationStatus: 'configured',
  mediaJobs: [
    DemoMediaJob(
      jobId: 'job-1',
      state: 'completed',
      operation: 'image',
      model: 'configured-by-server',
      runId: 'run-1',
      memberId: 'writer',
      configRevision: 4,
      ingestionState: 'ingesting',
    ),
  ],
);

Future<DemoRepository> _repository() async {
  final session = _session();
  SharedPreferences.setMockInitialValues({
    DemoRepository.storageKey: jsonEncode({
      'sessions': [session.toJson()],
      'assets': [_remoteAsset.toJson()],
    }),
  });
  final repository = DemoRepository(
    PreferencesStorage(await SharedPreferences.getInstance()),
  )..restore();
  return repository;
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  Size size = const Size(375, 760),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: ToastificationWrapper(
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: home,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('remote and bundled assets choose their matching image provider', () {
    final remote = demoAssetImageProvider(_remoteAsset);
    final local = demoAssetImageProvider(
      const DemoAsset(
        id: 'local',
        title: 'Local',
        kind: DemoAssetKind.image,
        cover: 'assets/images/demo_scene_1.png',
      ),
    );

    expect(remote, isA<CachedNetworkImageProvider>());
    expect((remote as CachedNetworkImageProvider).url, _remoteAsset.contentUrl);
    expect(local, isA<AssetImage>());
  });

  testWidgets('owned image and verifiable saving state fit the chat at 320px', (
    tester,
  ) async {
    final repository = await _repository();
    addTearDown(repository.dispose);
    await _pump(
      tester,
      DemoChatPage(repository: repository, sessionId: 'server-session'),
      size: const Size(320, 700),
    );

    expect(find.text('南极猫角色图'), findsOneWidget);
    expect(find.text('正在保存到资产库'), findsOneWidget);
    expect(find.textContaining('受理配置 v4'), findsOneWidget);
    expect(find.byKey(const ValueKey('demo-media-job-job-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected owned image uses authenticated cached thumbnail', (
    tester,
  ) async {
    final repository = await _repository();
    addTearDown(repository.dispose);
    final cacheKey = '${_remoteAsset.thumbnailUrl}::composer-session';
    await AppImageCache.manager.putFile(
      cacheKey,
      File('assets/icons/common_user_avatar.png').readAsBytesSync(),
    );
    tester.view.physicalSize = const Size(375, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          harnessAccessHeadersProvider.overrideWith(
            (ref, url) => const {
              'Cookie': '__Host-popi-test=private-session',
              'Origin': 'https://harness.test',
            },
          ),
          harnessAccessCacheKeyProvider.overrideWith(
            (ref, url) => '$url::composer-session',
          ),
          harnessAccessUnauthorizedProvider.overrideWith((ref, url) => () {}),
        ],
        child: ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: DemoChatPage(
              repository: repository,
              sessionId: 'server-session',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('添加附件'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('demo-attachment-library')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('owned-image-1')));
    await tester.pumpAndSettle();

    final selected = find.byKey(
      const ValueKey('popi-selected-asset-owned-image-1'),
    );
    expect(selected, findsOneWidget);
    final image = tester.widget<Image>(
      find.descendant(of: selected, matching: find.byType(Image)),
    );
    final provider = image.image as CachedNetworkImageProvider;
    expect(provider.url, _remoteAsset.thumbnailUrl);
    expect(provider.cacheKey, cacheKey);
    expect(provider.headers, containsPair('Origin', 'https://harness.test'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('server capability catalog is read only and work mode saves', (
    tester,
  ) async {
    final repository = await _repository();
    addTearDown(repository.dispose);
    await _pump(
      tester,
      DemoSettingsPage(repository: repository, sessionId: 'server-session'),
    );

    await tester.tap(find.text('能力'));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
    expect(find.byKey(const ValueKey('demo-dsh-tools')), findsOneWidget);

    final settingsScroll = find
        .descendant(
          of: find.byKey(const PageStorageKey('demo-settings-skills')),
          matching: find.byType(Scrollable),
        )
        .first;
    final workMode = find.byKey(const Key('demo-work-mode'));
    await tester.scrollUntilVisible(workMode, 240, scrollable: settingsScroll);
    await tester.tap(workMode);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('demo-work-mode-manual')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-active-member-picker')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('demo-active-member-writer')));
    await tester.tap(find.byKey(const Key('demo-work-mode-confirm')));
    await tester.pumpAndSettle();

    final saved = repository.session('server-session');
    expect(saved.workMode, 'manual');
    expect(saved.activeMemberId, 'writer');
    expect(tester.takeException(), isNull);
  });

  testWidgets('role profile cancel rolls back and save marks it configured', (
    tester,
  ) async {
    final repository = await _repository();
    addTearDown(repository.dispose);
    await _pump(
      tester,
      DemoSettingsPage(repository: repository, sessionId: 'server-session'),
    );

    await tester.tap(find.byKey(const ValueKey('demo-role-profile-alice')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('demo-role-profile-instructions')),
      '温柔、安静，所有画面都保持南极猫的橘白花纹。',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      repository.session('server-session').roleProfiles['alice']!.isReady,
      false,
    );

    await tester.tap(find.byKey(const ValueKey('demo-role-profile-alice')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('demo-role-profile-instructions')),
      '温柔、安静，所有画面都保持南极猫的橘白花纹。',
    );
    await tester.pump();
    final confirm = find.descendant(
      of: find.byKey(const Key('demo-role-profile-confirm')),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    final profile = repository.session('server-session').roleProfiles['alice']!;
    expect(profile.instructions, contains('南极猫'));
    expect(profile.revision, isNotEmpty);
    expect(profile.isReady, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('remote asset card remains bounded on the small grid', (
    tester,
  ) async {
    await _pump(
      tester,
      Scaffold(
        body: SizedBox(
          width: 152,
          height: 220,
          child: DemoAssetCard(asset: _remoteAsset, onTap: () {}),
        ),
      ),
      size: const Size(320, 640),
    );

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(DemoAssetImage),
        matching: find.byType(Image),
      ),
    );
    expect(image.image, isA<ResizeImage>());
    final resized = image.image as ResizeImage;
    expect(resized.width, 800);
    expect(resized.imageProvider, isA<CachedNetworkImageProvider>());
    expect(find.text('南极猫角色图'), findsOneWidget);
    expect(find.text('图片 / 1024×1024'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owned video uses a neutral cover and measured metadata', (
    tester,
  ) async {
    await _pump(
      tester,
      Scaffold(
        body: SizedBox(
          width: 152,
          height: 220,
          child: DemoAssetCard(asset: _remoteVideoAsset, onTap: () {}),
        ),
      ),
      size: const Size(320, 640),
    );

    final thumbnail = find.byKey(
      const ValueKey('demo-remote-video-thumbnail-owned-video-1'),
    );
    expect(thumbnail, findsOneWidget);
    expect(
      find.descendant(of: thumbnail, matching: find.byType(Image)),
      findsNothing,
    );
    expect(find.text('视频 / 00:30 / 480×854'), findsOneWidget);
    expect(find.text('00:30'), findsOneWidget);
    expect(find.text('00:08'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owned video poster uses image cache without creating a player', (
    tester,
  ) async {
    final original = VideoPlayerPlatform.instance;
    final platform = FakeVideoPlayer();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = original);
    await _pump(
      tester,
      Scaffold(
        body: SizedBox(
          width: 152,
          height: 220,
          child: DemoAssetCard(asset: _remoteVideoPosterAsset, onTap: () {}),
        ),
      ),
      size: const Size(320, 640),
    );

    final image = tester.widget<Image>(
      find.descendant(
        of: find.byType(DemoAssetImage),
        matching: find.byType(Image),
      ),
    );
    expect(image.image, isA<ResizeImage>());
    final resized = image.image as ResizeImage;
    final network = resized.imageProvider;
    expect(resized.width, 800);
    expect(network, isA<CachedNetworkImageProvider>());
    expect(
      (network as CachedNetworkImageProvider).url,
      _remoteVideoPosterAsset.posterUrl,
    );
    expect(platform.sources, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owned video opens the shared playable preview', (tester) async {
    final original = VideoPlayerPlatform.instance;
    final platform = FakeVideoPlayer();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = original);
    await _pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => openDemoAsset(context, _remoteVideoAsset),
            child: const Text('open video'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open video'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('asset-preview-video')), findsOneWidget);
    expect(find.byKey(const Key('asset-preview-download')), findsOneWidget);
    expect(platform.sources.single.uri, _remoteVideoAsset.contentUrl);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owned video poster preview plays its MP4 with one player', (
    tester,
  ) async {
    final original = VideoPlayerPlatform.instance;
    final platform = FakeVideoPlayer();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = original);
    await _pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => openDemoAsset(context, _remoteVideoPosterAsset),
            child: const Text('open poster video'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open poster video'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('asset-preview-video')), findsOneWidget);
    expect(platform.sources, hasLength(1));
    expect(platform.sources.single.uri, _remoteVideoPosterAsset.contentUrl);
    expect(
      tester.widget<AppVideoPlayer>(find.byType(AppVideoPlayer)).placeholder,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('owned image opens shared preview with download action', (
    tester,
  ) async {
    await _pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => openDemoAsset(context, _remoteAsset),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('asset-preview-gallery')), findsOneWidget);
    expect(find.byKey(const Key('asset-preview-download')), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('asset-preview-download')))
          .tooltip,
      '下载',
    );
    expect(tester.takeException(), isNull);
  });
}
