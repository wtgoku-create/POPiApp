import 'dart:async';

import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/speech/speech_input.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/popi_message_composer.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/speech_input_provider.dart';
import 'package:toastification/toastification.dart';

class _Speech implements SpeechInput {
  late void Function(String) result;
  late void Function(String) error;
  late void Function() done;
  Completer<void>? starting;
  String? failure;
  int stops = 0;
  int cancels = 0;
  bool disposed = false;

  @override
  Future<void> start({
    required String locale,
    required void Function(String) onResult,
    required void Function(String) onError,
    required void Function() onDone,
  }) async {
    expect(locale, 'en-US');
    result = onResult;
    error = onError;
    done = onDone;
    if (failure case final code?) throw SpeechInputException(code);
    await starting?.future;
  }

  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> cancel() async => cancels++;
  @override
  void dispose() => disposed = true;
}

void main() {
  final mic = find.byKey(const Key('popi-voice-input'));
  final send = find.byKey(const Key('popi-send-button'));
  late _Speech speech;
  late PopiMessageComposerController composer;
  late List<String> submissions;

  setUp(() {
    speech = _Speech();
    composer = PopiMessageComposerController(initialText: 'before OLD after');
    composer.textController.selection = const TextSelection(
      baseOffset: 7,
      extentOffset: 10,
    );
    submissions = [];
  });
  tearDown(() {
    composer.dispose();
    toastification.dismissAll(delayForAnimation: false);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [speechInputFactoryProvider.overrideWithValue(() => speech)],
        child: ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: PopiMessageComposer(
                  controller: composer,
                  conversationMode: true,
                  sessionLayout: true,
                  selectedImages: const [],
                  onAttachment: () {},
                  onRemoveImage: (_) {},
                  onHeightChanged: (_) {},
                  onSubmitted: submissions.add,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'dictation remains editable after finish and requires explicit send',
    (tester) async {
      await pump(tester);
      expect(tester.getRect(mic).right, lessThan(tester.getRect(send).left));
      await tester.tap(mic);
      await tester.pumpAndSettle();
      expect(
        find.text('Listening. Tap the microphone to finish'),
        findsOneWidget,
      );
      speech.result('new');
      await tester.pumpAndSettle();
      expect(composer.textController.text, 'before new after');
      expect(tester.widget<IconButton>(send).onPressed, isNull);
      expect(
        tester
            .widget<ExtendedTextField>(find.byType(ExtendedTextField))
            .readOnly,
        true,
      );

      await tester.tap(mic);
      await tester.pump();
      expect(speech.stops, 1);
      expect(find.text('Transcribing…'), findsOneWidget);
      speech.result('new words');
      speech.done();
      await tester.pumpAndSettle();
      expect(composer.textController.text, 'before new words after');
      expect(submissions, isEmpty);
      expect(
        tester
            .widget<ExtendedTextField>(find.byType(ExtendedTextField))
            .readOnly,
        false,
      );
      await tester.tap(send);
      expect(submissions, ['before new words after']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancel restores draft and rejects delayed results', (
    tester,
  ) async {
    await pump(tester);
    final original = composer.textController.value;
    await tester.tap(mic);
    await tester.pumpAndSettle();
    speech.result('temporary words');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('popi-voice-cancel')));
    speech.result('late words');
    speech.error('network');
    await tester.pumpAndSettle();
    expect(composer.textController.value, original);
    expect(speech.cancels, 1);
    expect(find.text('Listening. Tap the microphone to finish'), findsNothing);
    expect(submissions, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permission failure preserves draft and shows one toast', (
    tester,
  ) async {
    speech.failure = 'permission_denied';
    await pump(tester);
    final original = composer.textController.value;
    await tester.tap(mic);
    await tester.pumpAndSettle();
    expect(composer.textController.value, original);
    expect(
      find.text(
        'Allow microphone and speech recognition access in system or browser settings',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('popi-voice-cancel')), findsNothing);
    expect(submissions, isEmpty);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending permission can be cancelled without losing the draft', (
    tester,
  ) async {
    speech.starting = Completer<void>();
    await pump(tester);
    await tester.tap(mic);
    await tester.pump();
    expect(find.text('Preparing voice input…'), findsOneWidget);
    await tester.tap(find.byKey(const Key('popi-voice-cancel')));
    speech.starting!.complete();
    await tester.pumpAndSettle();
    speech.result('late words');
    expect(composer.textController.text, 'before OLD after');
    expect(speech.cancels, 1);
    expect(tester.widget<IconButton>(mic).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('covering the route cancels capture and ignores late callbacks', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(mic);
    await tester.pumpAndSettle();
    final navigator = Navigator.of(tester.element(mic));
    unawaited(
      navigator.push<void>(
        MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('Other page')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(speech.cancels, 1);
    speech.result('late words');
    navigator.pop();
    await tester.pumpAndSettle();
    expect(composer.textController.text, 'before OLD after');
    expect(find.text('Listening. Tap the microphone to finish'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
