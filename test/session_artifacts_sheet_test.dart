import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/session/data/session_artifact_repository.dart';
import 'package:popi_ai_app/features/session/data/session_repository.dart';
import 'package:popi_ai_app/features/session/domain/session_artifact.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/session_artifacts_sheet.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/fake_video_player.dart';
import 'support/session_artifact_fixtures.dart';
import 'support/session_fixtures.dart';

void main() {
  setUpAll(() async {
    const path = String.fromEnvironment('SESSION_ARTIFACT_CAPTURE_FONT');
    if (path.isEmpty) return;
    await (FontLoader(
      'ArtifactCapture',
    )..addFont(File(path).readAsBytes().then(ByteData.sublistView))).load();
  });

  Future<void> pumpSheet(
    WidgetTester tester, {
    Size size = const Size(440, 956),
    bool dark = false,
    double textScale = 1,
    SessionArtifactRepository repository =
        const FixtureSessionArtifactRepository(),
    SessionRepository? mediaRepository,
    GlobalKey? capture,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final baseTheme = dark ? AppTheme.dark : AppTheme.light;
    final theme =
        const String.fromEnvironment('SESSION_ARTIFACT_CAPTURE_FONT').isEmpty
        ? baseTheme
        : baseTheme.copyWith(
            textTheme: baseTheme.textTheme.apply(fontFamily: 'ArtifactCapture'),
          );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: theme,
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        body: RepaintBoundary(
                          key: capture,
                          child: Material(
                            color: theme.colorScheme.surface,
                            child: SessionArtifactsSheet(
                              sessionId: 'session/id',
                              repository: repository,
                              mediaRepository: mediaRepository,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('filters outputs and returns from details to selected category', (
    tester,
  ) async {
    await pumpSheet(tester);
    expect(find.text('萌宠角色三视图'), findsOneWidget);
    expect(find.text('《围巾不见了》分镜剧本'), findsOneWidget);
    expect(find.text('角色故事短片'), findsOneWidget);
    await tap(tester, 'session-artifact-filter-script');
    expect(find.text('萌宠角色三视图'), findsNothing);
    expect(find.text('角色故事短片'), findsNothing);
    await tap(tester, 'session-artifact-open-mock-script');
    expect(find.text('脚本详情'), findsOneWidget);
    final detail = find.byKey(
      const ValueKey('session-artifact-detail-mock-script'),
    );
    await tester.drag(detail, const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.text('镜头 06 · 温暖的结尾'), findsOneWidget);
    await tap(tester, 'session-artifact-back');
    expect(find.text('当前对话产物'), findsOneWidget);
    expect(find.text('萌宠角色三视图'), findsNothing);
    expect(find.text('《围巾不见了》分镜剧本'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'image details preserve full image and platform back returns to list',
    (tester) async {
      await pumpSheet(tester);
      await tap(tester, 'session-artifact-open-mock-role');
      expect(find.text('图片详情'), findsOneWidget);
      final detail = find.byKey(
        const ValueKey('session-artifact-detail-mock-role'),
      );
      final image = find.descendant(of: detail, matching: find.byType(Image));
      expect(tester.widget<Image>(image).fit, BoxFit.contain);
      final bounds = tester.getSize(
        find.descendant(of: detail, matching: find.byType(AspectRatio)),
      );
      expect(bounds.width, bounds.height);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('当前对话产物'), findsOneWidget);
      expect(find.text('图片详情'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('video starts on demand and releases player on detail return', (
    tester,
  ) async {
    final original = VideoPlayerPlatform.instance;
    final platform = FakeVideoPlayer();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = original);
    await pumpSheet(tester);
    await tap(tester, 'session-artifact-filter-video');
    await tap(tester, 'session-artifact-open-mock-video');
    expect(find.text('视频详情'), findsOneWidget);
    expect(platform.sources, isEmpty);
    await tap(tester, 'session-artifact-video-play');
    expect(find.byType(AppVideoPlayer), findsOneWidget);
    expect(platform.playing, isTrue);
    await tap(tester, 'session-artifact-back');
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(platform.disposed, [1]);
    expect(platform.playing, isFalse);
    expect(find.text('角色故事短片'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets('compact layout fits all categories and details, dark=$dark', (
      tester,
    ) async {
      await pumpSheet(tester, size: const Size(320, 568), dark: dark);
      for (final type in ['image', 'script', 'video']) {
        await tap(tester, 'session-artifact-filter-$type');
        final id = type == 'image' ? 'role' : type;
        final card = find.byKey(ValueKey('session-artifact-mock-$id'));
        if (type != 'script') {
          expect(
            find.descendant(
              of: card,
              matching: find.text(type == 'image' ? '图片' : '视频'),
            ),
            findsOneWidget,
          );
        }
        for (final text in tester.widgetList<Text>(
          find.descendant(of: card, matching: find.byType(Text)),
        )) {
          expect(text.maxLines, 1);
          expect(text.overflow, TextOverflow.ellipsis);
        }
        await tester.tapAt(
          tester.getTopLeft(card) + Offset(4, tester.getSize(card).height / 2),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('session-artifact-detail-mock-$id')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tap(tester, 'session-artifact-back');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty outputs show empty state with filters available', (
    tester,
  ) async {
    await pumpSheet(tester, repository: const _EmptyRepository());
    expect(find.text('暂无产物'), findsOneWidget);
    await tap(tester, 'session-artifact-filter-script');
    expect(find.text('暂无产物'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'real text drafts preview Markdown without adopt or edit actions at large text scale',
    (tester) async {
      await pumpSheet(
        tester,
        size: const Size(320, 568),
        dark: true,
        textScale: 1.5,
        repository: const _TextRepository(),
      );
      await tap(tester, 'session-artifact-filter-script');
      expect(find.textContaining('未记录时长'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('session-artifact-download-text')),
        findsOneWidget,
      );
      await tap(tester, 'session-artifact-open-text');
      expect(find.text('故事正文'), findsOneWidget);
      expect(find.text('第二段正文'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('session-artifact-download-detail')),
        findsOneWidget,
      );
      expect(find.text('采用'), findsNothing);
      expect(find.text('修改'), findsNothing);
      await tap(tester, 'session-artifact-back');
      expect(find.text('真实稿件'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'list and detail export the complete saved text, not the preview',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'popi-text-export-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
      const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
      addTearDown(() => messenger.setMockMethodCallHandler(shareChannel, null));
      addTearDown(() => messenger.setMockMethodCallHandler(pathChannel, null));
      messenger.setMockMethodCallHandler(
        pathChannel,
        (_) async => directory.path,
      );
      var exports = 0;
      late Completer<Map> shared;
      messenger.setMockMethodCallHandler(shareChannel, (call) async {
        exports++;
        shared.complete(call.arguments as Map);
        return '';
      });
      await pumpSheet(tester, repository: const _TextRepository());
      for (final key in [
        'session-artifact-download-text',
        'session-artifact-download-detail',
      ]) {
        if (key.endsWith('detail')) {
          await tap(tester, 'session-artifact-open-text');
        }
        await tester.runAsync(() async {
          shared = Completer<Map>();
          tester.widget<IconButton>(find.byKey(ValueKey(key))).onPressed!();
          final args = await shared.future.timeout(const Duration(seconds: 5));
          final path = (args['paths'] as List).single as String;
          expect(path.endsWith('/真实稿件.md'), isTrue);
          expect(await File(path).readAsString(), '## 故事正文\n\n第二段正文');
          expect(args['originWidth'], greaterThan(0));
        });
        await tester.pumpAndSettle();
        expect(find.text('文档已导出'), findsNothing);
        expect(find.text('文档导出失败，请稍后重试'), findsNothing);
        expect(
          tester.widget<IconButton>(find.byKey(ValueKey(key))).onPressed,
          isNotNull,
        );
      }
      expect(exports, 2);
      expect(find.text('故事正文'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'export failure keeps the document and original download action',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel('plugins.flutter.io/file_selector');
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final response = Completer<String?>();
      var attempts = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        attempts++;
        if (attempts == 1) return response.future;
        return null;
      });
      await pumpSheet(tester, repository: const _TextRepository());
      await tap(tester, 'session-artifact-open-text');
      final download = find.byKey(
        const ValueKey('session-artifact-download-detail'),
      );
      await tester.tap(download);
      await tester.pump();
      expect(tester.widget<IconButton>(download).onPressed, isNull);
      await tester.tap(download);
      await tester.pump();
      expect(attempts, 1);
      response.completeError(PlatformException(code: 'save_failed'));
      await tester.pumpAndSettle();
      expect(find.text('文档导出失败，请稍后重试'), findsOneWidget);
      expect(find.text('第二段正文'), findsOneWidget);
      expect(tester.widget<IconButton>(download).onPressed, isNotNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.tap(download);
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('文档导出失败，请稍后重试'), findsNothing);
      expect(find.text('文档已导出'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'unified video title and download are available in list and detail at 320px',
    (tester) async {
      final dio = Dio();
      addTearDown(() => dio.close(force: true));
      final requests = <RequestOptions>[];
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request);
            handler.resolve(
              Response(
                requestOptions: request,
                data: {
                  'status': '0000',
                  'data': {
                    'list': [
                      {
                        'id': 'media:movie',
                        'category': 'media',
                        'type': 'video',
                        'title': '天台黄昏：来福的笑点急救（15秒短片）',
                        'createdAt': '2026-10-20T03:04:00Z',
                        'media': {
                          'id': 'movie',
                          'kind': 'video',
                          'mime': 'video/mp4',
                          'size': 13107200,
                        },
                      },
                      {
                        'id': 'media:movie-2',
                        'category': 'media',
                        'type': 'video',
                        'title': '电梯口·人快猫慢分镜视频提示词（15秒）',
                        'media': {'id': 'movie-2', 'kind': 'video'},
                      },
                    ],
                    'pageInfo': {'page': 1, 'pageSize': 20, 'pageCount': 1},
                  },
                },
              ),
            );
          },
        ),
      );
      final original = VideoPlayerPlatform.instance;
      final platform = FakeVideoPlayer();
      VideoPlayerPlatform.instance = platform;
      addTearDown(() => VideoPlayerPlatform.instance = original);
      const galleryChannel = MethodChannel('gal');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(
        () => messenger.setMockMethodCallHandler(galleryChannel, null),
      );
      var attempts = 0;
      messenger.setMockMethodCallHandler(galleryChannel, (_) async {
        attempts++;
        return false;
      });
      final media = _MediaRepository();
      final capture = GlobalKey();
      await pumpSheet(
        tester,
        size: const Size(320, 568),
        textScale: 1.5,
        repository: ApiSessionArtifactRepository(NetworkApi(dio)),
        mediaRepository: media,
        capture: capture,
      );
      expect(
        requests.single.path,
        '/api_client/agent/v2/sessions/session%2Fid/artifacts',
      );
      expect(find.text('天台黄昏：来福的笑点急救（15秒短片）'), findsOneWidget);
      expect(find.text('生成结果'), findsNothing);
      expect(media.requests, isEmpty);
      final metadata = find.textContaining('视频 · 12.5 MB · ');
      expect(metadata, findsOneWidget);
      final metadataContext = tester.element(metadata);
      final material = MaterialLocalizations.of(metadataContext);
      final createdAt = DateTime.utc(2026, 10, 20, 3, 4).toLocal();
      expect(
        tester.widget<Text>(metadata).data,
        contains(
          '${material.formatCompactDate(createdAt)} '
          '${material.formatTimeOfDay(TimeOfDay.fromDateTime(createdAt), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(metadataContext))}',
        ),
      );
      expect(tester.widget<Text>(metadata).maxLines, 1);
      expect(tester.widget<Text>(metadata).overflow, TextOverflow.ellipsis);
      for (final id in ['movie', 'movie-2']) {
        final card = find.byKey(ValueKey('session-artifact-media:$id'));
        expect(tester.getSize(card).height, lessThanOrEqualTo(108));
        expect(
          find.descendant(of: card, matching: find.text('')),
          findsNothing,
        );
      }
      final listDownload = find.byKey(
        const ValueKey('session-artifact-download-media:movie'),
      );
      expect(listDownload, findsOneWidget);
      if (const bool.fromEnvironment('CAPTURE_SESSION_ARTIFACTS')) {
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final pixels = await boundary.toImage();
          final bytes = await pixels.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/session-artifact-unified-video-320.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          pixels.dispose();
        });
      }
      media.failNext = true;
      await tester.tap(listDownload);
      await tester.pumpAndSettle();
      expect(media.requests, ['movie']);
      expect(find.text('视频详情'), findsNothing);
      expect(find.text('文件保存失败，请稍后重试'), findsOneWidget);
      expect(attempts, 0);
      expect(tester.widget<IconButton>(listDownload).onPressed, isNotNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.tap(listDownload);
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('无法保存视频，请在系统设置中允许添加照片'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tap(tester, 'session-artifact-open-media:movie');
      expect(find.byType(AppVideoPlayer), findsOneWidget);
      expect(find.textContaining('视频 · 12.5 MB · '), findsOneWidget);
      final detailDownload = find.byKey(
        const ValueKey('session-artifact-download-detail'),
      );
      expect(detailDownload, findsOneWidget);
      await tester.tap(detailDownload);
      await tester.pumpAndSettle();
      expect(attempts, 4);
      expect(tester.widget<IconButton>(detailDownload).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'late responses from the previous session cannot replace current outputs',
    (tester) async {
      final repository = _DeferredRepository();
      final session = ValueNotifier('first');
      addTearDown(session.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ValueListenableBuilder<String>(
                valueListenable: session,
                builder: (_, id, _) => SessionArtifactsSheet(
                  sessionId: id,
                  repository: repository,
                ),
              ),
            ),
          ),
        ),
      );
      session.value = 'second';
      await tester.pump();
      repository.requests['second']!.complete([
        SessionArtifact.fromTextDraft({
          'id': 'new',
          'title': 'Current output',
          'content': 'Current',
        }),
      ]);
      await tester.pumpAndSettle();
      repository.requests['first']!.complete([
        SessionArtifact.fromTextDraft({
          'id': 'old',
          'title': 'Obsolete output',
          'content': 'Old',
        }),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Current output'), findsOneWidget);
      expect(find.text('Obsolete output'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _MediaRepository extends FixtureSessionRepository {
  final requests = <String>[];
  bool failNext = false;

  @override
  Future<ConversationMedia> media(String id, {CancelToken? cancelToken}) async {
    requests.add(id);
    if (failNext) {
      failNext = false;
      throw StateError('unavailable');
    }
    return ConversationMedia(
      id: id,
      kind: 'video',
      url: 'https://example.com/video.mp4',
    );
  }
}

class _DeferredRepository extends SessionArtifactRepository {
  final requests = <String, Completer<List<SessionArtifact>>>{};

  @override
  Future<List<SessionArtifact>> list(String? sessionId) =>
      (requests[sessionId!] = Completer<List<SessionArtifact>>()).future;
}

class _TextRepository extends SessionArtifactRepository {
  const _TextRepository();

  @override
  Future<List<SessionArtifact>> list(String? sessionId) async => [
    SessionArtifact.fromTextDraft({
      'id': 'text',
      'kind': 'topic',
      'title': '真实稿件',
      'content': '## 故事正文\n\n第二段正文',
      'durationSeconds': 0,
      'createdAt': '2026-10-19T03:15:00Z',
    }),
  ];
}

class _EmptyRepository extends SessionArtifactRepository {
  const _EmptyRepository();

  @override
  Future<List<SessionArtifact>> list(String? sessionId) async => const [];
}
