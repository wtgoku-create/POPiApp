@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/core/speech/speech_input.dart';

void main() {
  setUp(_installFakeRecognition);
  tearDown(_restoreRecognition);

  test('interim corrections replace the cumulative snapshot', () async {
    final input = createSpeechInput();
    addTearDown(input.dispose);
    final results = <String>[];
    final started = input.start(
      locale: 'en-US',
      onResult: results.add,
      onError: (_) {},
      onDone: () {},
    );
    final recognition = _lastRecognition;
    recognition.emitStart();
    await started;

    recognition.emitResult('hel', false, 0);
    recognition.emitResult('hello', false, 0);

    expect(results, ['hel', 'hello']);
    expect(recognition.lang, 'en-US');
    expect(recognition.interimResults, isTrue);
  });

  test('cumulative segments preserve English and Chinese boundaries', () async {
    final english = createSpeechInput();
    addTearDown(english.dispose);
    final englishResults = <String>[];
    final englishStarted = english.start(
      locale: 'en-US',
      onResult: englishResults.add,
      onError: (_) {},
      onDone: () {},
    );
    var recognition = _lastRecognition;
    recognition.emitStart();
    await englishStarted;
    recognition.emitResult('hello', true, 0);
    recognition.emitResult('world', false, 1);
    expect(englishResults.last, 'hello world');
    await english.cancel();

    final chinese = createSpeechInput();
    addTearDown(chinese.dispose);
    final chineseResults = <String>[];
    final chineseStarted = chinese.start(
      locale: 'zh-CN',
      onResult: chineseResults.add,
      onError: (_) {},
      onDone: () {},
    );
    recognition = _lastRecognition;
    recognition.emitStart();
    await chineseStarted;
    recognition.emitResult('你好', true, 0);
    recognition.emitResult('世界', false, 1);
    expect(chineseResults.last, '你好世界');
  });

  test('setup error rejects start without duplicate callbacks', () async {
    final input = createSpeechInput();
    addTearDown(input.dispose);
    final errors = <String>[];
    var done = 0;
    final started = input.start(
      locale: 'en-US',
      onResult: (_) {},
      onError: errors.add,
      onDone: () => done++,
    );
    final expectation = expectLater(
      started,
      throwsA(
        isA<SpeechInputException>().having(
          (error) => error.code,
          'code',
          'permission_denied',
        ),
      ),
    );
    final recognition = _lastRecognition;
    recognition.emitError('not-allowed');
    recognition.emitEnd();
    await expectation;

    expect(errors, isEmpty);
    expect(done, 0);
    expect(recognition.abortCalls, 1);
  });

  test('runtime error aborts and survives reentrant cancel', () async {
    late final SpeechInput input;
    final events = <String>[];
    input = createSpeechInput();
    addTearDown(input.dispose);
    final started = input.start(
      locale: 'en-US',
      onResult: (_) {},
      onError: (code) {
        events.add('error:$code');
        unawaited(input.cancel());
      },
      onDone: () => events.add('done'),
    );
    final recognition = _lastRecognition;
    recognition.emitStart();
    await started;

    recognition.emitError('network');
    recognition.emitEnd();

    expect(events, ['error:network', 'done']);
    expect(recognition.abortCalls, 1);
  });

  test('stop keeps final results alive until done', () async {
    final input = createSpeechInput();
    addTearDown(input.dispose);
    final results = <String>[];
    var done = 0;
    final started = input.start(
      locale: 'en-US',
      onResult: results.add,
      onError: (_) {},
      onDone: () => done++,
    );
    final recognition = _lastRecognition;
    recognition.emitStart();
    await started;

    await input.stop();
    recognition.emitResult('final words', true, 0);
    recognition.emitEnd();

    expect(recognition.stopCalls, 1);
    expect(results, ['final words']);
    expect(done, 1);
    expect(recognition.abortCalls, 0);
  });

  test('cancel aborts and suppresses stale browser events', () async {
    final input = createSpeechInput();
    addTearDown(input.dispose);
    final results = <String>[];
    final errors = <String>[];
    var done = 0;
    final started = input.start(
      locale: 'en-US',
      onResult: results.add,
      onError: errors.add,
      onDone: () => done++,
    );
    final recognition = _lastRecognition;
    recognition.emitStart();
    await started;

    await input.cancel();
    recognition.emitResult('stale', true, 0);
    recognition.emitError('network');
    recognition.emitEnd();

    expect(recognition.abortCalls, 1);
    expect(results, isEmpty);
    expect(errors, isEmpty);
    expect(done, 0);
  });

  test('new owner cancels and completes the previous active owner', () async {
    final first = createSpeechInput();
    final second = createSpeechInput();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    final firstEvents = <String>[];
    final firstStarted = first.start(
      locale: 'en-US',
      onResult: (text) => firstEvents.add('result:$text'),
      onError: (code) => firstEvents.add('error:$code'),
      onDone: () => firstEvents.add('done'),
    );
    final firstRecognition = _lastRecognition;
    firstRecognition.emitStart();
    await firstStarted;

    final secondStarted = second.start(
      locale: 'en-US',
      onResult: (_) {},
      onError: (_) {},
      onDone: () {},
    );
    await Future<void>.delayed(Duration.zero);
    final secondRecognition = _lastRecognition;
    secondRecognition.emitStart();
    await secondStarted;
    firstRecognition.emitResult('stale', true, 0);

    expect(firstRecognition.abortCalls, 1);
    expect(firstEvents, ['error:cancelled', 'done']);
    expect(secondRecognition, isNot(same(firstRecognition)));
  });
}

