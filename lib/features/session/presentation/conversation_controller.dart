import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/agent_api_exception.dart';
import '../data/conversation_events.dart';
import '../data/session_repository.dart';
import '../domain/conversation_session.dart';
import '../domain/conversation_snapshot.dart';

enum ConversationConnection { offline, connecting, connected, reconnecting }

/// Page-local lifecycle; obsolete streams cannot update another conversation.
class ConversationController extends ChangeNotifier {
  ConversationController(
    this.repository,
    this.userId, {
    this.onSessionChanged,
    this.reconnectDelay = const Duration(seconds: 1),
  });
  final SessionRepository repository;
  final String userId;
  final void Function(ConversationSession)? onSessionChanged;
  final Duration reconnectDelay;
  ConversationSnapshot? snapshot;
  ConversationConnection connection = ConversationConnection.offline;
  Object? error;
  bool loading = false;
  bool pending = false;
  bool _awaitingRun = false;
  bool get running => _awaitingRun || (snapshot?.running ?? false);
  String? sessionId;
  int _epoch = 0;
  int _commandEpoch = 0;
  bool _disposed = false;
  CancelToken? _eventsToken;
  CancelToken? _commandToken;
  Timer? _timer;
  Completer<void>? _delay;

  void open(String? id) {
    // HTTP 和 SSE 各自有生命周期编号，旧会话的迟到结果不得写入新会话。
    _commandEpoch++;
    _commandToken?.cancel();
    _cancelEvents();
    sessionId = id;
    snapshot = null;
    error = null;
    pending = false;
    _awaitingRun = false;
    loading = id != null;
    connection = id == null
        ? ConversationConnection.offline
        : ConversationConnection.connecting;
    notifyListeners();
    if (id != null) unawaited(_connect(id, _epoch));
  }

  void refresh() {
    final id = sessionId;
    if (id == null || _disposed) return;
    _cancelEvents();
    snapshot = null;
    loading = true;
    notifyListeners();
    unawaited(_connect(id, _epoch));
  }

  Future<void> _connect(String id, int epoch) async {
    final token = CancelToken();
    _eventsToken = token;
    var attempts = 0;
    bool current() => !_disposed && epoch == _epoch && !token.isCancelled;
    while (current()) {
      try {
        connection = attempts == 0
            ? ConversationConnection.connecting
            : ConversationConnection.reconnecting;
        notifyListeners();
        if (snapshot == null) {
          final data = await repository.snapshot(id, cancelToken: token);
          if (!current()) return;
          snapshot = data;
          _awaitingRun = false;
          loading = false;
          onSessionChanged?.call(data.session);
          notifyListeners();
        }
        await for (final event in repository.events(
          id,
          snapshot!.lastSeq,
          token,
          onConnected: () {
            if (!current()) return;
            connection = ConversationConnection.connected;
            error = null;
            notifyListeners();
          },
        )) {
          if (!current()) return;
          snapshot = applyConversationEvent(snapshot!, event);
          if (event.type.startsWith('run.')) _awaitingRun = false;
          onSessionChanged?.call(snapshot!.session);
          attempts = 0;
          notifyListeners();
        }
      } catch (cause) {
        if (!current()) return;
        if (cause is AgentApiException && cause.code == 'SNAPSHOT_REQUIRED') {
          // 游标过期或事件缺号时先同步权威快照，再从 lastSeq 继续订阅。
          snapshot = null;
          continue;
        }
        if (cause is FormatException || cause is TypeError) snapshot = null;
        error = cause;
        if (cause is AgentApiException &&
            [401, 403, 404].contains(cause.statusCode)) {
          loading = false;
          connection = ConversationConnection.offline;
          notifyListeners();
          return;
        }
      }
      if (!current()) return;
      connection = ConversationConnection.reconnecting;
      loading = false;
      notifyListeners();
      final delay = Completer<void>();
      _delay = delay;
      _timer = Timer(
        Duration(
          milliseconds: math.min(
            30000,
            reconnectDelay.inMilliseconds * (1 << math.min(attempts++, 5)),
          ),
        ),
        () {
          if (!delay.isCompleted) delay.complete();
        },
      );
      await delay.future;
    }
  }

  Future<bool> send(
    String text,
    List<({String name, Uint8List bytes})> images,
    String newTitle,
    String mediaPrompt,
  ) => running || loading
      ? Future.value(false)
      : act((token) async {
          if (sessionId == null) {
            final session = await repository.create(
              userId,
              newTitle,
              cancelToken: token,
            );
            if (token.isCancelled || _disposed) return;
            sessionId = session.id;
            onSessionChanged?.call(session);
            notifyListeners();
          }
          final mediaIds = <String>[];
          for (final image in images) {
            mediaIds.add(
              await repository.upload(
                userId,
                image.name,
                image.bytes,
                cancelToken: token,
              ),
            );
            if (token.isCancelled) return;
          }
          await repository.send(
            userId,
            sessionId!,
            text.isEmpty ? mediaPrompt : text,
            mediaIds,
            cancelToken: token,
          );
          if (!token.isCancelled) _awaitingRun = true;
        }, refreshAfter: true);

  Future<bool> stop() => act(
    (token) => repository.stop(userId, sessionId!, cancelToken: token),
    refreshAfter: true,
  );
  Future<bool> retry(String runId) => running
      ? Future.value(false)
      : act(
          (token) => repository.retry(userId, runId, cancelToken: token),
          refreshAfter: true,
        );
  Future<bool> answer(
    ConversationBlock question,
    String action,
    Map<String, Object?> answer,
  ) => act(
    (token) => repository.answer(
      sessionId!,
      question,
      action,
      answer,
      cancelToken: token,
    ),
    refreshAfter: true,
  );
  Future<bool> confirm(ConversationBlock card, String action) => act(
    (token) => repository.confirm(
      userId,
      sessionId!,
      card,
      action,
      cancelToken: token,
    ),
    refreshAfter: true,
  );

  Future<bool> act(
    Future<void> Function(CancelToken) action, {
    bool refreshAfter = false,
  }) async {
    if (pending || _disposed) return false;
    final epoch = _commandEpoch;
    final token = CancelToken();
    _commandToken = token;
    pending = true;
    error = null;
    notifyListeners();
    bool current() =>
        !_disposed && epoch == _commandEpoch && !token.isCancelled;
    try {
      await action(token);
      if (!current()) return false;
      if (refreshAfter) refresh();
      return true;
    } catch (cause) {
      if (!current()) return false;
      if (cause is AgentApiException && cause.statusCode == 409) refresh();
      error = cause;
      return false;
    } finally {
      if (current()) {
        pending = false;
        notifyListeners();
      }
    }
  }

  void _cancelEvents() {
    _epoch++;
    _eventsToken?.cancel();
    _timer?.cancel();
    if (!(_delay?.isCompleted ?? true)) _delay!.complete();
  }

  @override
  void dispose() {
    _disposed = true;
    _commandEpoch++;
    _commandToken?.cancel();
    _cancelEvents();
    super.dispose();
  }
}
