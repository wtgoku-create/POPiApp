import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/gallery_image_storage.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_image_preview.dart';
import 'package:popi_ai_app/shared/widgets/app_media_preview.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'support/fake_video_player.dart';

void main() {
  final boundaryKey = GlobalKey();
  const galleryChannel = MethodChannel('gal');
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(galleryChannel, null),
  );
  Future<void> openPreview(
    WidgetTester tester, {
    bool reduceMotion = false,
    bool settle = true,
    String imageAsset = 'assets/images/assets_works_gallery_01.png',
    List<ImagePreviewItem>? images,
    List<MediaPreviewItem>? media,
    int initialIndex = 0,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final image = AssetImage(imageAsset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: RepaintBoundary(key: boundaryKey, child: child!),
        ),
        home: Builder(
          builder: (context) => Scaffold(
            key: const Key('underlying-screen'),
            body: Center(
              child: GestureDetector(
                key: const Key('thumbnail'),
                onTap: () => media != null
                    ? AppMediaPreview.showGallery(
                        context: context,
                        items: media,
                        initialIndex: initialIndex,
                      )
                    : images == null
                    ? AppImagePreview.show(
                        context: context,
                        image: image,
                        heroTag: 'test-image',
                      )
                    : AppImagePreview.showGallery(
                        context: context,
                        images: images,
                        initialIndex: initialIndex,
                      ),
                child: Hero(
                  tag: 'test-image',
                  child: Image(
                    image: image,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final context = tester.element(find.byKey(const Key('thumbnail')));
      await precacheImage(image, context);
      for (final item in media ?? images ?? <MediaPreviewItem>[]) {
        if (context.mounted && item.previewImage != null) {
          await precacheImage(item.previewImage!, context);
        }
      }
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('thumbnail')));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
    }
  }

  final galleryImages = [
    for (var index = 0; index < 3; index++)
      ImagePreviewItem(
        image: AssetImage(
          'assets/images/assets_works_gallery_0${index + 1}.png',
        ),
        heroTag: index == 0 ? 'test-image' : 'test-image-$index',
      ),
  ];

  double currentPage(WidgetTester tester) => tester
      .widget<PageView>(find.byKey(const Key('asset-preview-gallery')))
      .controller!
      .page!;

  final mixedMedia = <MediaPreviewItem>[
    galleryImages[0],
    VideoPreviewItem(
      url: Uri.parse('https://example.test/first.mp4'),
      heroTag: 'video-1',
    ),
    galleryImages[1],
    VideoPreviewItem(
      url: Uri.parse('https://example.test/second.mp4'),
      heroTag: 'video-2',
      thumbnail: galleryImages[2].image,
    ),
  ];

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets(
      'mixed gallery swipes image-video-image with ${kind.name} and releases video',
      (tester) async {
        final original = VideoPlayerPlatform.instance;
        final platform = FakeVideoPlayer();
        VideoPlayerPlatform.instance = platform;
        addTearDown(() => VideoPlayerPlatform.instance = original);
        await openPreview(tester, media: mixedMedia);
        expect(platform.sources, isEmpty);
        await tester.drag(
          find.byKey(const Key('asset-preview-image')),
          const Offset(-300, 0),
          kind: kind,
        );
        await tester.pumpAndSettle();
        expect(currentPage(tester), 1);
        expect(find.byType(VideoPlayer), findsOneWidget);
        expect(platform.sources.single.uri, 'https://example.test/first.mp4');
        expect(platform.playing, isTrue);
        await tester.drag(
          find.byKey(const Key('asset-preview-video')),
          const Offset(-300, 0),
          kind: kind,
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        expect(currentPage(tester), 2);
        expect(find.byType(VideoPlayer), findsNothing);
        expect(platform.disposed, [1]);
        expect(platform.playing, isFalse);
        await tester.tap(find.byKey(const Key('asset-preview-thumbnail-3')));
        await tester.pumpAndSettle();
        expect(currentPage(tester), 3);
        expect(platform.sources.last.uri, 'https://example.test/second.mp4');
        expect(platform.playing, isTrue);
        await tester.tap(find.byKey(const Key('asset-preview-thumbnail-1')));
        await tester.pumpAndSettle();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        expect(platform.disposed, [1, 2]);
        expect(platform.sources.last.uri, 'https://example.test/first.mp4');
        await tester.tap(find.byKey(const Key('asset-preview-close')));
        await tester.pumpAndSettle();
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        expect(platform.disposed, [1, 2, 3]);
        expect(platform.playing, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'mixed gallery opens a loading video and switching away cancels initialization',
    (tester) async {
      final original = VideoPlayerPlatform.instance;
      final platform = FakeVideoPlayer()..autoInitialize = false;
      VideoPlayerPlatform.instance = platform;
      addTearDown(() => VideoPlayerPlatform.instance = original);
      await openPreview(
        tester,
        media: mixedMedia,
        initialIndex: 1,
        settle: false,
      );
      expect(currentPage(tester), 1);
      expect(platform.sources, hasLength(1));
      expect(platform.playing, isFalse);
      await tester.tap(find.byKey(const Key('asset-preview-thumbnail-0')));
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(platform.disposed, [1]);
      expect(currentPage(tester), 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(320, 568), const Size(1280, 900)]) {
    for (final videoSize in [const Size(1920, 1080), const Size(1080, 1920)]) {
      testWidgets('mixed video controls fit $size with video $videoSize', (
        tester,
      ) async {
        final original = VideoPlayerPlatform.instance;
        final platform = FakeVideoPlayer()..videoSize = videoSize;
        VideoPlayerPlatform.instance = platform;
        addTearDown(() => VideoPlayerPlatform.instance = original);
        await openPreview(
          tester,
          media: mixedMedia,
          initialIndex: 1,
          size: size,
        );
        final video = tester.getRect(find.byType(VideoPlayer));
        final toolbar = tester.getRect(
          find.byKey(const Key('asset-preview-close')),
        );
        final strip = tester.getRect(
          find.byKey(const Key('asset-preview-thumbnails')),
        );
        expect(video.top, greaterThan(toolbar.bottom));
        expect(video.bottom, lessThan(strip.top));
        expect(video.left, greaterThanOrEqualTo(0));
        expect(video.right, lessThanOrEqualTo(size.width));
        final seek = tester.getRect(
          find.byKey(const Key('video-preview-seek')),
        );
        expect(seek.bottom, lessThan(strip.top));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('asset-preview-close')));
        await tester.pumpAndSettle();
      });
    }
  }

  for (final size in [const Size(320, 568), const Size(1280, 900)]) {
    testWidgets('long gallery reveals selected thumbnail and fits $size', (
      tester,
    ) async {
      await openPreview(
        tester,
        size: size,
        initialIndex: 19,
        images: [
          for (var index = 0; index < 20; index++)
            ImagePreviewItem(
              image: galleryImages[index % 3].image,
              heroTag: 'long-gallery-$index',
            ),
        ],
      );
      expect(currentPage(tester), 19);
      final last = find.byKey(const Key('asset-preview-thumbnail-19'));
      expect(last.hitTestable(), findsOneWidget);
      expect(find.byKey(const Key('asset-preview-thumbnail-0')), findsNothing);
      final toolbar = tester.getRect(
        find.byKey(const Key('asset-preview-share')),
      );
      expect(toolbar.right, lessThanOrEqualTo(size.width - 20));
      final strip = tester.getRect(
        find.byKey(const Key('asset-preview-thumbnails')),
      );
      expect(strip.width, lessThanOrEqualTo(310));
      expect(strip.bottom, size.height - 20);
      if (const bool.fromEnvironment('CAPTURE_IMAGE_PREVIEW')) {
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/popi-gallery-${size.width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(find.byKey(const Key('asset-preview-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('asset-preview-gallery')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('gallery opens selected image, swipes and jumps via thumbnails', (
    tester,
  ) async {
    await openPreview(tester, images: galleryImages, initialIndex: 1);
    expect(currentPage(tester), 1);
    await tester.drag(
      find.byKey(const Key('asset-preview-gallery')),
      const Offset(-320, 0),
    );
    await tester.pumpAndSettle();
    expect(currentPage(tester), 2);
    await tester.tap(find.byKey(const Key('asset-preview-thumbnail-0')));
    await tester.pumpAndSettle();
    expect(currentPage(tester), 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(currentPage(tester), 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('asset-preview-gallery')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('gallery swipes both ways over the image with ${kind.name}', (
      tester,
    ) async {
      final size = kind == PointerDeviceKind.mouse
          ? const Size(1280, 900)
          : const Size(390, 844);
      await openPreview(
        tester,
        images: galleryImages,
        initialIndex: 1,
        size: size,
      );
      final preview = find.byKey(const Key('asset-preview-image'));
      final swipe = Offset(size.width * .7, 0);
      Future<void> drag(Offset offset) async {
        await tester.drag(preview, offset, kind: kind);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('asset-preview-gallery')), findsOneWidget);
      }

      await drag(-swipe);
      expect(currentPage(tester), 2);
      await drag(-swipe);
      expect(currentPage(tester), 2);
      await drag(swipe);
      expect(currentPage(tester), 1);
      await drag(swipe);
      expect(currentPage(tester), 0);
      await drag(swipe);
      expect(currentPage(tester), 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets(
      'zoom locks ${kind.name} paging and resets when a thumbnail changes image',
      (tester) async {
        await openPreview(tester, images: galleryImages);
        final preview = find.byKey(const Key('asset-preview-image'));
        await tester.tap(preview);
        await tester.pump(const Duration(milliseconds: 60));
        await tester.tap(preview);
        await tester.pumpAndSettle();
        await tester.drag(preview, const Offset(-320, 0), kind: kind);
        await tester.pumpAndSettle();
        expect(currentPage(tester), 0);
        await tester.tap(find.byKey(const Key('asset-preview-thumbnail-1')));
        await tester.pumpAndSettle();
        expect(currentPage(tester), 1);
        await tester.tap(find.byKey(const Key('asset-preview-thumbnail-0')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<InteractiveViewer>(preview)
              .transformationController!
              .value
              .getMaxScaleOnAxis(),
          1,
        );
        await tester.drag(preview, const Offset(-320, 0), kind: kind);
        await tester.pumpAndSettle();
        expect(currentPage(tester), 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('download and share use the currently selected original image', (
    tester,
  ) async {
    late Completer<List<int>> saved;
    late Completer<Map> shared;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final directory = Directory.systemTemp.createTempSync('popi-preview-test-');
    addTearDown(() => directory.deleteSync(recursive: true));
    addTearDown(() => messenger.setMockMethodCallHandler(shareChannel, null));
    addTearDown(() => messenger.setMockMethodCallHandler(pathChannel, null));
    messenger.setMockMethodCallHandler(galleryChannel, (call) async {
      if (call.method == 'hasAccess' || call.method == 'requestAccess') {
        return true;
      }
      if (call.method == 'putImageBytes') {
        saved.complete((call.arguments as Map)['bytes'] as List<int>);
      }
      return null;
    });
    messenger.setMockMethodCallHandler(
      pathChannel,
      (_) async => directory.path,
    );
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      shared.complete(call.arguments as Map);
      return '';
    });
    await openPreview(tester, images: galleryImages, initialIndex: 2);
    await tester.runAsync(() async {
      saved = Completer<List<int>>();
      shared = Completer<Map>();
      final expected = await GalleryImageStorage.readPng(
        galleryImages[2].image,
        const ImageConfiguration(),
      );
      tester
          .widget<IconButton>(find.byKey(const Key('asset-preview-download')))
          .onPressed!();
      expect(
        await saved.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () =>
              throw StateError('Download did not reach gallery channel'),
        ),
        expected,
      );
      tester
          .widget<IconButton>(find.byKey(const Key('asset-preview-share')))
          .onPressed!();
      final arguments = await shared.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw StateError('Share did not reach native channel'),
      );
      final path = (arguments['paths'] as List).single as String;
      expect(await File(path).readAsBytes(), expected);
      expect(arguments['mimeTypes'], ['image/png']);
      expect(arguments['originWidth'], 40);
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('asset-preview-image')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens above the current screen and closes to the thumbnail', (
    tester,
  ) async {
    await openPreview(tester);
    expect(find.byKey(const Key('asset-preview-image')), findsOneWidget);
    expect(find.byKey(const Key('underlying-screen')), findsOneWidget);
    final route = ModalRoute.of(
      tester.element(find.byKey(const Key('asset-preview-image'))),
    )!;
    expect(route.opaque, isFalse);
    expect(route.transitionDuration, const Duration(milliseconds: 300));
    expect(route.reverseTransitionDuration, const Duration(milliseconds: 220));
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(Hero), findsNWidgets(2));
    if (const bool.fromEnvironment('CAPTURE_IMAGE_PREVIEW')) {
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/tmp/popi-image-preview.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    expect(find.byKey(const Key('asset-preview-back')), findsNothing);
    expect(find.byKey(const Key('asset-preview-download')), findsOneWidget);
    final download = tester.getRect(
      find.byKey(const Key('asset-preview-download')),
    );
    expect(download.right, 320);
    expect(download.top, 20);
    expect(find.byKey(const Key('asset-preview-close')), findsOneWidget);
    expect(find.byKey(const Key('asset-preview-share')), findsOneWidget);
    final button = tester.widget<IconButton>(
      find.byKey(const Key('asset-preview-download')),
    );
    final shape = button.style!.shape!.resolve({})! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(10));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('asset-preview-image')), findsNothing);
    expect(find.byKey(const Key('thumbnail')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short drag rebounds and downward drag dismisses', (
    tester,
  ) async {
    await openPreview(tester);
    final preview = find.byKey(const Key('asset-preview-image'));
    final original = tester.getTopLeft(preview);
    await tester.drag(preview, const Offset(0, 50));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(preview), original);
    await tester.drag(preview, const Offset(0, 160));
    await tester.pumpAndSettle();
    expect(preview, findsNothing);
    expect(tester.takeException(), isNull);
  });

  Rect largestPaintedImage(WidgetTester tester) {
    final bounds = find.byType(RawImage).evaluate().map((element) {
      final render = element.findRenderObject()! as RenderImage;
      final image = render.image!;
      final size = applyBoxFit(
        render.fit ?? BoxFit.scaleDown,
        Size(image.width / render.scale, image.height / render.scale),
        render.size,
      ).destination;
      final rect = render.alignment
          .resolve(TextDirection.ltr)
          .inscribe(size, Offset.zero & render.size);
      return MatrixUtils.transformRect(render.getTransformTo(null), rect);
    }).toList();
    bounds.sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));
    return bounds.first;
  }

  for (final asset in [
    'assets/images/assets_works_gallery_01.png',
    'assets/images/assets_works_selection_01.png',
    'assets/images/assets_works_selection_04.png',
  ]) {
    for (final drag in [false, true]) {
      testWidgets('closing $asset never enlarges the image with drag=$drag', (
        tester,
      ) async {
        await openPreview(tester, imageAsset: asset);
        final preview = find.byKey(const Key('asset-preview-image'));
        TestGesture? gesture;
        if (drag) {
          gesture = await tester.startGesture(tester.getCenter(preview));
          await gesture.moveBy(const Offset(0, 160));
          await tester.pump();
        }
        var previous = largestPaintedImage(tester);
        if (gesture != null) {
          await gesture.up();
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pump();
        for (var frame = 0; frame < 14; frame++) {
          final current = largestPaintedImage(tester);
          expect(current.width, lessThanOrEqualTo(previous.width + .01));
          expect(current.height, lessThanOrEqualTo(previous.height + .01));
          previous = current;
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();
        expect(preview, findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('tap closing preserves the zoom until the return flight starts', (
    tester,
  ) async {
    await openPreview(tester);
    final preview = find.byKey(const Key('asset-preview-image'));
    await tester.tap(preview);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(preview);
    await tester.pumpAndSettle();
    final controller = tester
        .widget<InteractiveViewer>(preview)
        .transformationController!;
    final before = largestPaintedImage(tester);
    await tester.tap(preview);
    await tester.pump(const Duration(milliseconds: 310));
    expect(controller.value.getMaxScaleOnAxis(), 2.5);
    final start = largestPaintedImage(tester);
    expect(start.width, closeTo(before.width, .01));
    expect(start.height, closeTo(before.height, .01));
    await tester.pumpAndSettle();
    expect(preview, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('double tap zooms and panning a zoomed image does not dismiss', (
    tester,
  ) async {
    await openPreview(tester);
    final preview = find.byKey(const Key('asset-preview-image'));
    await tester.tap(preview);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(preview);
    await tester.pumpAndSettle();
    final controller = tester
        .widget<InteractiveViewer>(preview)
        .transformationController!;
    expect(controller.value.getMaxScaleOnAxis(), 2.5);
    await tester.drag(preview, const Offset(0, 160));
    await tester.pumpAndSettle();
    expect(preview, findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(preview, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion opens and dismisses without a transition', (
    tester,
  ) async {
    await openPreview(tester, reduceMotion: true);
    final context = tester.element(
      find.byKey(const Key('asset-preview-image')),
    );
    expect(
      (ModalRoute.of(context)! as PageRoute).transitionDuration,
      Duration.zero,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('asset-preview-image')), findsNothing);
  });

  testWidgets(
    'download saves full-resolution PNG bytes and keeps the preview open',
    (tester) async {
      MethodCall? saved;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(galleryChannel, (call) async {
            if (call.method == 'hasAccess' || call.method == 'requestAccess') {
              return true;
            }
            if (call.method == 'putImageBytes') saved = call;
            return null;
          });
      await openPreview(tester);
      await tester.runAsync(() async {
        await GalleryImageStorage.save(
          const AssetImage('assets/images/assets_works_gallery_01.png'),
          const ImageConfiguration(),
        );
        final call = saved!;
        final bytes = (call.arguments as Map)['bytes'] as List<int>;
        expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('asset-preview-image')), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('asset-preview-download')))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('denied gallery permission does not save and allows retry', (
    tester,
  ) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(galleryChannel, (call) async {
          calls.add(call.method);
          return false;
        });
    await openPreview(tester);
    await tester.tap(find.byKey(const Key('asset-preview-download')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(calls, ['hasAccess', 'requestAccess']);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('asset-preview-image')), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('asset-preview-download')))
          .onPressed,
      isNotNull,
    );
  });
}