_FakeSpeechRecognition get _lastRecognition {
  expect(_speechInstances.length, greaterThan(0));
  return _speechInstances[_speechInstances.length - 1];
}

void _installFakeRecognition() {
  _evaluate(r'''
    globalThis.__speechHadRecognition = Object.prototype.hasOwnProperty.call(
      globalThis,
      'SpeechRecognition'
    );
    globalThis.__speechRealRecognition = globalThis.SpeechRecognition;
    globalThis.__speechInstances = [];
    globalThis.SpeechRecognition = class FakeSpeechRecognition {
      constructor() {
        this.lang = '';
        this.continuous = false;
        this.interimResults = false;
        this.onstart = null;
        this.onresult = null;
        this.onerror = null;
        this.onend = null;
        this.abortCalls = 0;
        this.stopCalls = 0;
        this._results = [];
        globalThis.__speechInstances.push(this);
      }

      start() {}
      stop() { this.stopCalls += 1; }
      abort() { this.abortCalls += 1; }
      emitStart() { this.onstart?.({}); }
      emitResult(text, isFinal, index) {
        const result = [{ transcript: text }];
        result.isFinal = isFinal;
        this._results[index] = result;
        this.onresult?.({ resultIndex: index, results: this._results });
      }
      emitError(error) { this.onerror?.({ error }); }
      emitEnd() { this.onend?.({}); }
    };
  ''');
}

void _restoreRecognition() {
  _evaluate(r'''
    if (globalThis.__speechHadRecognition) {
      globalThis.SpeechRecognition = globalThis.__speechRealRecognition;
    } else {
      delete globalThis.SpeechRecognition;
    }
    delete globalThis.__speechHadRecognition;
    delete globalThis.__speechRealRecognition;
    delete globalThis.__speechInstances;
  ''');
}

void _evaluate(String source) {
  globalContext.callMethod<JSAny?>('eval'.toJS, source.toJS);
}

@JS('__speechInstances')
external JSArray<_FakeSpeechRecognition> get _speechInstances;

extension type _FakeSpeechRecognition(JSObject _) implements JSObject {
  external String lang;
  external bool interimResults;
  external int abortCalls;
  external int stopCalls;
  external void emitStart();
  external void emitResult(String text, bool isFinal, int index);
  external void emitError(String error);
  external void emitEnd();
}
