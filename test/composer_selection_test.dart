import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';

void main() {
  testWidgets(
    'selection toolbar keeps focus through select all, copy, cut and paste',
    (tester) async {
      String clipboard = '';
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            clipboard = (call.arguments as Map)['text'] as String;
            return null;
          case 'Clipboard.getData':
            return {'text': clipboard};
          case 'Clipboard.hasStrings':
            return {'value': clipboard.isNotEmpty};
          default:
            return null;
        }
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final controller = PopiMessageComposerController(
        initialText: 'hello world',
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: PopiMessageComposer(
                  controller: controller,
                  selectedImages: const [],
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
      await tester.tap(find.byKey(const Key('popi-message-input')));
      await tester.pumpAndSettle();
      final field = tester.widget<ExtendedTextField>(
        find.byType(ExtendedTextField),
      );
      final editable = tester.state<ExtendedEditableTextState>(
        find.byType(ExtendedEditableText),
      );

      await tester.longPressAt(
        editable.renderEditable.localToGlobal(
          editable.renderEditable
              .getLocalRectForCaret(const TextPosition(offset: 2))
              .center,
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.textController.selection.isCollapsed, isFalse);
      expect(find.text('Copy'), findsOneWidget);
      final selectionEnd = editable.renderEditable.localToGlobal(
        editable.renderEditable
            .getLocalRectForCaret(
              TextPosition(offset: controller.textController.selection.end),
            )
            .bottomCenter,
      );
      final handleGesture = await tester.startGesture(
        selectionEnd + const Offset(6, 10),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(field.focusNode!.hasFocus, isTrue);
      await handleGesture.moveBy(const Offset(35, 0));
      await handleGesture.up();
      await tester.pumpAndSettle();
      expect(field.focusNode!.hasFocus, isTrue);

      Future<void> showToolbar() async {
        editable.showToolbar();
        await tester.pumpAndSettle();
      }

      controller.textController.selection = const TextSelection.collapsed(
        offset: 2,
      );
      await tester.pump();
      await showToolbar();
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      expect(field.focusNode!.hasFocus, isTrue);
      expect(
        controller.textController.selection,
        const TextSelection(baseOffset: 0, extentOffset: 11),
      );
      await showToolbar();
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();
      expect(field.focusNode!.hasFocus, isTrue);
      expect(clipboard, 'hello world');
      controller.textController.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );
      await tester.pump();
      await showToolbar();
      await tester.tap(find.text('Cut'));
      await tester.pumpAndSettle();
      expect(controller.textController.text, ' world');
      expect(field.focusNode!.hasFocus, isTrue);
      await showToolbar();
      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();
      expect(controller.textController.text, 'hello world');
      expect(field.focusNode!.hasFocus, isTrue);
      await tester.tapAt(const Offset(10, 20));
      await tester.pumpAndSettle();
      expect(field.focusNode!.hasFocus, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
