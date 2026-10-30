@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/shared/widgets/app_modal_backdrop.dart';
import 'package:popi_ai_app/shared/widgets/app_sheet.dart';

void main() {
  Future<void> pumpLauncher(
    WidgetTester tester, {
    required void Function(BuildContext) open,
    Size size = const Size(1200, 800),
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
            builder: (context) => TextButton(
              onPressed: () => open(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Web sheets center and stay bounded after resizing', (
    tester,
  ) async {
    const content = Key('content');
    await pumpLauncher(
      tester,
      open: (context) => AppSheet.show<void>(
        context: context,
        maxHeightFraction: 1,
        builder: (_) => const SizedBox(key: content, height: 2000),
      ),
    );
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(Dialog), findsOneWidget);
    expect(
      tester.getRect(find.byKey(content)),
      const Rect.fromLTWH(360, 80, 480, 640),
    );
    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(
      dialog.shape,
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    );
    expect(dialog.backgroundColor, AppTheme.light.colorScheme.surface);
    expect(dialog.clipBehavior, Clip.antiAlias);
    tester.view.physicalSize = const Size(320, 600);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(content)),
      const Rect.fromLTWH(20, 60, 280, 480),
    );
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(content)),
      const Rect.fromLTWH(182, 39, 480, 312),
    );
    expect(tester.takeException(), isNull);
  });

  for (final reduceMotion in [false, true]) {
    testWidgets(
      'Web sheets return results and dismiss with reduced motion: $reduceMotion',
      (tester) async {
        String? result;
        var completed = false;
        await pumpLauncher(
          tester,
          reduceMotion: reduceMotion,
          open: (context) async {
            result = await AppSheet.show<String>(
              context: context,
              builder: (context) => SizedBox(
                height: 120,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop('done'),
                  child: const Text('Confirm'),
                ),
              ),
            );
            completed = true;
          },
        );
        expect(tester.getRect(find.text('Confirm')).center.dy, 400);
        expect(
          tester.getRect(find.byType(AppModalBackdrop)),
          const Rect.fromLTWH(0, 0, 1200, 800),
        );
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
        expect(result, 'done');
        expect(completed, isTrue);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Web non-dismissible sheets retain system back', (tester) async {
    await pumpLauncher(
      tester,
      open: (context) => AppSheet.show<void>(
        context: context,
        isDismissible: false,
        builder: (_) => const SizedBox(height: 120, child: Text('Content')),
      ),
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Content'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('Web keyboard insets constrain contents once', (tester) async {
    const content = Key('content');
    addTearDown(tester.view.resetViewInsets);
    await pumpLauncher(
      tester,
      size: const Size(390, 844),
      open: (context) => AppSheet.show<void>(
        context: context,
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: const SizedBox(key: content, height: 2000),
        ),
      ),
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byKey(content));
    expect(rect.top, 24);
    expect(rect.bottom, 844 - 300 - 24);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Web draggable content scrolls without resizing or closing', (
    tester,
  ) async {
    const list = Key('list');
    await pumpLauncher(
      tester,
      open: (context) => AppSheet.showDraggable<void>(
        context: context,
        builder: (context, controller) => ListView.builder(
          key: list,
          controller: controller,
          itemExtent: 48,
          itemCount: 100,
          itemBuilder: (_, index) => Text('Item $index'),
        ),
      ),
    );
    final rect = tester.getRect(find.byKey(list));
    await tester.drag(find.byKey(list), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Item 0'), findsNothing);
    expect(tester.getRect(find.byKey(list)), rect);
    await tester.drag(find.byKey(list), const Offset(0, 900));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.getRect(find.byKey(list)), rect);
    expect(tester.takeException(), isNull);
  });
}
