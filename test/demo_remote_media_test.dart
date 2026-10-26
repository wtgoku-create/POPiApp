import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/storage/app_image_cache.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_remote_media.dart';
import 'package:popi_ai_app/features/assets/domain/library_work.dart';
import 'package:popi_ai_app/features/assets/presentation/library_work_thumbnail.dart';
import 'package:popi_ai_app/shared/providers/harness_access_provider.dart';

const _remoteImage = DemoAsset(
  id: 'remote-image',
  title: 'Remote image',
  kind: DemoAssetKind.image,
  cover: 'https://harness.test/api_agent/v2/assets/remote-image/content',
  contentUrl: 'https://harness.test/api_agent/v2/assets/remote-image/content',
  thumbnailUrl:
      'https://harness.test/api_agent/v2/assets/remote-image/thumbnail',
  mimeType: 'image/png',
  width: 4096,
  height: 4096,
);

const _offlineVideo = DemoAsset(
  id: 'offline-video',
  title: 'Offline video',
  kind: DemoAssetKind.video,
  cover: 'assets/images/demo_weekend.png',
  media: 'assets/images/demo_video.mp4',
);

class _FailingImageCache implements BaseCacheManager {
  _FailingImageCache(this.thumbnailStatus);

  final int thumbnailStatus;
  final requestedUrls = <String>[];

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
    requestedUrls.add(url);
    final status = url.endsWith('/thumbnail') ? thumbnailStatus : 500;
    throw HttpExceptionWithStatus(
      status,
      'fixture failure',
      uri: Uri.parse(url),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'remote card and image-stack thumbnails request bounded decode widths',
    () {
      const headers = {
        'Cookie': '__Host-popi-test=private-session',
        'Origin': 'https://harness.test',
      };
      const cacheKey = 'remote-image::11111111-1111-4111-8111-111111111111';
      var unauthorized = 0;

      for (final width in [162, 900]) {
        final thumbnail = demoAssetImageProvider(
          _remoteImage,
          headers: headers,
          cacheKey: cacheKey,
          onUnauthorized: () => unauthorized++,
          cacheWidth: width,
          preferThumbnail: true,
        );

        expect(thumbnail, isA<ResizeImage>());
        final resized = thumbnail as ResizeImage;
        expect(resized.width, width);
        expect(resized.height, isNull);
        expect(resized.imageProvider, isA<CachedNetworkImageProvider>());
        final network = resized.imageProvider as CachedNetworkImageProvider;
        expect(network.url, _remoteImage.thumbnailUrl);
        expect(network.headers, headers);
        expect(network.cacheKey, cacheKey);
        expect(network.cacheKey, isNot(contains(headers['Cookie']!)));
      }

      expect(unauthorized, 0);
    },
  );

  test('full-size remote preview keeps the original image provider', () {
    const headers = {
      'Cookie': '__Host-popi-test=private-session',
      'Origin': 'https://harness.test',
    };
    const cacheKey = 'remote-image::22222222-2222-4222-8222-222222222222';

    final preview = demoAssetImageProvider(
      _remoteImage,
      headers: headers,
      cacheKey: cacheKey,
      onUnauthorized: () {},
    );

    expect(preview, isA<CachedNetworkImageProvider>());
    final network = preview as CachedNetworkImageProvider;
    expect(network.url, _remoteImage.contentUrl);
    expect(network.headers, headers);
    expect(network.cacheKey, cacheKey);
  });

