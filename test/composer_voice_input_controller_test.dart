import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/speech/speech_input.dart';
import 'package:popi_ai_app/features/session/presentation/composer_voice_input_controller.dart';

class _SpeechSession {
  _SpeechSession(this.result, this.error, this.done);
  final void Function(String) result;
  final void Function(String) error;
  final void Function() done;
}

class _Speech implements SpeechInput {
  final sessions = <_SpeechSession>[];
  Completer<void>? starting;
  String? locale;
  String? startError;
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
    this.locale = locale;
    sessions.add(_SpeechSession(onResult, onError, onDone));
    if (startError case final code?) throw SpeechInputException(code);
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
  late _Speech speech;
  late TextEditingController text;
  late ComposerVoiceInputController voice;
  late List<String> errors;
  setUp(() {
    speech = _Speech();
    text = TextEditingController(text: '开始[popi-image:0]结束');
    text.selection = const TextSelection.collapsed(offset: 2);
    errors = [];
    voice = ComposerVoiceInputController(
      speechInput: speech,
      textController: text,
      onError: errors.add,
    );
  });
  tearDown(() {
    voice.dispose();
    text.dispose();
  });

  test(
    'interim corrections insert at the caret without losing inline images',
    () async {
      await voice.start('zh-CN');
      expect(speech.locale, 'zh-CN');
      expect(voice.state, ComposerVoiceInputState.listening);
      speech.sessions.single.result('你好');
      speech.sessions.single.result('你好世界');
      expect(text.text, '开始你好世界[popi-image:0]结束');
      expect(text.selection.baseOffset, 6);
      speech.sessions.single.done();
      expect(voice.active, false);
      expect(errors, isEmpty);
    },
  );

  test('a final result replaces the selected text only once', () async {
    text.value = const TextEditingValue(
      text: 'before OLD after',
      selection: TextSelection(baseOffset: 7, extentOffset: 10),
    );
    await voice.start('en-US');
    speech.sessions.single.result('new');
    await voice.stop();
    expect(voice.state, ComposerVoiceInputState.stopping);
    speech.sessions.single.result('new words');
    speech.sessions.single.done();
    expect(text.text, 'before new words after');
    expect(speech.stops, 1);
    expect(voice.active, false);
  });

  test(
    'cancelling discards only this dictation and ignores late callbacks',
    () async {
      final original = text.value;
      await voice.start('zh-CN');
      speech.sessions.single.result('临时文字');
      voice.cancel(discard: true);
      speech.sessions.single.result('迟到结果');
      speech.sessions.single.error('network');
      speech.sessions.single.done();
      expect(text.value, original);
      expect(speech.cancels, 1);
      expect(errors, isEmpty);
    },
  );

  test('manual edits stop recognition without overwriting the edit', () async {
    await voice.start('zh-CN');
    speech.sessions.single.result('临时文字');
    text.text = '用户自己修改的文字';
    speech.sessions.single.result('迟到结果');
    expect(text.text, '用户自己修改的文字');
    expect(voice.active, false);
    expect(speech.cancels, 1);
  });

  test(
    'permission denial preserves the complete draft and reports once',
    () async {
      final original = text.value;
      speech.startError = 'permission_denied';
      await voice.start('zh-CN');
      speech.sessions.single.error('permission_denied');
      speech.sessions.single.done();
      expect(voice.active, false);
      expect(text.value, original);
      expect(errors, ['permission_denied']);
    },
  );

  test('recognition errors keep already dictated text', () async {
    await voice.start('zh-CN');
    speech.sessions.single.result('已经识别');
    speech.sessions.single.error('network');
    speech.sessions.single.done();
    expect(text.text, '开始已经识别[popi-image:0]结束');
    expect(errors, ['network']);
    expect(voice.active, false);
  });

  test(
    'cancellation during permission prompt invalidates the pending start',
    () async {
      speech.starting = Completer<void>();
      final original = text.value;
      final pending = voice.start('zh-CN');
      expect(voice.state, ComposerVoiceInputState.starting);
      await voice.stop();
      speech.starting!.complete();
      await pending;
      speech.sessions.single.result('不得写入');
      expect(voice.active, false);
      expect(text.value, original);
      expect(speech.cancels, 1);
      expect(errors, isEmpty);
    },
  );

  test('older sessions cannot mutate a new recording', () async {
    await voice.start('zh-CN');
    final old = speech.sessions.single;
    voice.cancel();
    await voice.start('en-US');
    old.result('old');
    old.done();
    expect(voice.active, true);
    speech.sessions.last.result('new');
    speech.sessions.last.done();
    expect(text.text, '开始new[popi-image:0]结束');
  });

  test(
    'no speech keeps selected content and permits another attempt',
    () async {
      text.selection = const TextSelection(baseOffset: 0, extentOffset: 2);
      final original = text.value;
      await voice.start('zh-CN');
      speech.sessions.single.done();
      expect(text.value, original);
      expect(errors, ['no_speech']);
      await voice.start('zh-CN');
      speech.sessions.last.result('重新录入');
      speech.sessions.last.done();
      expect(text.text, '重新录入[popi-image:0]结束');
    },
  );

  testWidgets('capture and finalization have bounded lifetimes', (
    tester,
  ) async {
    await voice.start('zh-CN');
    speech.sessions.single.result('保留的文字');
    await tester.pump(const Duration(seconds: 60));
    expect(speech.stops, 1);
    expect(voice.state, ComposerVoiceInputState.stopping);
    await tester.pump(const Duration(seconds: 5));
    speech.sessions.single.result('过期的文字');
    expect(text.text, '开始保留的文字[popi-image:0]结束');
    expect(voice.active, false);
    expect(speech.cancels, 1);
    expect(errors, isEmpty);
  });

  test('disposing suppresses callbacks and releases the recognizer', () async {
    await voice.start('zh-CN');
    voice.dispose();
    speech.sessions.single.result('过期');
    speech.sessions.single.error('network');
    expect(speech.disposed, true);
    expect(errors, isEmpty);
    // Replace the disposed fixture so the shared tearDown stays meaningful.
    voice = ComposerVoiceInputController(
      speechInput: _Speech(),
      textController: text,
      onError: errors.add,
    );
  });
}
