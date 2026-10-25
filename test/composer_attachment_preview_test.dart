import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/assets/domain/library_work.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';

const _works = [
  LibraryWork(
    id: 'first',
    previewUrl: 'assets/images/demo_role_1.png',
    isVideo: false,
    imageUrls: ['assets/images/demo_role_1.png'],
    createdAt: null,
  ),
  LibraryWork(
    id: 'second',
    previewUrl: 'assets/images/demo_role_2.png',
    isVideo: false,
    imageUrls: ['assets/images/demo_role_2.png'],
    createdAt: null,
  ),
];

Future<void> _pumpComposer(
  WidgetTester tester, {
  ValueChanged<int>? onPreview,
  ValueChanged<int>? onRemove,
  Widget? Function(BuildContext context, int index)? thumbnailBuilder,
  double textScale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = PopiMessageComposerController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: PopiMessageComposer(
              controller: controller,
              selectedImages: const [],
              selectedAssets: _works,
              onPreviewAsset: onPreview,
              onRemoveAsset: onRemove,
              selectedAssetThumbnailBuilder: thumbnailBuilder,
              onAttachment: () {},
              onRemoveImage: (_) {},
              onHeightChanged: (_) {},
              onSubmitted: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Offset _previewPoint(WidgetTester tester, Finder finder) {
  final rect = tester.getRect(finder);
  return Offset(rect.left + 20, rect.bottom - 20);
}

Future<void> _doubleTap(WidgetTester tester, Finder finder) async {
  final point = _previewPoint(tester, finder);
  await tester.tapAt(point);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(point);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('single tap is inert and double tap previews the exact asset', (
    tester,
  ) async {
    final previews = <int>[];
    await _pumpComposer(tester, onPreview: previews.add);
    final second = find.byKey(
      const ValueKey('popi-preview-selected-asset-second'),
    );

    await tester.tapAt(_previewPoint(tester, second));
    await tester.pump(const Duration(milliseconds: 400));
    expect(previews, isEmpty);

    await _doubleTap(tester, second);
    expect(previews, [1]);
  });

  testWidgets('remove control never leaks its taps into preview', (
    tester,
  ) async {
    final previews = <int>[];
    final removals = <int>[];
    await _pumpComposer(
      tester,
      onPreview: previews.add,
      onRemove: removals.add,
    );
    final remove = find.byKey(
      const ValueKey('popi-remove-selected-asset-first'),
    );

    await tester.tap(remove);
    await tester.pump();
    expect(removals, [0]);
    expect(previews, isEmpty);

    removals.clear();
    await _doubleTap(tester, remove);
    expect(removals, [0, 0]);
    expect(previews, isEmpty);
  });

  testWidgets('preview supports keyboard and semantics activation', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final previews = <int>[];
    await _pumpComposer(tester, onPreview: previews.add);
    final first = find.byKey(
      const ValueKey('popi-preview-selected-asset-first'),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(previews, [0, 0]);

    final node = tester.getSemantics(first);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    tester.semantics.performAction(
      find.semantics.byLabel('双击预览附件').first,
      SemanticsAction.tap,
    );
    await tester.pump();
    expect(previews, [0, 0, 0]);
    semantics.dispose();
  });

  testWidgets(
    'preview remains optional and narrow large text does not overflow',
    (tester) async {
      await _pumpComposer(tester, textScale: 1.5, size: const Size(320, 640));

      expect(
        find.byKey(const ValueKey('popi-selected-asset-first')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('popi-preview-selected-asset-first')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('custom thumbnail retains preview and remove interactions', (
    tester,
  ) async {
    final previews = <int>[];
    final removals = <int>[];
    await _pumpComposer(
      tester,
      onPreview: previews.add,
      onRemove: removals.add,
      thumbnailBuilder: (context, index) => ColoredBox(
        key: ValueKey('custom-thumbnail-$index'),
        color: Colors.amber,
        child: Text('file-$index'),
      ),
    );

    expect(find.byKey(const ValueKey('custom-thumbnail-1')), findsOneWidget);
    await _doubleTap(
      tester,
      find.byKey(const ValueKey('popi-preview-selected-asset-second')),
    );
    expect(previews, [1]);
    await tester.tap(
      find.byKey(const ValueKey('popi-remove-selected-asset-second')),
    );
    expect(removals, [1]);
  });
}
