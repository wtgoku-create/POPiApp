import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';

void main() {
  final input = find.byKey(const Key('popi-message-input'));
  final frame = find.byKey(const Key('popi-message-composer'));

  Future<void> pumpComposer(
    WidgetTester tester,
    PopiMessageComposerController controller, {
    bool conversationMode = false,
    bool running = false,
    VoidCallback? onStop,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: PopiMessageComposer(
                controller: controller,
                conversationMode: conversationMode,
                running: running,
                onStop: onStop,
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
    await tester.pumpAndSettle();
  }

  testWidgets('collapses only when empty and unfocused', (tester) async {
    final controller = PopiMessageComposerController();
    addTearDown(controller.dispose);
    await pumpComposer(tester, controller);
    expect(tester.getSize(frame).height, 60);
    await tester.tap(input);
    await tester.pumpAndSettle();
    expect(tester.getSize(frame).height, 112);
    expect(find.byTooltip('Voice input'), findsNothing);
    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);

    tester.testTextInput.enterText('Draft message');
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ExtendedTextField>(input).focusNode!.hasFocus,
      isFalse,
    );
    expect(tester.getSize(frame).height, 112);
    expect(find.byKey(const Key('popi-send-button')), findsOneWidget);

    await tester.tap(input);
    await tester.pumpAndSettle();
    tester.testTextInput.enterText('First\nSecond\nThird\nFourth');
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    expect(tester.getSize(frame).height, 133);
    expect(tester.widget<ExtendedTextField>(input).maxLines, 3);

    await tester.tap(input);
    await tester.pumpAndSettle();
    tester.testTextInput.enterText('');
    await tester.pumpAndSettle();
    expect(tester.getSize(frame).height, 112);
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    expect(tester.getSize(frame).height, 60);

    await controller.setText('Programmatic draft');
    await tester.pumpAndSettle();
    expect(
      tester.widget<ExtendedTextField>(input).focusNode!.hasFocus,
      isFalse,
    );
    expect(tester.getSize(frame).height, 112);
    await controller.setText('');
    await tester.pumpAndSettle();
    expect(tester.getSize(frame).height, 60);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('active conversation expands only for focus or draft content', (
    tester,
  ) async {
    final controller = PopiMessageComposerController();
    addTearDown(controller.dispose);
    await pumpComposer(tester, controller, conversationMode: true);
    expect(tester.getSize(frame).height, 60);
    await tester.tap(input);
    await tester.pumpAndSettle();
    expect(tester.getSize(frame).height, 105);
    tester.testTextInput.enterText('First\nSecond\nThird');
    await tester.pumpAndSettle();
    expect(tester.getSize(frame).height, 159);
    tester.testTextInput.enterText('First\nSecond\nThird\nFourth\nFifth');
    await tester.pumpAndSettle();
    expect(tester.getSize(frame).height, 159);
    expect(tester.widget<ExtendedTextField>(input).maxLines, 3);
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    expect(tester.getSize(frame).height, 159);
    await controller.setText('');
    await tester.pumpAndSettle();
    expect(tester.getSize(frame).height, 60);
    await controller.setText('Draft');
    await tester.pumpAndSettle();
    expect(tester.getSize(frame).height, 105);
    await tester.tap(input);
    await tester.pumpAndSettle();
    tester.testTextInput.enterText('');
    await tester.pumpAndSettle();
    expect(tester.getSize(frame).height, 105);
    await tester.tapAt(const Offset(10, 20));
    await tester.pumpAndSettle();
    expect(tester.getSize(frame).height, 60);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('running reply keeps stop accessible in a collapsed composer', (
    tester,
  ) async {
    final controller = PopiMessageComposerController();
    addTearDown(controller.dispose);
    var stopped = false;
    await pumpComposer(tester, controller, conversationMode: true);
    await pumpComposer(
      tester,
      controller,
      conversationMode: true,
      running: true,
      onStop: () => stopped = true,
    );
    expect(tester.getSize(frame).height, 60);
    final stop = find.byKey(const Key('popi-send-button'));
    final stopRect = tester.getRect(stop);
    final inputRect = tester.getRect(input);
    expect(inputRect.overlaps(stopRect), isFalse);
    expect(tester.getRect(frame).contains(stopRect.center), isTrue);
    await tester.tap(stop);
    await tester.pumpAndSettle();
    expect(stopped, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  for (final text in ['Draft', '   ', '\n']) {
    testWidgets(
      'initial value ${text.codeUnits} stays expanded without focus',
      (tester) async {
        final controller = PopiMessageComposerController(initialText: text);
        addTearDown(controller.dispose);
        await pumpComposer(tester, controller);
        expect(
          tester.widget<ExtendedTextField>(input).focusNode!.hasFocus,
          isFalse,
        );
        expect(tester.getSize(frame).height, 112);
        await controller.setText('');
        await tester.pumpAndSettle();
        expect(tester.getSize(frame).height, 60);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