  testWidgets(
    'inline remote image authenticates and caches the thumbnail URL',
    (tester) async {
      final requestedUrls = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            harnessAccessHeadersProvider.overrideWith((ref, url) {
              requestedUrls.add('headers:$url');
              return const {
                'Cookie': '__Host-popi-test=private-session',
                'Origin': 'https://harness.test',
              };
            }),
            harnessAccessCacheKeyProvider.overrideWith((ref, url) {
              requestedUrls.add('cache:$url');
              return '$url::session';
            }),
            harnessAccessUnauthorizedProvider.overrideWith((ref, url) => () {}),
          ],
          child: const MaterialApp(
            home: DemoAssetImage(
              asset: _remoteImage,
              width: 160,
              height: 160,
              cacheWidth: 320,
            ),
          ),
        ),
      );
      await tester.pump();

      final resized =
          tester.widget<Image>(find.byType(Image)).image as ResizeImage;
      final network = resized.imageProvider as CachedNetworkImageProvider;
      expect(network.url, _remoteImage.thumbnailUrl);
      expect(network.cacheKey, '${_remoteImage.thumbnailUrl}::session');
      expect(network.headers, containsPair('Origin', 'https://harness.test'));
      expect(requestedUrls, [
        'headers:${_remoteImage.thumbnailUrl}',
        'cache:${_remoteImage.thumbnailUrl}',
      ]);
    },
  );

  test('legacy image without a thumbnail falls back to original content', () {
    const legacy = DemoAsset(
      id: 'legacy-image',
      title: 'Legacy image',
      kind: DemoAssetKind.image,
      cover: 'https://harness.test/api_agent/v2/assets/legacy-image/content',
      contentUrl:
          'https://harness.test/api_agent/v2/assets/legacy-image/content',
    );
    expect(demoAssetImageUrl(legacy, preferThumbnail: true), legacy.contentUrl);
  });

  testWidgets('offline video keeps its bundled cover without a poster URL', (
    tester,
  ) async {
    final provider = demoAssetImageProvider(_offlineVideo);
    expect(provider, isA<AssetImage>());

    await tester.pumpWidget(
      const MaterialApp(
        home: DemoAssetImage(asset: _offlineVideo, width: 160, height: 160),
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
    expect((image.image as AssetImage).assetName, _offlineVideo.cover);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing thumbnail falls back to original content once', (
    tester,
  ) async {
    final original = AppImageCache.debugCacheManager;
    final cache = _FailingImageCache(404);
    AppImageCache.debugCacheManager = cache;
    addTearDown(() => AppImageCache.debugCacheManager = original);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DemoAssetImage(asset: _remoteImage)),
      ),
    );
    await tester.pumpAndSettle();

    expect(cache.requestedUrls, [
      _remoteImage.thumbnailUrl,
      _remoteImage.contentUrl,
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unauthorized thumbnail does not retry with original content', (
    tester,
  ) async {
    final original = AppImageCache.debugCacheManager;
    final cache = _FailingImageCache(401);
    AppImageCache.debugCacheManager = cache;
    addTearDown(() => AppImageCache.debugCacheManager = original);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DemoAssetImage(asset: _remoteImage)),
      ),
    );
    await tester.pumpAndSettle();

    expect(cache.requestedUrls, [_remoteImage.thumbnailUrl]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selected work keeps original fallback across equal-list parent rebuilds',
    (tester) async {
      final original = AppImageCache.debugCacheManager;
      final cache = _FailingImageCache(404);
      AppImageCache.debugCacheManager = cache;
      addTearDown(() => AppImageCache.debugCacheManager = original);
      const thumbnail =
          'https://harness.test/api_agent/v2/assets/work/thumbnail';
      const content = 'https://harness.test/api_agent/v2/assets/work/content';

      Widget app(LibraryWork work) => ProviderScope(
        child: MaterialApp(home: LibraryWorkThumbnail(work: work)),
      );

      await tester.pumpWidget(
        app(
          const LibraryWork(
            id: 'work',
            previewUrl: thumbnail,
            imageUrls: [content],
            isVideo: false,
            createdAt: null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(cache.requestedUrls, [thumbnail, content]);

      await tester.pumpWidget(
        app(
          LibraryWork(
            id: 'work',
            previewUrl: thumbnail,
            imageUrls: <String>[content],
            isVideo: false,
            createdAt: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        cache.requestedUrls.where((url) => url == thumbnail),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
