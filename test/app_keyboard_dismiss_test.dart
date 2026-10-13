import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/shared/widgets/app_dialog.dart';
import 'package:popi_ai_app/shared/widgets/app_keyboard_dismiss.dart';
import 'package:popi_ai_app/shared/widgets/app_sheet.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'touch outside dismisses keyboard and still activates buttons on $platform',
      (tester) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            builder: (_, child) => AppKeyboardDismiss(child: child!),
            home: Scaffold(
              body: Column(
                children: [
                  TextField(focusNode: focus, maxLines: 3),
                  TextButton(
                    onPressed: () => taps++,
                    child: const Text('Action'),
                  ),
                  const Expanded(child: SizedBox.expand()),
                ],
              ),
            ),
          ),
        );
        await tester.tap(find.byType(TextField));
        await tester.pump();
        expect(focus.hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        await tester.tapAt(const Offset(20, 400));
        await tester.pump();
        expect(focus.hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(find.byType(TextField));
        await tester.pump();
        await tester.tap(find.text('Action'));
        await tester.pump();
        expect(focus.hasFocus, isFalse);
        expect(taps, 1);
      },
      variant: TargetPlatformVariant({platform}),
    );
  }

  testWidgets(
    'field switching and text-field tools preserve input focus on iOS',
    (tester) async {
      final first = FocusNode();
      final second = FocusNode();
      final controller = TextEditingController(text: 'Draft');
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => AppKeyboardDismiss(child: child!),
          home: Scaffold(
            body: Column(
              children: [
                TextField(key: const Key('first'), focusNode: first),
                TextField(
                  key: const Key('second'),
                  focusNode: second,
                  controller: controller,
                ),
                TextFieldTapRegion(
                  child: IconButton(
                    onPressed: () => controller.text += '!',
                    icon: const Icon(Icons.add),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('first')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('second')));
      await tester.pump();
      expect(first.hasFocus, isFalse);
      expect(second.hasFocus, isTrue);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(second.hasFocus, isTrue);
      expect(controller.text, 'Draft!');
      expect(tester.testTextInput.isVisible, isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final dialog in [false, true]) {
    testWidgets(
      'modal dismisses keyboard without restoring parent focus: dialog=$dialog',
      (tester) async {
        final parentFocus = FocusNode();
        final childFocus = FocusNode();
        addTearDown(parentFocus.dispose);
        addTearDown(childFocus.dispose);
        Widget content(BuildContext context) => SizedBox(
          height: 220,
          child: Column(
            children: [
              TextField(
                key: const Key('modal-input'),
                focusNode: childFocus,
                autofocus: true,
              ),
              const SizedBox(height: 30),
              const Text('Modal title'),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    TextField(
                      key: const Key('parent-input'),
                      focusNode: parentFocus,
                    ),
                    TextButton(
                      onPressed: () {
                        if (dialog) {
                          AppDialog.show<void>(
                            context: context,
                            builder: (context) =>
                                AppDialog(child: content(context)),
                          );
                        } else {
                          AppSheet.show<void>(
                            context: context,
                            builder: content,
                          );
                        }
                      },
                      child: const Text('Open'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const Key('parent-input')));
        await tester.pump();
        expect(parentFocus.hasFocus, isTrue);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(childFocus.hasFocus, isTrue);
        await tester.tap(find.text('Modal title'));
        await tester.pump();
        expect(childFocus.hasFocus, isFalse);
        expect(find.text('Modal title'), findsOneWidget);
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(find.byKey(const Key('modal-input')));
        await tester.pump();
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(parentFocus.hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
