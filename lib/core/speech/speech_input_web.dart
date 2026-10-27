import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'speech_input_contract.dart';

SpeechInput createSpeechInput() => WebSpeechInput();

final class WebSpeechInput implements SpeechInput {
  static WebSpeechInput? _owner;

  _SpeechRecognition? _recognition;
  Completer<void>? _starting;
  void Function(String code)? _onError;
  void Function()? _onDone;
  Object? _session;
  bool _started = false;
  bool _disposed = false;
  bool _completed = false;

  @override
  Future<void> start({
    required String locale,
    required void Function(String text) onResult,
    required void Function(String code) onError,
    required void Function() onDone,
  }) async {
    if (_disposed) throw const SpeechInputException('cancelled');
    if (_session != null) {
      throw const SpeechInputException('recognition_failed');
    }

    final constructor = _constructor;
    if (constructor == null) throw const SpeechInputException('unavailable');
    final previousOwner = _owner;
    if (previousOwner != null && previousOwner != this) {
      await previousOwner._supersede();
    }
    if (_disposed) throw const SpeechInputException('cancelled');

    final session = Object();
    final starting = Completer<void>();
    late final _SpeechRecognition recognition;
    try {
      recognition = constructor.callAsConstructor<_SpeechRecognition>();
    } catch (error) {
      throw SpeechInputException(_startErrorCode(error));
    }
    final transcripts = <int, String>{};
    _owner = this;
    _session = session;
    _starting = starting;
    _onError = onError;
    _onDone = onDone;
    _recognition = recognition;
    _started = false;
    _completed = false;
    recognition
      ..lang = locale
      ..continuous = true
      ..interimResults = true
      ..onstart = (() {
        if (_session != session) return;
        _started = true;
        if (!starting.isCompleted) starting.complete();
      }).toJS
      ..onresult = ((JSAny eventValue) {
        if (_session != session) return;
        final event = eventValue as _SpeechRecognitionEvent;
        transcripts.removeWhere((index, _) => index >= event.results.length);
        for (
          var index = event.resultIndex;
          index < event.results.length;
          index++
        ) {
          final result = event.results[index];
          if (result.length == 0) continue;
          transcripts[index] = result[0].transcript;
        }
        onResult(_joinTranscripts(transcripts));
      }).toJS
      ..onerror = ((JSAny eventValue) {
        if (_session != session) return;
        final code = _webErrorCode(
          (eventValue as _SpeechRecognitionErrorEvent).error,
        );
        if (!_started && !starting.isCompleted) {
          _clearSession(session);
          _abortRecognition(recognition);
          starting.completeError(SpeechInputException(code));
          return;
        }
        _fail(session, recognition, code, onError, onDone);
      }).toJS
      ..onend = (() {
        if (_session != session) return;
        if (!_started && !starting.isCompleted) {
          _clearSession(session);
          _abortRecognition(recognition);
          starting.completeError(
            const SpeechInputException('recognition_failed'),
          );
          return;
        }
        _finish(session, onDone);
      }).toJS;

    try {
      recognition.start();
    } catch (error) {
      _clearSession(session);
      _abortRecognition(recognition);
      throw SpeechInputException(_startErrorCode(error));
    }
    await starting.future;
  }

  @override
  Future<void> stop() async {
    final recognition = _recognition;
    if (_session == null || recognition == null) return;
    try {
      recognition.stop();
    } catch (error) {
      throw SpeechInputException(_startErrorCode(error));
    }
  }

  @override
  Future<void> cancel() async {
    final session = _session;
    final recognition = _recognition;
    if (session == null || recognition == null) return;
    final starting = _starting;
    _clearSession(session);
    if (starting != null && !starting.isCompleted) {
      starting.completeError(const SpeechInputException('cancelled'));
    }
    _abortRecognition(recognition);
  }

