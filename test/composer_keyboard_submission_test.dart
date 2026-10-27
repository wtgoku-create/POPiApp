import 'dart:convert';

import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/speech/speech_input.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/speech_input_provider.dart';
import 'package:toastification/toastification.dart';

void main() {
  tearDown(() => toastification.dismissAll(delayForAnimation: false));

  for (final key in [
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
  ]) {
    testWidgets('desktop ${key.keyLabel} submits the current draft once', (
      tester,
    ) async {
      final submitted = <String>[];
      final controller = await _pumpComposer(
        tester,
        platform: TargetPlatform.macOS,
        text: '发送这一句',
        onSubmitted: submitted.add,
      );

      await _focusInput(tester);
      await tester.sendKeyEvent(key);
      await tester.pump();

      expect(submitted, ['发送这一句']);
      expect(controller.markdown, '发送这一句');
    });
  }

  testWidgets('held Enter cannot submit more than once', (tester) async {
    final submitted = <String>[];
    await _pumpComposer(
      tester,
      platform: TargetPlatform.windows,
      text: '只发送一次',
      onSubmitted: submitted.add,
    );

    await _focusInput(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(submitted, ['只发送一次']);
  });

  testWidgets('Shift Enter inserts a newline without submitting', (
    tester,
  ) async {
    final submitted = <String>[];
    final controller = await _pumpComposer(
      tester,
      platform: TargetPlatform.linux,
      text: '第一行',
      onSubmitted: submitted.add,
    );
    controller.textController.selection = TextSelection.collapsed(
      offset: controller.markdown.length,
    );

    await _focusInput(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '第一行\n',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    await tester.pump();

    expect(submitted, isEmpty);
    expect(controller.textController.text, '第一行\n');
  });

  testWidgets('desktop command modifiers never submit the draft', (
    tester,
  ) async {
    final submitted = <String>[];
    final controller = await _pumpComposer(
      tester,
      platform: TargetPlatform.macOS,
      text: '保留草稿',
      onSubmitted: submitted.add,
    );

    await _focusInput(tester);
    for (final modifier in [
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.altLeft,
    ]) {
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(modifier);
    }
    await tester.pump();

    expect(submitted, isEmpty);
    expect(controller.textController.text, '保留草稿');
  });

  testWidgets('mobile Enter remains a newline action', (tester) async {
    final submitted = <String>[];
    final controller = await _pumpComposer(
      tester,
      platform: TargetPlatform.android,
      text: '第一行',
      onSubmitted: submitted.add,
    );
    controller.textController.selection = TextSelection.collapsed(
      offset: controller.markdown.length,
    );

    await _focusInput(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '第一行\n',
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    await tester.pump();

    expect(submitted, isEmpty);
    expect(controller.textController.text, '第一行\n');
  });

  testWidgets('IME composition confirmation never submits the draft', (
    tester,
  ) async {
    final submitted = <String>[];
    final controller = await _pumpComposer(
      tester,
      platform: TargetPlatform.macOS,
      text: '候选字',
      onSubmitted: submitted.add,
    );
    await _focusInput(tester);
    controller.textController.value = const TextEditingValue(
      text: '候选字',
      selection: TextSelection.collapsed(offset: 3),
      composing: TextRange(start: 0, end: 3),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(submitted, isEmpty);
  });

  for (final state in [
    (
      name: 'empty',
      text: '',
      active: true,
      sending: false,
      running: false,
      ready: true,
    ),
    (
      name: 'inactive',
      text: '草稿',
      active: false,
      sending: false,
      running: false,
      ready: true,
    ),
    (
      name: 'sending',
      text: '草稿',
      active: true,
      sending: true,
      running: false,
      ready: true,
    ),
    (
      name: 'running',
      text: '草稿',
      active: true,
      sending: false,
      running: true,
      ready: true,
    ),
    (
      name: 'unready',
      text: '草稿',
      active: true,
      sending: false,
      running: false,
      ready: false,
    ),
  ]) {
    testWidgets('desktop Enter does not submit a ${state.name} composer', (
      tester,
    ) async {
      final submitted = <String>[];
      await _pumpComposer(
        tester,
        platform: TargetPlatform.macOS,
        text: state.text,
        active: state.active,
        sending: state.sending,
        running: state.running,
        attachmentsReady: state.ready,
        onSubmitted: submitted.add,
      );

      await _focusInput(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(submitted, isEmpty);
    });
  }

  testWidgets('attachment-only desktop draft submits when ready', (
    tester,
  ) async {
    final submitted = <String>[];
    await _pumpComposer(
      tester,
      platform: TargetPlatform.macOS,
      text: '',
      selectedImages: [
        PopiComposerImage(
          name: 'reference.png',
          bytes: Uint8List.fromList(
            base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
              'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
            ),
          ),
        ),
      ],
      onSubmitted: submitted.add,
    );

    await _focusInput(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(submitted, ['']);
  });

  testWidgets('voice capture blocks desktop Enter submission', (tester) async {
    final submitted = <String>[];
    final speech = _Speech();
    await _pumpComposer(
      tester,
      platform: TargetPlatform.macOS,
      text: '语音中的草稿',
      speech: speech,
      onSubmitted: submitted.add,
    );

    await tester.tap(find.byKey(const Key('popi-voice-input')));
    await tester.pumpAndSettle();
    await _focusInput(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(submitted, isEmpty);
    expect(speech.starts, 1);
  });

  testWidgets('expanded desktop editor submits once and closes on Enter', (
    tester,
  ) async {
    final submitted = <String>[];
    const text = '第一行\n第二行\n第三行\n第四行';
    await _pumpComposer(
      tester,
      platform: TargetPlatform.macOS,
      text: text,
      onSubmitted: submitted.add,
    );

    await tester.tap(find.byKey(const Key('popi-expand-input')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('popi-expanded-message-input')));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(submitted, [text]);
    expect(find.byKey(const Key('popi-expanded-editor')), findsNothing);
  });
}

Future<void> _focusInput(WidgetTester tester) async {
  tester
      .widget<ExtendedTextField>(find.byKey(const Key('popi-message-input')))
      .focusNode!
      .requestFocus();
  await tester.pump();
}

final class _Speech implements SpeechInput {
  int starts = 0;

  @override
  Future<void> start({
    required String locale,
    required void Function(String text) onResult,
    required void Function(String code) onError,
    required void Function() onDone,
  }) async {
    starts += 1;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}

  @override
  void dispose() {}
}

Future<PopiMessageComposerController> _pumpComposer(
  WidgetTester tester, {
  required TargetPlatform platform,
  required String text,
  required ValueChanged<String> onSubmitted,
  bool active = true,
  bool sending = false,
  bool running = false,
  bool attachmentsReady = true,
  List<PopiComposerImage> selectedImages = const [],
  SpeechInput? speech,
}) async {
  final controller = PopiMessageComposerController(initialText: text);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (speech != null)
          speechInputFactoryProvider.overrideWithValue(() => speech),
      ],
      child: ToastificationWrapper(
        child: MaterialApp(
          theme: AppTheme.light.copyWith(platform: platform),
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: PopiMessageComposer(
                controller: controller,
                conversationMode: true,
                active: active,
                sending: sending,
                running: running,
                attachmentsReady: attachmentsReady,
                selectedImages: selectedImages,
                onAttachment: () {},
                onRemoveImage: (_) {},
                onHeightChanged: (_) {},
                onSubmitted: onSubmitted,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byType(ExtendedTextField), findsOneWidget);
  return controller;
}
