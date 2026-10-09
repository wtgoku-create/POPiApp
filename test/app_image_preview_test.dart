import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/storage/gallery_image_storage.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_image_preview.dart';

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
    String imageAsset = 'assets/images/assets_works_gallery_01.png',
  }) async {
    tester.view.physicalSize = const Size(390, 844);
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
                onTap: () => AppImagePreview.show(
                  context: context,
                  image: image,
                  heroTag: 'test-image',
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
    await tester.runAsync(
      () => precacheImage(
        image,
        tester.element(find.byKey(const Key('thumbnail'))),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('thumbnail')));
    await tester.pumpAndSettle();
  }

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
