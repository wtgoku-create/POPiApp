import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/session/presentation/widgets/conversation_question_card.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';

const _prompt = '《留个位置》可以进入声音和成片制作了吗？';
const _singleField = ConversationQuestionField(
  id: 'next_step',
  label: _prompt,
  required: true,
  options: ['可以，进入声音和成片', '先再打磨一轮分镜和画面', '之后全程不用停下来问我'],
);

typedef _Response = ({String action, Map<String, Object?> answer});

Future<void> _pumpCard(
  WidgetTester tester, {
  List<ConversationQuestionField> fields = const [_singleField],
  required Future<bool> Function(String, Map<String, Object?>) onRespond,
  String title = _prompt,
  String status = 'pending',
  Map<String, Object?> answer = const {},
  bool instant = false,
  bool busy = false,
  Size size = const Size(760, 700),
  double textScale = 1,
  bool dark = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: ConversationQuestionCard(
            title: title,
            fields: fields,
            status: status,
            answer: answer,
            busy: busy,
            instantSingleChoice: instant,
            onRespond: onRespond,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('single option submits immediately with the selected answer', (
    tester,
  ) async {
    final responses = <_Response>[];
    await _pumpCard(
      tester,
      instant: true,
      onRespond: (action, answer) async {
        responses.add((action: action, answer: answer));
        return true;
      },
    );

    await tester.tap(find.text('可以，进入声音和成片'));
    await tester.pumpAndSettle();

    expect(responses, hasLength(1));
    expect(responses.single.action, 'submit');
    expect(responses.single.answer, {'next_step': '可以，进入声音和成片'});
  });

  testWidgets('pending submission ignores a second option tap', (tester) async {
    final pending = Completer<bool>();
    final responses = <_Response>[];
    await _pumpCard(
      tester,
      instant: true,
      onRespond: (action, answer) {
        responses.add((action: action, answer: answer));
        return pending.future;
      },
    );

    await tester.tap(find.text('可以，进入声音和成片'));
    await tester.pump();
    await tester.tap(find.text('先再打磨一轮分镜和画面'));
    await tester.pump();

    expect(responses, hasLength(1));
    pending.complete(true);
    await tester.pumpAndSettle();
  });

  testWidgets('failed submission keeps the answer and permits retry', (
    tester,
  ) async {
    var attempts = 0;
    final answers = <Map<String, Object?>>[];
    await _pumpCard(
      tester,
      instant: true,
      onRespond: (_, answer) async {
        attempts += 1;
        answers.add(answer);
        return attempts > 1;
      },
    );

    await tester.tap(find.text('先再打磨一轮分镜和画面'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('先再打磨一轮分镜和画面'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(answers, everyElement({'next_step': '先再打磨一轮分镜和画面'}));
  });

  testWidgets('custom single answer replaces a selected option', (
    tester,
  ) async {
    final responses = <_Response>[];
    await _pumpCard(
      tester,
      onRespond: (action, answer) async {
        responses.add((action: action, answer: answer));
        return true;
      },
    );

    await tester.tap(find.text('可以，进入声音和成片'));
    await tester.enterText(find.byType(TextFormField), '只先制作声音');
    await tester.tap(find.widgetWithText(FilledButton, '确认'));
    await tester.pumpAndSettle();

    expect(responses.single.action, 'submit');
    expect(responses.single.answer, {'next_step': '只先制作声音'});
  });

  testWidgets('multi-field form submits all single and multiple selections', (
    tester,
  ) async {
    final responses = <_Response>[];
    const fields = [
      ConversationQuestionField(
        id: 'direction',
        label: '选择方向',
        required: true,
        options: ['声音', '成片'],
      ),
      ConversationQuestionField(
        id: 'checks',
        label: '选择复核项',
        multiple: true,
        required: true,
        options: ['节奏', '画面', '字幕'],
      ),
    ];
    await _pumpCard(
      tester,
      title: '制作设置',
      fields: fields,
      size: const Size(760, 1000),
      onRespond: (action, answer) async {
        responses.add((action: action, answer: answer));
        return true;
      },
    );

    await tester.tap(find.text('成片'));
    await tester.pump();
    await tester.tap(find.text('节奏'));
    await tester.pump();
    await tester.ensureVisible(find.text('字幕'));
    await tester.tap(find.text('字幕'));
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, '确认'));
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '确认'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithText(FilledButton, '确认'));
    await tester.pumpAndSettle();

    expect(responses, hasLength(1));
    expect(responses.single.action, 'submit');
    expect(responses.single.answer, {
      'direction': '成片',
      'checks': ['节奏', '字幕'],
    });
  });

  testWidgets('cancel responds without requiring an answer', (tester) async {
    final responses = <_Response>[];
    await _pumpCard(
      tester,
      onRespond: (action, answer) async {
        responses.add((action: action, answer: answer));
        return true;
      },
    );

    await tester.tap(find.widgetWithText(OutlinedButton, '取消'));
    await tester.pumpAndSettle();

    expect(responses.single.action, 'cancel');
    expect(responses.single.answer, isEmpty);
  });

  for (final status in ['answered', 'expired']) {
    testWidgets('$status card displays its answer and disables interaction', (
      tester,
    ) async {
      var calls = 0;
      await _pumpCard(
        tester,
        status: status,
        answer: const {'next_step': '可以，进入声音和成片'},
        onRespond: (_, _) async {
          calls += 1;
          return true;
        },
      );

      await tester.tap(find.text('先再打磨一轮分镜和画面'));
      await tester.pump();

      expect(calls, 0);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('card remains usable at 320px with large text', (tester) async {
    await _pumpCard(
      tester,
      size: const Size(320, 844),
      textScale: 1.5,
      onRespond: (_, _) async => true,
    );

    expect(find.text(_prompt), findsOneWidget);
    expect(find.text('之后全程不用停下来问我'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('focused option submits from the keyboard', (tester) async {
    final responses = <_Response>[];
    await _pumpCard(
      tester,
      instant: true,
      onRespond: (action, answer) async {
        responses.add((action: action, answer: answer));
        return true;
      },
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(responses, hasLength(1));
    expect(responses.single.answer['next_step'], '可以，进入声音和成片');
  });
}
