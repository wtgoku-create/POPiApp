import 'dart:async';

import 'package:flutter/services.dart';

import 'speech_input_contract.dart';

const _channel = MethodChannel('art.popi/speech_input');

SpeechInput createSpeechInput() =>
    NativeSpeechInput._(_NativeSpeechRouter.instance);

final class NativeSpeechInput implements SpeechInput {
  NativeSpeechInput._(this._router);

  final _NativeSpeechRouter _router;
  String? _sessionId;
  bool _disposed = false;

  @override
  Future<void> start({
    required String locale,
    required void Function(String text) onResult,
    required void Function(String code) onError,
    required void Function() onDone,
  }) async {
    if (_disposed) throw const SpeechInputException('cancelled');
    if (_sessionId != null) {
      throw const SpeechInputException('recognition_failed');
    }

    late final String sessionId;
    sessionId = _router.attach(
      onResult: onResult,
      onError: onError,
      onDone: () {
        if (_sessionId == sessionId) _sessionId = null;
        onDone();
      },
    );
    _sessionId = sessionId;
    try {
      await _router.start(sessionId: sessionId, locale: locale);
    } on PlatformException catch (error) {
      _router.detach(sessionId);
      if (_sessionId == sessionId) _sessionId = null;
      throw SpeechInputException(_platformErrorCode(error.code));
    } on MissingPluginException {
      _router.detach(sessionId);
      if (_sessionId == sessionId) _sessionId = null;
      throw const SpeechInputException('unavailable');
    } catch (_) {
      _router.detach(sessionId);
      if (_sessionId == sessionId) _sessionId = null;
      throw const SpeechInputException('recognition_failed');
    }

    // Cancellation may win while the platform is still answering start.
    if (_sessionId != sessionId || !_router.contains(sessionId)) {
      throw const SpeechInputException('cancelled');
    }
    _router.activate(sessionId);
  }

  @override
  Future<void> stop() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    try {
      await _router.stop(sessionId);
    } on PlatformException catch (error) {
      throw SpeechInputException(_platformErrorCode(error.code));
    } on MissingPluginException {
      throw const SpeechInputException('unavailable');
    }
  }

  @override
  Future<void> cancel() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    _sessionId = null;
    _router.detach(sessionId);
    try {
      await _router.cancel(sessionId);
    } on PlatformException catch (error) {
      throw SpeechInputException(_platformErrorCode(error.code));
    } on MissingPluginException {
      throw const SpeechInputException('unavailable');
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final sessionId = _sessionId;
    if (sessionId == null) return;
    _sessionId = null;
    _router.detach(sessionId);
    unawaited(_router.cancel(sessionId).catchError((Object _) {}));
  }
}

final class _NativeSpeechRouter {
  _NativeSpeechRouter._() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static final instance = _NativeSpeechRouter._();

  final Map<String, _NativeSpeechSession> _sessions = {};
  var _nextSessionId = 0;

  String attach({
    required void Function(String text) onResult,
    required void Function(String code) onError,
    required void Function() onDone,
  }) {
    final sessionId =
        '${DateTime.now().microsecondsSinceEpoch}-${_nextSessionId++}';
    _sessions[sessionId] = _NativeSpeechSession(
      onResult: onResult,
      onError: onError,
      onDone: onDone,
    );
    return sessionId;
  }

  bool contains(String sessionId) => _sessions.containsKey(sessionId);

  void activate(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return;
    session.active = true;
    final pendingEvents = List<Map<Object?, Object?>>.of(session.pendingEvents);
    session.pendingEvents.clear();
    for (final event in pendingEvents) {
      _routeEvent(event);
    }
  }

  void detach(String sessionId) => _sessions.remove(sessionId);

  Future<void> start({required String sessionId, required String locale}) =>
      _channel.invokeMethod<void>('start', {
        'sessionId': sessionId,
        'locale': locale,
      });

  Future<void> stop(String sessionId) =>
      _channel.invokeMethod<void>('stop', {'sessionId': sessionId});

  Future<void> cancel(String sessionId) =>
      _channel.invokeMethod<void>('cancel', {'sessionId': sessionId});

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method != 'event' || call.arguments is! Map) return;
    final event = Map<Object?, Object?>.from(call.arguments as Map);
    final sessionId = event['sessionId'];
    final type = event['type'];
    if (sessionId is! String || type is! String) return;
    final session = _sessions[sessionId];
    if (session == null) return;
    if (!session.active) {
      session.pendingEvents.add(event);
      return;
    }
    _routeEvent(event);
  }

  void _routeEvent(Map<Object?, Object?> event) {
    final sessionId = event['sessionId'];
    final type = event['type'];
    if (sessionId is! String || type is! String) return;
    final session = _sessions[sessionId];
    if (session == null) return;

    switch (type) {
      case 'result':
        final text = event['text'];
        if (text is String) session.onResult(text);
      case 'error':
        _sessions.remove(sessionId);
        final code = event['code'];
        session.onError(
          code is String ? _platformErrorCode(code) : 'recognition_failed',
        );
        session.onDone();
      case 'done':
        _sessions.remove(sessionId);
        session.onDone();
    }
  }
}

final class _NativeSpeechSession {
  _NativeSpeechSession({
    required this.onResult,
    required this.onError,
    required this.onDone,
  });

  final void Function(String text) onResult;
  final void Function(String code) onError;
  final void Function() onDone;
  final List<Map<Object?, Object?>> pendingEvents = [];
  bool active = false;
}

String _platformErrorCode(String code) => switch (code) {
  'permission_denied' ||
  'unavailable' ||
  'audio' ||
  'network' ||
  'no_speech' ||
  'recognition_failed' ||
  'cancelled' => code,
  _ => 'recognition_failed',
};
