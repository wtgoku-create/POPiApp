import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/shared/widgets/app_modal_backdrop.dart';
import 'package:popi_ai_app/shared/widgets/app_sheet.dart';

void main() {
  for (final isScrollControlled in [false, true]) {
    testWidgets('sheet height stays capped after rotation with scroll control: '
        '$isScrollControlled', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      var contentHeight = 2000.0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => AppSheet.show<void>(
                  context: context,
                  isScrollControlled: isScrollControlled,
                  builder: (_) => SizedBox(height: contentHeight),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(tester.getSize(sheet).height, closeTo(844 * .8, .01));
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(tester.getSize(sheet).height, closeTo(390 * .8, .01));
      final surface = find.descendant(
        of: sheet,
        matching: find.byType(Material),
      );
      expect(tester.getSize(surface).width, lessThanOrEqualTo(640));
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      contentHeight = 120;
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.getSize(sheet).height, lessThan(390 * .8));
      expect(tester.takeException(), isNull);
    });
  }

  for (final reduceMotion in [false, true]) {
    testWidgets(
      'sheet backdrop and dismissal with reduced motion: $reduceMotion',
      (tester) async {
        var backgroundTaps = 0;
        String? result;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => backgroundTaps++,
                  child: Center(
                    child: TextButton(
                      onPressed: () async {
                        result = await AppSheet.show<String>(
                          context: context,
                          builder: (context) => SizedBox(
                            height: 200,
                            child: Center(
                              child: TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop('done'),
                                child: const Text('Confirm'),
                              ),
                            ),
                          ),
                        );
                      },
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pump();
        double progress() => tester
            .widget<AppModalBackdrop>(find.byType(AppModalBackdrop))
            .progress;
        if (reduceMotion) {
          expect(progress(), 1);
        } else {
          await tester.pump(const Duration(milliseconds: 80));
          expect(progress(), inExclusiveRange(0, 1));
        }
        await tester.pumpAndSettle();
        final blur = find.byType(BackdropFilter);
        expect(blur, findsOneWidget);
        expect(
          tester.getSize(blur),
          tester.view.physicalSize / tester.view.devicePixelRatio,
        );
        expect(
          tester.widget<BackdropFilter>(blur).filter,
          ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        );
        final overlay = tester.widget<ColoredBox>(
          find.descendant(of: blur, matching: find.byType(ColoredBox)),
        );
        expect(overlay.color, const Color(0x33AFAFAF));
        expect(
          find.descendant(of: blur, matching: find.text('Confirm')),
          findsNothing,
        );
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(find.byType(AppModalBackdrop), findsNothing);
        expect(backgroundTaps, 0);
        expect(result, isNull);

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
        expect(result, 'done');
        expect(find.byType(AppModalBackdrop), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('non-dismissible sheet blocks backdrop taps and supports back', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AppSheet.show<void>(
                context: context,
                isDismissible: false,
                enableDrag: false,
                builder: (_) =>
                    const SizedBox(height: 200, child: Text('Sheet')),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Sheet'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AppModalBackdrop), findsNothing);
    expect(find.text('Sheet'), findsNothing);
  });

  testWidgets(
    'draggable sheet expands, scrolls and dismisses with its backdrop',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => AppSheet.showDraggable<void>(
                  context: context,
                  builder: (_, controller) => ListView.builder(
                    controller: controller,
                    itemCount: 40,
                    itemBuilder: (_, index) =>
                        ListTile(title: Text('Item $index')),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      final height = tester.getSize(sheet).height;
      await tester.drag(find.byType(ListView), const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(tester.getSize(sheet).height, greaterThan(height));
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -180));
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        tester.getSize(sheet).height,
        closeTo(
          tester.view.physicalSize.height / tester.view.devicePixelRatio * .8,
          .01,
        ),
      );
      expect(scrollable.position.pixels, greaterThan(0));
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(AppModalBackdrop), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
