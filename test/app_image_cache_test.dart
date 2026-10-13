import 'dart:io';

import 'package:file/file.dart' as fs;
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/shared/widgets/app_network_image.dart';

final _imageBytes = File(
  'assets/icons/common_user_avatar.png',
).readAsBytesSync();

class _DirectoryFiles implements FileSystem {
  _DirectoryFiles(this.directory);
  final Directory directory;

  @override
  Future<fs.File> createFile(String name) async =>
      const LocalFileSystem().file('${directory.path}/$name');
}

class _RealHttp extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late HttpServer server;
  late CacheManager manager;
  late String url;
  var requests = 0;
  var failNext = false;
  final requestHeaders = <String?>[];
  BaseCacheManager? original;

  CacheManager createManager() => HttpOverrides.runWithHttpOverrides(
    () => CacheManager(
      Config(
        'image-cache-test',
        fileSystem: _DirectoryFiles(directory),
        repo: JsonCacheInfoRepository.withFile(
          File('${directory.path}/cache.json'),
        ),
      ),
    ),
    _RealHttp(),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('popi-image-cache-');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    url = 'http://127.0.0.1:${server.port}/cover.png';
    requests = 0;
    failNext = false;
    requestHeaders.clear();
    server.listen((request) async {
      requests++;
      requestHeaders.add(request.headers.value(HttpHeaders.ifNoneMatchHeader));
      if (failNext) {
        failNext = false;
        request.response.statusCode = HttpStatus.internalServerError;
      } else {
        request.response.headers
          ..contentType = ContentType('image', 'png')
          ..set(HttpHeaders.cacheControlHeader, 'max-age=3600')
          ..set(HttpHeaders.etagHeader, 'cover-v1');
        if (request.headers.value(HttpHeaders.ifNoneMatchHeader) ==
            'cover-v1') {
          request.response.statusCode = HttpStatus.notModified;
        } else {
          request.response.add(_imageBytes);
        }
      }
      await request.response.close();
    });
    original = AppImageCache.debugCacheManager;
    manager = createManager();
    AppImageCache.debugCacheManager = manager;
  });

  tearDown(() async {
    AppImageCache.debugCacheManager = original;
    await manager.dispose();
    await server.close(force: true);
    await directory.delete(recursive: true);
  });

  test(
    'concurrent covers share a download and disk cache survives reopening',
    () async {
      final files = await Future.wait([
        manager.getSingleFile(url),
        manager.getSingleFile(url),
      ]);
      expect(requests, 1);
      expect(await files.first.readAsBytes(), _imageBytes);
      expect(files.first.path, files.last.path);

      await manager.dispose();
      manager = createManager();
      AppImageCache.debugCacheManager = manager;
      final restored = await manager.getSingleFile(url);
      expect(await restored.readAsBytes(), _imageBytes);
      expect(requests, 1);
      expect(restored.path, files.first.path);
    },
  );

  test('expired images revalidate with their ETag', () async {
    await manager.putFile(
      url,
      _imageBytes,
      eTag: 'cover-v1',
      maxAge: const Duration(seconds: -1),
      fileExtension: 'png',
    );
    final refreshed = await manager.getSingleFile(url);
    expect(await refreshed.readAsBytes(), _imageBytes);
    expect(requestHeaders, ['cover-v1']);
    expect(
      (await manager.getFileFromCache(url))!.validTill.isAfter(DateTime.now()),
      isTrue,
    );
  });

  test(
    'changed URL versions stay distinct and eviction forces a fresh download',
    () async {
      final first = '$url?version=1&signature=first';
      final next = '$url?version=2&signature=next';
      expect(
        AppImageCache.provider(first),
        isNot(AppImageCache.provider(next)),
      );
      final files = await Future.wait([
        manager.getSingleFile(first),
        manager.getSingleFile(next),
      ]);
      expect(files.first.path, isNot(files.last.path));
      expect(requests, 2);
      await AppImageCache.evict(first);
      expect(await manager.getFileFromCache(first), isNull);
      expect(await manager.getFileFromCache(next), isNotNull);
      await manager.getSingleFile(first);
      expect(requests, 3);
    },
  );

  test(
    'failed downloads are retryable and do not become cached covers',
    () async {
      failNext = true;
      await expectLater(
        manager.getSingleFile(url),
        throwsA(isA<HttpExceptionWithStatus>()),
      );
      expect(await manager.getFileFromCache(url), isNull);
      final file = await manager.getSingleFile(url);
      expect(await file.readAsBytes(), _imageBytes);
      expect(requests, 2);
    },
  );

  testWidgets('cached image survives a new page without a new request', (
    tester,
  ) async {
    await tester.runAsync(() => manager.getSingleFile(url));
    Future<void> showImage() async {
      await tester.pumpWidget(
        const MaterialApp(home: SizedBox(key: Key('image-cache-page'))),
      );
      await tester.runAsync(
        () => precacheImage(
          AppImageCache.provider(url),
          tester.element(find.byKey(const Key('image-cache-page'))),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: AppNetworkImage(url, width: 80, height: 80)),
        ),
      );
      await tester.pumpAndSettle();
    }

    await showImage();
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(tester.getSize(find.byType(Image)), const Size(80, 80));
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => AppImageCache.provider(url).evict());
    await showImage();
    expect(requests, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
