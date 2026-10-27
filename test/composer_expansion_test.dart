import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/widgets/app_keyboard_dismiss.dart';
import 'package:toastification/toastification.dart';

void main() {
  tearDown(() => toastification.dismissAll(delayForAnimation: false));
  final input = find.byKey(const Key('popi-message-input'));
  final frame = find.byKey(const Key('popi-message-composer'));

  Future<void> pumpComposer(
    WidgetTester tester,
    PopiMessageComposerController controller, {
    bool conversationMode = false,
    bool sessionLayout = false,
    double textScale = 1,
    bool running = false,
    bool keyboardDismissWrapper = false,
    VoidCallback? onStop,
    VoidCallback? onVoiceInput,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            final content = MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            );
            return keyboardDismissWrapper
                ? AppKeyboardDismiss(child: content)
                : content;
          },
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: PopiMessageComposer(
                controller: controller,
                conversationMode: conversationMode,
                sessionLayout: sessionLayout,
                running: running,
                onStop: onStop,
                onVoiceInput: onVoiceInput,
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

  testWidgets('voice entry stays beside send and yields to running stop', (
    tester,
  ) async {
    final controller = PopiMessageComposerController();
    addTearDown(controller.dispose);
    var voiceRequests = 0;
    var stopRequests = 0;
    await pumpComposer(tester, controller, onVoiceInput: () => voiceRequests++);
    final voice = find.byKey(const Key('popi-voice-input'));
    expect(voice.hitTestable(), findsOneWidget);
    await tester.tap(voice);
    expect(voiceRequests, 1);
    await controller.setText('Keep the draft');
    await tester.pumpAndSettle();
    expect(voice.hitTestable(), findsOneWidget);
    expect(find.byTooltip('Send message').hitTestable(), findsOneWidget);
    await controller.setText('');
    await pumpComposer(
      tester,
      controller,
      running: true,
      onVoiceInput: () => voiceRequests++,
      onStop: () => stopRequests++,
    );
    expect(voice, findsNothing);
    await tester.tap(find.byTooltip('Stop reply'));
    expect(stopRequests, 1);
    expect(voiceRequests, 1);
  });

  testWidgets('voice entry is available to existing hosts', (tester) async {
    final controller = PopiMessageComposerController();
    addTearDown(controller.dispose);
    await pumpComposer(tester, controller);
    expect(
      find.byKey(const Key('popi-voice-input')).hitTestable(),
      findsOneWidget,
    );
  });

  for (final blankArea in ['top', 'bottom']) {
    testWidgets(
      'one tap on collapsed $blankArea padding accepts the first character',
      (tester) async {
        final controller = PopiMessageComposerController();
        addTearDown(controller.dispose);
        await pumpComposer(
          tester,
          controller,
          conversationMode: true,
          sessionLayout: true,
          keyboardDismissWrapper: true,
        );

        expect(tester.getSize(frame).height, 60);
        expect(
          tester.widget<ExtendedTextField>(input).focusNode!.hasFocus,
          isFalse,
        );
        expect(tester.testTextInput.isVisible, isFalse);

        final composerRect = tester.getRect(frame);
        final target = Offset(
          composerRect.center.dx,
          blankArea == 'top' ? composerRect.top + 4 : composerRect.bottom - 4,
        );
        expect(tester.getRect(input).contains(target), isFalse);
        expect(
          tester.getRect(find.byTooltip('Add attachment')).contains(target),
          isFalse,
        );
        expect(
          tester.getRect(find.byTooltip('Voice input')).contains(target),
          isFalse,
        );

        await tester.tapAt(target);
        await tester.pump();

        expect(tester.testTextInput.hasAnyClients, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        expect(
          tester.widget<ExtendedTextField>(input).focusNode!.hasFocus,
          isTrue,
        );
        tester.testTextInput.enterText('A');
        await tester.pump();
        expect(controller.textController.text, 'A');
        expect(controller.textController.selection.extentOffset, 1);
        await tester.pumpAndSettle();
        expect(tester.getSize(frame).height, 105);
      },
    );

    testWidgets(
      'one tap on $blankArea composer padding restores the hidden keyboard',
      (tester) async {
        final controller = PopiMessageComposerController(
          initialText: 'Saved draft',
        );
        addTearDown(controller.dispose);
        await pumpComposer(tester, controller, conversationMode: true);

        await tester.tap(input);
        await tester.pumpAndSettle();
        controller.textController.selection = const TextSelection.collapsed(
          offset: 5,
        );
        expect(tester.testTextInput.hasAnyClients, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);

        tester.testTextInput.hide();
        await tester.pump();
        expect(tester.testTextInput.isVisible, isFalse);
        expect(
          tester.widget<ExtendedTextField>(input).focusNode!.hasFocus,
          isTrue,
        );

        final composerRect = tester.getRect(frame);
        final target = Offset(
          composerRect.center.dx,
          blankArea == 'top' ? composerRect.top + 4 : composerRect.bottom - 4,
        );
        expect(tester.getRect(input).contains(target), isFalse);
        expect(
          tester.getRect(find.byTooltip('Add attachment')).contains(target),
          isFalse,
        );
        expect(
          tester.getRect(find.byTooltip('Voice input')).contains(target),
          isFalse,
        );

        await tester.tapAt(target);
        await tester.pump();

        expect(tester.testTextInput.hasAnyClients, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
        expect(
          tester.widget<ExtendedTextField>(input).focusNode!.hasFocus,
          isTrue,
        );
        expect(controller.textController.text, 'Saved draft');
        expect(controller.textController.selection.extentOffset, 5);

        tester.testTextInput.enterText('Saved! draft');
        await tester.pump();
        expect(controller.textController.text, 'Saved! draft');
      },
    );
  }

  testWidgets(
    'long inserted text reveals its end without locking manual scrolling',
    (tester) async {
      final controller = PopiMessageComposerController();
      addTearDown(controller.dispose);
      await pumpComposer(tester, controller);
      final text = List.generate(40, (i) => 'Pasted paragraph $i').join('\n');
      await controller.setText(text);
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: input, matching: find.byType(Scrollable)).first,
          )
          .position;
      expect(position.maxScrollExtent, greaterThan(0));
      expect(position.extentAfter, lessThanOrEqualTo(1));
      position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(position.pixels, 0);
      await controller.setText('$text\nNew final line');
      await tester.pumpAndSettle();
      expect(position.extentAfter, lessThanOrEqualTo(1));
    },
  );

  testWidgets(
    'pasting long clipboard content shows the final lines',
    (tester) async {
      final controller = PopiMessageComposerController();
      addTearDown(controller.dispose);
      final text = List.generate(50, (i) => 'Clipboard line $i').join('\n');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') return {'text': text};
          if (call.method == 'Clipboard.hasStrings') return {'value': true};
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpComposer(tester, controller, conversationMode: true);
      await tester.tap(input);
      await tester.pumpAndSettle();
      await tester
          .state<ExtendedTextFieldState>(input)
          .editableTextKey
          .currentState!
          .pasteText(SelectionChangedCause.toolbar);
      await tester.pumpAndSettle();
      expect(controller.textController.text, text);
      expect(controller.textController.selection.extentOffset, text.length);
      final position = tester
          .state<ScrollableState>(
            find.descendant(of: input, matching: find.byType(Scrollable)).first,
          )
          .position;
      expect(position.extentAfter, lessThanOrEqualTo(1));
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets('collapses only when empty and unfocused', (tester) async {
    final controller = PopiMessageComposerController();
    addTearDown(controller.dispose);
    await pumpComposer(tester, controller);
    expect(tester.getSize(frame).height, 60);
    await tester.tap(input);
    await tester.pumpAndSettle();
    expect(tester.getSize(frame).height, 112);
    expect(find.byTooltip('Voice input').hitTestable(), findsOneWidget);
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

  for (final textScale in [1.0, 1.5]) {
    testWidgets('collapsed session hint is centered at text scale $textScale', (
      tester,
    ) async {
      final controller = PopiMessageComposerController();
      addTearDown(controller.dispose);
      await pumpComposer(
        tester,
        controller,
        conversationMode: true,
        sessionLayout: true,
        textScale: textScale,
      );
      final hint = find.text('Say something to POPi...');
      final attachment = find.byTooltip('Add attachment');
      expect(
        tester.getCenter(hint).dy,
        closeTo(tester.getCenter(attachment).dy, .5),
      );
      await tester.tap(input);
      await tester.pumpAndSettle();
      expect(tester.widget<ExtendedTextField>(input).style!.fontSize, 18);
      tester.testTextInput.enterText('First\nSecond\nThird');
      await tester.pumpAndSettle();
      expect(tester.getSize(frame).height, 78 + 81 * textScale);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

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
    expect(tester.widget<ExtendedTextField>(input).enabled, isFalse);
    await tester.tapAt(tester.getCenter(input));
    await tester.pumpAndSettle();
    expect(find.text('Session is running'), findsOneWidget);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pumpAndSettle();
    expect(tester.getSize(frame).height, 60);
    expect(
      tester.widget<ExtendedTextField>(input).focusNode!.hasFocus,
      isFalse,
    );
    await tester.tap(stop);
    await tester.pumpAndSettle();
    expect(stopped, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('running locks an active draft and completion restores editing', (
    tester,
  ) async {
    final controller = PopiMessageComposerController(initialText: 'Draft');
    addTearDown(controller.dispose);
    await pumpComposer(tester, controller);
    await tester.tap(input);
    await tester.pumpAndSettle();
    expect(tester.widget<ExtendedTextField>(input).focusNode!.hasFocus, isTrue);

    await pumpComposer(tester, controller, running: true);
    expect(tester.widget<ExtendedTextField>(input).readOnly, isTrue);
    expect(
      tester.widget<ExtendedTextField>(input).focusNode!.hasFocus,
      isFalse,
    );
    expect(controller.markdown, 'Draft');

    await pumpComposer(tester, controller);
    expect(tester.widget<ExtendedTextField>(input).enabled, isTrue);
    expect(tester.widget<ExtendedTextField>(input).readOnly, isFalse);
    await tester.tap(input);
    await tester.pumpAndSettle();
    tester.testTextInput.enterText('Updated draft');
    expect(controller.markdown, 'Updated draft');
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
