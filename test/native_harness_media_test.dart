import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/app_image_cache.dart';
import 'package:popi_ai_app/core/storage/app_image_file_service.dart';
import 'package:popi_ai_app/core/storage/gallery_video_storage.dart';
import 'package:popi_ai_app/features/demo/domain/harness_access_session.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/harness_access_provider.dart';
import 'package:popi_ai_app/shared/widgets/app_video_player.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/fake_video_player.dart';

final _namespaceProvider = StateProvider<String>((ref) => 'one');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    GalleryVideoStorage.debugPlaybackDownload = null;
    GalleryVideoStorage.debugDeleteDownloaded = null;
  });

  test(
    'authenticated image cache keys isolate sessions without credentials',
    () {
      const url = 'https://harness.test/api_agent/v2/assets/a/content';
      const cookie = 'popi_access=secret';
      final first = AppImageCache.provider(
        url,
        headers: const {'Cookie': cookie},
        cacheKey: '$url::11111111-1111-4111-8111-111111111111',
      );
      final second = AppImageCache.provider(
        url,
        headers: const {'Cookie': 'popi_access=other'},
        cacheKey: '$url::22222222-2222-4222-8222-222222222222',
      );

      expect(first, isNot(second));
      expect(first.headers, const {'Cookie': cookie});
      expect(first.cacheKey, isNot(contains(cookie)));
      expect(second.cacheKey, isNot(contains('other')));
      expect(
        AppImageCache.provider('https://cdn.test/image.png').headers,
        isNull,
      );
    },
  );

  testWidgets(
    'protected video downloads locally and reloads for a new namespace',
    (tester) async {
      final original = VideoPlayerPlatform.instance;
      final platform = FakeVideoPlayer();
      VideoPlayerPlatform.instance = platform;
      addTearDown(() => VideoPlayerPlatform.instance = original);
      final downloads = <Map<String, String>>[];
      final deleted = <String>[];
      GalleryVideoStorage.debugPlaybackDownload =
          (url, headers, onUnauthorized, extension) async {
            downloads.add(headers);
            return '/tmp/protected-${downloads.length}.mp4';
          };
      GalleryVideoStorage.debugDeleteDownloaded = (path) async {
        deleted.add(path);
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            harnessAccessHeadersProvider.overrideWith(
              (ref, url) => {
                'Cookie': 'popi_access=${ref.watch(_namespaceProvider)}',
                'Origin': 'https://harness.test',
              },
            ),
            harnessAccessCacheKeyProvider.overrideWith(
              (ref, url) => '$url::${ref.watch(_namespaceProvider)}',
            ),
            harnessAccessUnauthorizedProvider.overrideWith((ref, url) => () {}),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AppVideoPlayer(
                url: Uri.parse(
                  'https://harness.test/api_agent/v2/assets/a/content',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(downloads.single, {
        'Cookie': 'popi_access=one',
        'Origin': 'https://harness.test',
      });
      expect(platform.sources.single.httpHeaders, isEmpty);
      expect(platform.sources.single.uri, 'file:///tmp/protected-1.mp4');

      final context = tester.element(find.byType(AppVideoPlayer));
      ProviderScope.containerOf(
        context,
      ).read(_namespaceProvider.notifier).state = 'two';
      await tester.pump();
      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 20 && downloads.length < 2; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await tester.pump();

      expect(downloads.last['Cookie'], 'popi_access=two');
      expect(downloads, hasLength(2));
      expect(deleted, contains('/tmp/protected-1.mp4'));
      expect(platform.sources.last.httpHeaders, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  test('style poster cache partitions use exact authenticated routes only', () {
    const base = 'https://harness.test';
    const url = '$base/api_agent/v2/style-films/styles/ink-wash/poster';
    final first = HarnessAccessSession(
      cookieValue: 'secret-one',
      origin: base,
      expiresAt: DateTime.utc(2099),
      cacheNamespace: '11111111-1111-4111-8111-111111111111',
    );
    final second = HarnessAccessSession(
      cookieValue: 'secret-two',
      origin: base,
      expiresAt: DateTime.utc(2099),
      cacheNamespace: '22222222-2222-4222-8222-222222222222',
    );
    final firstKey = harnessAccessCacheKeyFor(
      url,
      session: first,
      baseUrl: base,
    );
    final secondKey = harnessAccessCacheKeyFor(
      url,
      session: second,
      baseUrl: base,
    );
    expect(firstKey, '$url::${first.cacheNamespace}');
    expect(firstKey, isNot(secondKey));
    expect(firstKey, isNot(contains(first.cookieValue)));
    final image = AppImageCache.provider(
      url,
      headers: harnessAccessHeadersFor(url, session: first, baseUrl: base),
      cacheKey: firstKey,
    );
    expect(image.headers?['Cookie'], first.cookieHeader);
    expect(
      image,
      isNot(
        AppImageCache.provider(
          url,
          headers: harnessAccessHeadersFor(url, session: second, baseUrl: base),
          cacheKey: secondKey,
        ),
      ),
    );
    for (final rejected in [
      '$url?redirect=elsewhere',
      '$url#fragment',
      'https://other.test/api_agent/v2/style-films/styles/ink-wash/poster',
      'https://user:secret@harness.test/api_agent/v2/style-films/styles/ink-wash/poster',
      '$base/api_agent/v2/style-films/styles/../poster',
      '$base/api_agent/v2/style-films/styles/ink-wash/preview',
      '$base/api_agent/v2/style-films/styles/ink-wash/poster/extra',
      '$base/api_agent/v2/style-films/catalog',
    ]) {
      expect(
        harnessAccessCacheKeyFor(rejected, session: first, baseUrl: base),
        isNull,
      );
    }
  });

  testWidgets('protected video keeps its poster visible while downloading', (
    tester,
  ) async {
    final original = VideoPlayerPlatform.instance;
    VideoPlayerPlatform.instance = FakeVideoPlayer();
    addTearDown(() => VideoPlayerPlatform.instance = original);
    final download = Completer<String>();
    GalleryVideoStorage.debugPlaybackDownload =
        (url, headers, onUnauthorized, extension) => download.future;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          harnessAccessHeadersProvider.overrideWith(
            (ref, url) => const {'Cookie': 'popi_access=test'},
          ),
          harnessAccessCacheKeyProvider.overrideWith(
            (ref, url) => '$url::test',
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AppVideoPlayer(
              url: Uri.parse(
                'https://harness.test/api_agent/v2/assets/a/content',
              ),
              placeholder: const AssetImage(
                'assets/icons/common_user_avatar.png',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('video-player-placeholder')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    download.complete('/tmp/protected-poster.mp4');
    await tester.pumpAndSettle();
    expect(find.byType(VideoPlayer), findsOneWidget);
    expect(find.byKey(const Key('video-player-placeholder')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  test('native video download forwards access headers', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    String? cookie;
    server.listen((request) async {
      cookie = request.headers.value(HttpHeaders.cookieHeader);
      request.response.add(const [1, 2, 3]);
      await request.response.close();
    });
    final url = Uri.parse('http://127.0.0.1:${server.port}/video.mp4');

    final downloaded = await HttpOverrides.runWithHttpOverrides(
      () => GalleryVideoStorage.downloadForShare(
        url,
        headers: const {'Cookie': 'popi_access=secret'},
      ),
      _LoopbackHttpOverrides(),
    );

    expect(cookie, 'popi_access=secret');
    expect(downloaded.bytes, [1, 2, 3]);
  });

  test(
    'protected media rejects redirects without forwarding cookies',
    () async {
      final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final source = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await source.close(force: true);
        await target.close(force: true);
      });
      var targetRequests = 0;
      String? targetCookie;
      target.listen((request) async {
        targetRequests++;
        targetCookie = request.headers.value(HttpHeaders.cookieHeader);
        request.response.add(const [1, 2, 3]);
        await request.response.close();
      });
      source.listen((request) async {
        request.response
          ..statusCode = HttpStatus.found
          ..headers.set(
            HttpHeaders.locationHeader,
            'http://127.0.0.1:${target.port}/outside.mp4',
          );
        await request.response.close();
      });
      final url = Uri.parse('http://127.0.0.1:${source.port}/owned.mp4');

      await expectLater(
        HttpOverrides.runWithHttpOverrides(
          () => GalleryVideoStorage.downloadForPlayback(
            url,
            headers: const {'Cookie': 'popi_access=secret'},
          ),
          _LoopbackHttpOverrides(),
        ),
        throwsException,
      );

      expect(targetRequests, 0);

      final publicPath = await HttpOverrides.runWithHttpOverrides(
        () => GalleryVideoStorage.downloadForPlayback(url),
        _LoopbackHttpOverrides(),
      );
      addTearDown(() => GalleryVideoStorage.deleteDownloaded(publicPath));
      expect(await File(publicPath).readAsBytes(), [1, 2, 3]);
      expect(targetRequests, 1);
      expect(targetCookie, isNull);
    },
  );

  test('protected media reports 401 through its guarded callback', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.close();
    });
    var unauthorized = 0;

    await expectLater(
      HttpOverrides.runWithHttpOverrides(
        () => GalleryVideoStorage.downloadForPlayback(
          Uri.parse('http://127.0.0.1:${server.port}/owned.mp4'),
          headers: const {'Cookie': 'popi_access=secret'},
          onUnauthorized: () => unauthorized++,
        ),
        _LoopbackHttpOverrides(),
      ),
      throwsException,
    );

    expect(unauthorized, 1);
  });

  test('image requests reject redirects and report current 401', () async {
    final target = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final source = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await source.close(force: true);
      await target.close(force: true);
    });
    var targetRequests = 0;
    String? targetCookie;
    target.listen((request) async {
      targetRequests++;
      targetCookie = request.headers.value(HttpHeaders.cookieHeader);
      request.response.add(const [4, 5, 6]);
      await request.response.close();
    });
    var unauthorized = 0;
    final service = createAppImageFileService(
      onUnauthorized: (url, headers) => unauthorized++,
    );

    source.listen((request) async {
      if (request.uri.path == '/unauthorized') {
        request.response.statusCode = HttpStatus.unauthorized;
      } else {
        request.response
          ..statusCode = HttpStatus.found
          ..headers.set(
            HttpHeaders.locationHeader,
            'http://127.0.0.1:${target.port}/outside.png',
          );
      }
      await request.response.close();
    });
    final base = 'http://127.0.0.1:${source.port}';
    final redirect = await HttpOverrides.runWithHttpOverrides(
      () => service.get(
        '$base/redirect',
        headers: const {'Cookie': 'popi_access=secret'},
      ),
      _LoopbackHttpOverrides(),
    );
    expect(redirect.statusCode, HttpStatus.found);
    await redirect.content.drain<void>();
    expect(targetRequests, 0);

    final public = await HttpOverrides.runWithHttpOverrides(
      () => service.get('$base/redirect'),
      _LoopbackHttpOverrides(),
    );
    expect(public.statusCode, HttpStatus.ok);
    expect(await public.content.expand((chunk) => chunk).toList(), [4, 5, 6]);
    expect(targetRequests, 1);
    expect(targetCookie, isNull);

    final denied = await HttpOverrides.runWithHttpOverrides(
      () => service.get(
        '$base/unauthorized',
        headers: const {'Cookie': 'popi_access=secret'},
      ),
      _LoopbackHttpOverrides(),
    );
    expect(denied.statusCode, HttpStatus.unauthorized);
    await denied.content.drain<void>();
    expect(unauthorized, 1);
  });

  test('image requests stop waiting for a stalled response body', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final keepOpen = Completer<void>();
    addTearDown(() {
      if (!keepOpen.isCompleted) keepOpen.complete();
    });
    server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('image', 'png')
        ..write([1, 2, 3]);
      await request.response.flush();
      await keepOpen.future;
      await request.response.close();
    });
    final service = createAppImageFileService(
      onUnauthorized: (_, __) {},
      timeout: const Duration(milliseconds: 50),
    );

    final response = await HttpOverrides.runWithHttpOverrides(
      () => service.get('http://127.0.0.1:${server.port}/stalled.png'),
      _LoopbackHttpOverrides(),
    );

    await expectLater(
      response.content.drain<void>(),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('image requests stop waiting for response headers', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final keepOpen = Completer<void>();
    addTearDown(() {
      if (!keepOpen.isCompleted) keepOpen.complete();
    });
    server.listen((request) => keepOpen.future);
    final service = createAppImageFileService(
      onUnauthorized: (_, __) {},
      timeout: const Duration(milliseconds: 50),
    );

    await expectLater(
      HttpOverrides.runWithHttpOverrides(
        () => service.get('http://127.0.0.1:${server.port}/no-headers.png'),
        _LoopbackHttpOverrides(),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}

class _LoopbackHttpOverrides extends HttpOverrides {}
