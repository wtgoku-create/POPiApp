import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/speech/speech_input.dart';

enum ComposerVoiceInputState { idle, starting, listening, stopping }

/// Replaces interim speech at the captured selection without duplicating words.
class ComposerVoiceInputController extends ChangeNotifier {
  ComposerVoiceInputController({
    required SpeechInput speechInput,
    required TextEditingController textController,
    required void Function(String code) onError,
  }) : _speechInput = speechInput,
       _textController = textController,
       _onError = onError {
    _textController.addListener(_handleDraftEdit);
  }

  final SpeechInput _speechInput;
  final TextEditingController _textController;
  final void Function(String code) _onError;
  ComposerVoiceInputState _state = ComposerVoiceInputState.idle;
  ComposerVoiceInputState get state => _state;
  bool get active => _state != ComposerVoiceInputState.idle;
  TextEditingValue? _original;
  String? _lastAppliedText;
  bool _applyingResult = false;
  bool _hasResult = false;
  bool _disposed = false;
  int _revision = 0;
  Timer? _recordingLimit;
  Timer? _finishLimit;

  Future<void> start(String locale) async {
    if (active || _disposed) return;
    final revision = ++_revision;
    _original = _textController.value;
    _lastAppliedText = _original!.text;
    _hasResult = false;
    _setState(ComposerVoiceInputState.starting);
    try {
      await _speechInput.start(
        locale: locale,
        onResult: (text) {
          if (!_current(revision) || text.trim().isEmpty) return;
          final original = _original!;
          final selection = original.selection.isValid
              ? original.selection
              : TextSelection.collapsed(offset: original.text.length);
          final start = selection.start.clamp(0, original.text.length);
          final end = selection.end.clamp(start, original.text.length);
          final next = original.text.replaceRange(start, end, text);
          _hasResult = true;
          _lastAppliedText = next;
          _applyingResult = true;
          try {
            _textController.value = TextEditingValue(
              text: next,
              selection: TextSelection.collapsed(offset: start + text.length),
            );
          } finally {
            _applyingResult = false;
          }
        },
        onError: (code) {
          if (_current(revision)) _fail(code);
        },
        onDone: () {
          if (!_current(revision)) return;
          final empty = !_hasResult;
          _finish();
          if (empty) _onError('no_speech');
        },
      );
      if (!_current(revision)) return;
      _setState(ComposerVoiceInputState.listening);
      _recordingLimit = Timer(const Duration(seconds: 60), stop);
    } on SpeechInputException catch (error) {
      if (_current(revision)) _fail(error.code);
    } catch (_) {
      if (_current(revision)) _fail('recognition_failed');
    }
  }

  Future<void> stop() async {
    if (!active || _disposed || _state == ComposerVoiceInputState.stopping) {
      return;
    }
    if (_state == ComposerVoiceInputState.starting) {
      cancel();
      return;
    }
    final revision = _revision;
    _recordingLimit?.cancel();
    _setState(ComposerVoiceInputState.stopping);
    // Keep accepting the final correction after the microphone has stopped.
    _finishLimit = Timer(const Duration(seconds: 5), () {
      if (!_current(revision)) return;
      final empty = !_hasResult;
      _finish();
      unawaited(_cancelRecognition());
      if (empty) _onError('no_speech');
    });
    try {
      await _speechInput.stop();
    } on SpeechInputException catch (error) {
      if (_current(revision)) _fail(error.code);
    } catch (_) {
      if (_current(revision)) _fail('recognition_failed');
    }
  }

  void cancel({bool discard = false}) {
    if (!active || _disposed) return;
    if (discard && _hasResult && _textController.text == _lastAppliedText) {
      _applyingResult = true;
      try {
        _textController.value = _original!;
      } finally {
        _applyingResult = false;
      }
    }
    _finish();
    unawaited(_cancelRecognition());
  }

  void _handleDraftEdit() {
    if (!_applyingResult &&
        active &&
        _textController.text != _lastAppliedText) {
      // A user edit or successful submission owns the draft from this point on.
      cancel();
    }
  }

  bool _current(int revision) => !_disposed && active && revision == _revision;

  void _fail(String code) {
    _finish();
    unawaited(_cancelRecognition());
    if (code != 'cancelled') _onError(code);
  }

  Future<void> _cancelRecognition() async {
    try {
      await _speechInput.cancel();
    } catch (_) {
      // Cancellation must not replace a useful error or affect the draft.
    }
  }

  void _finish() {
    _revision++;
    _recordingLimit?.cancel();
    _finishLimit?.cancel();
    _setState(ComposerVoiceInputState.idle);
  }

  void _setState(ComposerVoiceInputState value) {
    if (_disposed || _state == value) return;
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _recordingLimit?.cancel();
    _finishLimit?.cancel();
    _textController.removeListener(_handleDraftEdit);
    _speechInput.dispose();
    super.dispose();
  }
}
