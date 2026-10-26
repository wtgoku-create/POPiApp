import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_remote_media.dart';
import 'package:popi_ai_app/features/demo/presentation/widgets/demo_image_stack.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';

const _images = [
  DemoAsset(
    id: 'scene-1',
    title: '场景一',
    kind: DemoAssetKind.image,
    cover: 'assets/images/demo_scene_1.png',
    width: 1672,
    height: 941,
  ),
  DemoAsset(
    id: 'scene-2',
    title: '场景二',
    kind: DemoAssetKind.image,
    cover: 'assets/images/demo_scene_2.png',
    width: 4096,
    height: 2286,
  ),
  DemoAsset(
    id: 'scene-3',
    title: '场景三',
    kind: DemoAssetKind.image,
    cover: 'assets/images/demo_scene_3.png',
    width: 540,
    height: 788,
  ),
  DemoAsset(
    id: 'scene-4',
    title: '场景四',
    kind: DemoAssetKind.image,
    cover: 'assets/images/demo_scene_4.png',
    width: 1600,
    height: 900,
  ),
  DemoAsset(
    id: 'scene-5',
    title: '场景五',
    kind: DemoAssetKind.image,
    cover: 'assets/images/demo_scene_5.png',
    width: 2286,
    height: 4096,
  ),
];

Future<void> _pumpDeck(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 700),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('fan exposes three rear cards and previews the current page', (
    tester,
  ) async {
    var index = 0;
    await _pumpDeck(
      tester,
      DemoImageStack(
        images: _images,
        messageId: 'fan',
        initialIndex: 0,
        onChanged: (value) => index = value,
      ),
    );

    expect(find.text('5 张图片'), findsOneWidget);
    expect(find.text('1/5'), findsOneWidget);
    final front = find.byWidgetPredicate(
      (widget) =>
          widget is DemoAssetImage && widget.asset.id == _images.first.id,
    );
    await tester.runAsync(
      () => precacheImage(
        demoAssetImageProvider(_images.first, cacheWidth: 900),
        tester.element(front),
      ),
    );
    await tester.pump();
    final rendered = tester.renderObject<RenderImage>(
      find.descendant(of: front, matching: find.byType(RawImage)),
    );
    final decoded = rendered.image!;
    final sourceSize = Size(
      decoded.width.toDouble(),
      decoded.height.toDouble(),
    );
    final fitted = applyBoxFit(
      rendered.fit ?? BoxFit.scaleDown,
      sourceSize,
      rendered.size,
    );
    expect(fitted.source, sourceSize);
    for (final depth in [1, 2, 3]) {
      expect(
        find.byKey(ValueKey('demo-image-stack-rear-$depth')),
        findsOneWidget,
      );
    }

    final deck = find.byType(DemoImageStack);
    await tester.drag(deck, const Offset(-220, 0));
    await tester.pumpAndSettle();
    expect(index, 1);
    expect(find.text('2/5'), findsOneWidget);

    // The exposed right edge belongs to the whole fan's preview target.
    await tester.tapAt(tester.getTopRight(deck) + const Offset(-8, 90));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final preview = find.byKey(const Key('asset-preview-image'));
    expect(preview, findsOneWidget);
    expect(
      tester
          .widget<Image>(
            find.descendant(of: preview, matching: find.byType(Image)),
          )
          .image,
      const AssetImage('assets/images/demo_scene_2.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('updated image lists preserve or safely clamp the visible page', (
    tester,
  ) async {
    final key = GlobalKey<_DeckHarnessState>();
    final changes = <int>[];
    await _pumpDeck(tester, _DeckHarness(key: key, onChanged: changes.add));

    expect(find.text('5/5'), findsOneWidget);
    key.currentState!.replace([_images[4], _images[0], _images[1]]);
    await tester.pumpAndSettle();
    expect(find.text('1/3'), findsOneWidget);

    key.currentState!.replace([_images[0], _images[1]]);
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
    expect(changes, containsAllInOrder([0, 1]));
    expect(tester.takeException(), isNull);
  });

  testWidgets('known landscape and portrait sets keep one stable frame shape', (
    tester,
  ) async {
    await _pumpDeck(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DemoImageStack(
            key: const Key('landscape-deck'),
            images: _images,
            messageId: 'landscape',
            initialIndex: 0,
            onChanged: (_) {},
          ),
          DemoImageStack(
            key: const Key('portrait-deck'),
            images: [_images[2], _images[4], _images[0]],
            messageId: 'portrait',
            initialIndex: 0,
            onChanged: (_) {},
          ),
        ],
      ),
    );

    Size imageSize(Finder deck, String id) {
      final image = find.descendant(
        of: deck,
        matching: find.byWidgetPredicate(
          (widget) => widget is DemoAssetImage && widget.asset.id == id,
        ),
      );
      return tester.getSize(
        find.descendant(of: image, matching: find.byType(RawImage)),
      );
    }

    final landscape = find.byKey(const Key('landscape-deck'));
    final portrait = find.byKey(const Key('portrait-deck'));
    final landscapeImage = imageSize(landscape, 'scene-1');
    final portraitImage = imageSize(portrait, 'scene-3');
    expect(landscapeImage.width, greaterThan(landscapeImage.height));
    expect(portraitImage.height, greaterThan(portraitImage.width));

    final stableSize = tester.getSize(landscape);
    await tester.drag(landscape, const Offset(-220, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(landscape), stableSize);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow 3x-text deck keeps its caption inside the layout', (
    tester,
  ) async {
    await _pumpDeck(
      tester,
      SizedBox(
        width: 190,
        child: DemoImageStack(
          images: _images,
          messageId: 'narrow',
          initialIndex: 0,
          onChanged: (_) {},
        ),
      ),
      size: const Size(240, 600),
      textScale: 3,
    );

    expect(find.text('5 张图片'), findsOneWidget);
    expect(find.text('1/5'), findsOneWidget);
    final deck = tester.getRect(find.byType(DemoImageStack));
    for (final caption in [find.text('5 张图片'), find.text('1/5')]) {
      final rect = tester.getRect(caption);
      expect(rect.top, greaterThanOrEqualTo(deck.top));
      expect(rect.bottom, lessThanOrEqualTo(deck.bottom));
    }
    expect(deck.width, 190);
    expect(tester.takeException(), isNull);
  });
}

class _DeckHarness extends StatefulWidget {
  const _DeckHarness({required this.onChanged, super.key});

  final ValueChanged<int> onChanged;

  @override
  State<_DeckHarness> createState() => _DeckHarnessState();
}

class _DeckHarnessState extends State<_DeckHarness> {
  List<DemoAsset> images = _images;

  void replace(List<DemoAsset> value) => setState(() => images = value);

  @override
  Widget build(BuildContext context) => DemoImageStack(
    images: images,
    messageId: 'updates',
    initialIndex: 4,
    onChanged: widget.onChanged,
  );
}
