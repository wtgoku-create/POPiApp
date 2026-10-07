import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/shared/widgets/app_dialog.dart';
import 'package:popi_ai_app/shared/widgets/app_modal_backdrop.dart';

void main() {
  for (final reduceMotion in [false, true]) {
    testWidgets(
      'dialog and backdrop transition with reduced motion: $reduceMotion',
      (tester) async {
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
                  onPressed: () => AppDialog.show<void>(
                    context: context,
                    builder: (_) =>
                        const AppDialog(child: Text('Animated dialog')),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pump();
        final text = find.text('Animated dialog');
        double backdropProgress() => tester
            .widget<AppModalBackdrop>(find.byType(AppModalBackdrop))
            .progress;
        final route = ModalRoute.of(tester.element(text))!;
        if (reduceMotion) {
          expect(route.animation!.status, AnimationStatus.completed);
          expect(backdropProgress(), 1);
        } else {
          expect(route.transitionDuration, const Duration(milliseconds: 260));
          expect(
            route.reverseTransitionDuration,
            const Duration(milliseconds: 180),
          );
          await tester.pump(const Duration(milliseconds: 80));
          final width = tester.getRect(text).width;
          final progress = backdropProgress();
          expect(progress, inExclusiveRange(0, 1));
          await tester.pump(const Duration(milliseconds: 80));
          expect(tester.getRect(text).width, greaterThan(width));
          expect(backdropProgress(), greaterThan(progress));
          await tester.pumpAndSettle();
        }
        await tester.binding.handlePopRoute();
        await tester.pump();
        if (reduceMotion) {
          expect(find.byType(AppDialog), findsNothing);
        } else {
          await tester.pump(const Duration(milliseconds: 90));
          expect(text, findsOneWidget);
          expect(backdropProgress(), inExclusiveRange(0, 1));
          await tester.pump(const Duration(milliseconds: 100));
          expect(find.byType(AppDialog), findsNothing);
        }
        await tester.pumpAndSettle();
        expect(find.byType(AppModalBackdrop), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final dark in [false, true]) {
    testWidgets('blurred dialog preserves barrier and actions in dark: $dark', (
      tester,
    ) async {
      var backgroundTaps = 0;
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  TextButton(
                    onPressed: () async {
                      result = await AppDialog.confirm(
                        context: context,
                        title: 'Delete item?',
                        description: 'This item will be removed.',
                        cancelLabel: 'Cancel',
                        confirmLabel: 'Delete',
                        destructive: true,
                      );
                    },
                    child: const Text('Open dialog'),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => backgroundTaps++,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();
      final blur = find.byType(BackdropFilter);
      expect(blur, findsOneWidget);
      expect(
        tester.getSize(blur),
        tester.view.physicalSize / tester.view.devicePixelRatio,
      );
      expect(
        find.descendant(of: blur, matching: find.text('Delete item?')),
        findsNothing,
      );
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(AppDialog), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(backgroundTaps, 0);
      expect(result, isNull);

      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(find.byType(BackdropFilter), findsNothing);

      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.byType(AppDialog), findsNothing);
    });
  }
}