  Future<void> _supersede() async {
    final session = _session;
    final recognition = _recognition;
    if (session == null || recognition == null) return;
    final starting = _starting;
    final wasStarted = _started;
    final onError = _onError;
    final onDone = _onDone;
    _clearSession(session);
    if (starting != null && !starting.isCompleted) {
      starting.completeError(const SpeechInputException('cancelled'));
    }
    _abortRecognition(recognition);
    if (wasStarted) {
      onError?.call('cancelled');
      onDone?.call();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(cancel());
  }

  void _finish(Object session, void Function() onDone) {
    if (_session != session || _completed) return;
    _completed = true;
    _clearSession(session);
    onDone();
  }

  void _fail(
    Object session,
    _SpeechRecognition recognition,
    String code,
    void Function(String code) onError,
    void Function() onDone,
  ) {
    if (_session != session || _completed) return;
    _completed = true;
    _clearSession(session);
    _abortRecognition(recognition);
    onError(code);
    onDone();
  }

  void _clearSession(Object session) {
    if (_session != session) return;
    final recognition = _recognition;
    if (recognition != null) {
      recognition
        ..onstart = null
        ..onresult = null
        ..onerror = null
        ..onend = null;
    }
    _session = null;
    _recognition = null;
    _starting = null;
    _onError = null;
    _onDone = null;
    _started = false;
    if (_owner == this) _owner = null;
  }
}

void _abortRecognition(_SpeechRecognition recognition) {
  try {
    recognition.abort();
  } catch (_) {
    // The Web Speech API ignores abort after recognition has already ended.
  }
}

JSFunction? get _constructor {
  final standard = globalContext.getProperty<JSAny?>('SpeechRecognition'.toJS);
  if (standard != null && standard.isA<JSFunction>()) {
    return standard as JSFunction;
  }
  final webkit = globalContext.getProperty<JSAny?>(
    'webkitSpeechRecognition'.toJS,
  );
  if (webkit != null && webkit.isA<JSFunction>()) return webkit as JSFunction;
  return null;
}

String _joinTranscripts(Map<int, String> transcripts) {
  final indexes = transcripts.keys.toList()..sort();
  final output = StringBuffer();
  var previous = '';
  for (final index in indexes) {
    final current = transcripts[index]!.trim();
    if (current.isEmpty) continue;
    if (previous.isNotEmpty &&
        _isAsciiWord(previous.codeUnitAt(previous.length - 1)) &&
        _isAsciiWord(current.codeUnitAt(0))) {
      output.write(' ');
    }
    output.write(current);
    previous = current;
  }
  return output.toString();
}

bool _isAsciiWord(int codeUnit) =>
    (codeUnit >= 0x30 && codeUnit <= 0x39) ||
    (codeUnit >= 0x41 && codeUnit <= 0x5a) ||
    (codeUnit >= 0x61 && codeUnit <= 0x7a);

String _webErrorCode(String error) => switch (error) {
  'not-allowed' || 'service-not-allowed' => 'permission_denied',
  'audio-capture' => 'audio',
  'network' => 'network',
  'no-speech' => 'no_speech',
  'aborted' => 'cancelled',
  'language-not-supported' => 'unavailable',
  _ => 'recognition_failed',
};

String _startErrorCode(Object error) {
  final description = error.toString().toLowerCase();
  if (description.contains('notallowed') ||
      description.contains('not allowed') ||
      description.contains('permission')) {
    return 'permission_denied';
  }
  if (description.contains('not supported') ||
      description.contains('unsupported')) {
    return 'unavailable';
  }
  return 'recognition_failed';
}

extension type _SpeechRecognition(JSObject _) implements JSObject {
  external String lang;
  external bool continuous;
  external bool interimResults;
  external JSFunction? onstart;
  external JSFunction? onresult;
  external JSFunction? onerror;
  external JSFunction? onend;
  external void start();
  external void stop();
  external void abort();
}

extension type _SpeechRecognitionEvent(JSObject _) implements JSObject {
  external int resultIndex;
  external _SpeechRecognitionResultList results;
}

extension type _SpeechRecognitionResultList(JSObject _) implements JSObject {
  external int length;
  external _SpeechRecognitionResult operator [](int index);
}

extension type _SpeechRecognitionResult(JSObject _) implements JSObject {
  external int length;
  external bool isFinal;
  external _SpeechRecognitionAlternative operator [](int index);
}

extension type _SpeechRecognitionAlternative(JSObject _) implements JSObject {
  external String transcript;
}

extension type _SpeechRecognitionErrorEvent(JSObject _) implements JSObject {
  external String error;
}
