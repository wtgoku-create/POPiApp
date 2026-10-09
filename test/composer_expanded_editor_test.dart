import 'dart:io';
import 'dart:ui' as ui;

import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';

void main() {
  final frame = find.byKey(const Key('popi-message-composer'));
  final input = find.byKey(const Key('popi-message-input'));
  final expand = find.byKey(const Key('popi-expand-input'));
  final editor = find.byKey(const Key('popi-expanded-editor'));
  final expandedInput = find.byKey(const Key('popi-expanded-message-input'));
  final close = find.byKey(const Key('popi-expanded-editor-close'));
  const longText = 'First\nSecond\nThird\nFourth';
  final boundaryKey = GlobalKey();

  Future<PopiMessageComposerController> openComposer(
    WidgetTester tester, {
    String text = longText,
    bool conversationMode = true,
    bool dark = false,
    ValueChanged<String>? onSubmitted,
    ValueNotifier<bool>? running,
    VoidCallback? onStop,
  }) async {
    final controller = PopiMessageComposerController(initialText: text);
    addTearDown(controller.dispose);
    final runState = running ?? ValueNotifier(false);
    if (running == null) addTearDown(runState.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: dark ? AppTheme.dark : AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (_, child) =>
              RepaintBoundary(key: boundaryKey, child: child!),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ValueListenableBuilder<bool>(
                valueListenable: runState,
                builder: (_, value, __) => PopiMessageComposer(
                  controller: controller,
                  conversationMode: conversationMode,
                  running: value,
                  onStop: onStop,
                  selectedImages: const [],
                  onAttachment: () {},
                  onRemoveImage: (_) {},
                  onHeightChanged: (_) {},
                  onSubmitted: onSubmitted ?? (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('only shows the top-right icon above three rendered lines', (
    tester,
  ) async {
    final controller = await openComposer(tester, text: 'First\nSecond\nThird');
    expect(expand, findsNothing);
    await controller.setText(longText);
    await tester.pumpAndSettle();
    expect(expand, findsOneWidget);
    final iconRect = tester.getRect(expand);
    final inputRect = tester.getRect(input);
    expect(tester.getRect(frame).contains(iconRect.center), isTrue);
    expect(iconRect.top, closeTo(inputRect.top, .01));
    expect(iconRect.left, greaterThanOrEqualTo(inputRect.right));
    await controller.setText(List.filled(100, 'Wrapped text').join(' '));
    await tester.pumpAndSettle();
    expect(expand, findsOneWidget);
    await controller.setText('Short');
    await tester.pumpAndSettle();
    expect(expand, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'expanding preserves selection and edits survive closing and back',
    (tester) async {
      final controller = await openComposer(tester);
      controller.textController.selection = const TextSelection.collapsed(
        offset: 6,
      );
      await tester.pumpAndSettle();
      await tester.tap(expand);
      await tester.pumpAndSettle();
      final field = tester.widget<ExtendedTextField>(expandedInput);
      expect(field.controller, same(controller.textController));
      expect(field.maxLines, isNull);
      expect(field.expands, isTrue);
      expect(controller.textController.selection.baseOffset, 6);
      await tester.tap(expandedInput);
      tester.testTextInput.enterText('$longText\nFifth');
      await tester.pumpAndSettle();
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(editor, findsNothing);
      expect(controller.markdown, '$longText\nFifth');
      expect(
        controller.textController.selection.baseOffset,
        controller.textController.text.length,
      );
      expect(
        tester.widget<ExtendedTextField>(input).focusNode!.hasFocus,
        isTrue,
      );
      expect(tester.widget<ExtendedTextField>(input).maxLines, 3);
      await tester.tap(expand);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(editor, findsNothing);
      expect(controller.markdown, '$longText\nFifth');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('expanded editor sends through the existing submit callback', (
    tester,
  ) async {
    final submitted = <String>[];
    final controller = await openComposer(tester, onSubmitted: submitted.add);
    await tester.tap(expand);
    await tester.pumpAndSettle();
    await tester.tap(expandedInput);
    tester.testTextInput.enterText('$longText\nContinue typing');
    await tester.pumpAndSettle();
    final send = find.descendant(
      of: editor,
      matching: find.byKey(const Key('popi-send-button')),
    );
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(editor, findsNothing);
    expect(submitted, ['$longText\nContinue typing']);
    expect(controller.markdown, submitted.single);
    expect(
      tester.widget<ExtendedTextField>(input).focusNode!.hasFocus,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('open editor follows generation state and disables empty sends', (
    tester,
  ) async {
    final running = ValueNotifier(false);
    addTearDown(running.dispose);
    var stops = 0;
    await openComposer(tester, running: running, onStop: () => stops++);
    await tester.tap(expand);
    await tester.pumpAndSettle();
    final action = find.descendant(
      of: editor,
      matching: find.byKey(const Key('popi-send-button')),
    );
    running.value = true;
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: editor, matching: find.byTooltip('Stop reply')),
      findsOneWidget,
    );
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(stops, 1);
    expect(editor, findsOneWidget);
    running.value = false;
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: editor, matching: find.byTooltip('Send message')),
      findsOneWidget,
    );
    await tester.tap(expandedInput);
    tester.testTextInput.enterText('');
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(action).onPressed, isNull);
    await tester.tap(close);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  for (final (size, keyboard, dark) in [
    (const Size(320, 568), 250.0, false),
    (const Size(390, 844), 300.0, false),
    (const Size(1024, 600), 0.0, true),
  ]) {
    testWidgets('editor fits above the keyboard at $size dark=$dark', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await openComposer(tester, conversationMode: false, dark: dark);
      await tester.tap(expand);
      await tester.pumpAndSettle();
      final bounds = tester.getRect(editor);
      final inputBounds = tester.getRect(expandedInput);
      expect(bounds.bottom, closeTo(size.height - keyboard, .01));
      expect(bounds.contains(inputBounds.topLeft), isTrue);
      expect(bounds.contains(inputBounds.bottomRight), isTrue);
      expect(
        inputBounds.top,
        greaterThanOrEqualTo(tester.getRect(close).bottom + 16),
      );
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_EXPANDED_COMPOSER')) {
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/popi-expanded-composer-${size.width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.tap(close);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });
  }
}
