import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:uuid/uuid.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/demo_fixtures.dart';
import '../data/demo_repository.dart';
import '../domain/demo_models.dart';

/// Keeps send lifecycle and chat synchronization outside the widget tree.
class DemoChatController extends ChangeNotifier {
  DemoChatController(this.repository, this.sessionId) {
    _sync();
    repository.addListener(_sync);
  }
  final DemoRepository repository;
  final String sessionId;
  final chat.InMemoryChatController chatController =
      chat.InMemoryChatController();
  bool _sending = false;
  bool _disposed = false;
  bool _syncing = false;
  bool _syncRequested = false;
  String? _pendingClientRequestId;
  String? _pendingBody;
  final Set<String> _respondingQuestionKeys = {};
  final Set<String> _submittedQuestionKeys = {};
  bool get sending => _sending;
  bool get running => repository.isSessionRunning(sessionId);
  bool get busy => sending || running || repository.isSessionLoading(sessionId);
  DemoSession get session => repository.session(sessionId);

  void _sync() {
    if (_disposed ||
        !repository.sessions.any((session) => session.id == sessionId)) {
      return;
    }
    _syncRequested = true;
    if (!_syncing) unawaited(_drainSync());
    notifyListeners();
  }

  Future<void> _drainSync() async {
    _syncing = true;
    try {
      while (_syncRequested && !_disposed) {
        _syncRequested = false;
        await _syncMessages();
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _syncMessages() async {
    final currentSession = repository.sessions
        .where((session) => session.id == sessionId)
        .firstOrNull;
    if (currentSession == null) return;
    final pendingQuestionKeys = currentSession.messages
        .map((message) => message.question)
        .whereType<DemoQuestion>()
        .where((question) => question.isPending)
        .map(_questionKey)
        .toSet();
    _submittedQuestionKeys.removeWhere(
      (key) => !pendingQuestionKeys.contains(key),
    );
    final next = currentSession.messages
        .where(_hasVisibleContent)
        .map(_chatMessage)
        .toList();
    final current = List<chat.Message>.of(chatController.messages);
    final currentById = {for (final message in current) message.id: message};
    for (final message in next) {
      final old = currentById[message.id];
      if (old != null && !_sameMessage(old, message)) {
        await chatController.updateMessage(old, message);
        if (_disposed) return;
      }
    }
    final structureChanged = !listEquals(
      current.map((message) => message.id).toList(),
      next.map((message) => message.id).toList(),
    );
    if (structureChanged) {
      await chatController.setMessages(next, animated: false);
    }
  }

  chat.TextMessage _chatMessage(DemoMessage message) => chat.TextMessage(
    id: message.id,
    authorId: message.user
        ? 'demo-user'
        : message.memberId.trim().isEmpty
        ? 'popi'
        : message.memberId,
    text: message.text,
    metadata: {'demo': message},
  );

  bool _sameMessage(chat.Message old, chat.TextMessage next) {
    if (old is! chat.TextMessage || old.authorId != next.authorId) return false;
    final oldDemo = old.metadata?['demo'];
    final nextDemo = next.metadata?['demo'];
    return oldDemo is DemoMessage &&
        nextDemo is DemoMessage &&
        oldDemo.text == nextDemo.text &&
        oldDemo.user == nextDemo.user &&
        oldDemo.status == nextDemo.status &&
        oldDemo.memberId == nextDemo.memberId &&
        oldDemo.memberName == nextDemo.memberName &&
        oldDemo.runId == nextDemo.runId &&
        oldDemo.configRevision == nextDemo.configRevision &&
        jsonEncode(oldDemo.question?.toJson()) ==
            jsonEncode(nextDemo.question?.toJson()) &&
        listEquals(oldDemo.assetIds, nextDemo.assetIds);
  }

  bool _hasVisibleContent(DemoMessage message) {
    if (message.status == 'skipped') return false;
    return message.text.trim().isNotEmpty ||
        message.assetIds.isNotEmpty ||
        message.question != null;
  }

  chat.User resolveUser(String id, AppLocalizations localizations) {
    if (id == 'demo-user') return chat.User(id: id);
    final currentName = session.memberNames[id]?.trim();
    final snapshotName = session.messages.reversed
        .where((message) => message.memberId == id)
        .map((message) => message.memberName.trim())
        .where((name) => name.isNotEmpty && name != id)
        .firstOrNull;
    final knownMember = DemoFixtures.memberImages.containsKey(id);
    return chat.User(
      id: id,
      name: currentName?.isNotEmpty == true
          ? currentName
          : snapshotName ??
                (knownMember ? _defaultMemberName(localizations, id) : id),
      imageSource: DemoFixtures.memberImage(
        id,
        savedImage: session.memberAvatars[id],
      ),
    );
  }

  String _defaultMemberName(AppLocalizations localizations, String id) =>
      switch (id) {
        'designer' => localizations.demoDesigner,
        'writer' => localizations.demoWriter,
        'director' => localizations.demoDirector,
        'sound' => localizations.demoSound,
        _ => localizations.demoPopi,
      };

  Future<bool> send(
    String text,
    List<String> assets,
    AppLocalizations l, {
    List<String> contextRoleIds = const [],
  }) async {
    if (busy || (text.trim().isEmpty && assets.isEmpty)) return false;
    _sending = true;
    notifyListeners();
    try {
      if (repository.isHarness) {
        final normalizedText = text.trim();
        final body = jsonEncode({
          'text': normalizedText,
          'assets': assets,
          'contextRoleIds': contextRoleIds,
        });
        if (_pendingBody != body) {
          _pendingBody = body;
          _pendingClientRequestId = const Uuid().v4();
        }
        try {
          await repository.sendHarnessMessage(
            sessionId,
            clientRequestId: _pendingClientRequestId!,
            text: normalizedText,
            mediaIds: assets,
            contextRoleIds: contextRoleIds,
            onAccepted: () {
              _sending = false;
              if (!_disposed) notifyListeners();
            },
          );
          _clearPendingRequest();
          return true;
        } on HarnessRunStoppedException {
          _clearPendingRequest();
          return false;
        } on HarnessRunTerminalException {
          _clearPendingRequest();
          rethrow;
        }
      }
      await repository.addMessage(
        sessionId,
        DemoMessage(
          id: const Uuid().v4(),
          text: text.trim(),
          user: true,
          assetIds: assets,
        ),
      );
      if (_disposed) return true;
      final memberId = session.members.contains(session.activeMemberId)
          ? session.activeMemberId
          : session.members.firstOrNull ?? 'popi';
      final memberName = session.memberNames[memberId] ?? '';
      var temporary = chat.TextMessage(
        id: const Uuid().v4(),
        authorId: memberId,
        text: l.demoThinking,
        metadata: {
          'demo': DemoMessage(
            id: 'thinking',
            text: l.demoThinking,
            memberId: memberId,
            memberName: memberName,
            configRevision: session.configRevision,
          ),
        },
      );
      await chatController.insertMessage(temporary);
      await Future<void>.delayed(const Duration(milliseconds: 450));
      final preview = l.demoGenerating;
      for (var i = 1; i <= preview.length; i++) {
        if (_disposed) return true;
        final next = temporary.copyWith(
          text: preview.substring(0, i),
          metadata: {
            'demo': DemoMessage(
              id: 'thinking',
              text: preview.substring(0, i),
              memberId: memberId,
              memberName: memberName,
              configRevision: session.configRevision,
            ),
          },
        );
        await chatController.updateMessage(temporary, next);
        temporary = next;
        await Future<void>.delayed(const Duration(milliseconds: 65));
      }
      if (_disposed) return true;
      await repository.reply(
        sessionId,
        text,
        text: l.demoReply,
        imageText: l.demoImageReply,
        scriptText: l.demoScriptReply,
        audioText: l.demoAudioReply,
        videoText: l.demoVideoReply,
      );
      return true;
    } finally {
      _sending = false;
      if (!_disposed) _sync();
    }
  }

  Future<void> stop() async {
    if (!repository.isHarness || !running) return;
    await repository.stopHarnessSession(sessionId);
  }

  bool questionBusy(String questionId) => {
    ..._respondingQuestionKeys,
    ..._submittedQuestionKeys,
  }.any((key) => key.startsWith('$questionId:'));

  Future<bool> respondQuestion(
    DemoQuestion question,
    String action,
    Map<String, Object?> answer,
  ) async {
    if (!repository.isHarness || !question.isPending) return false;
    final key = _questionKey(question);
    if (_respondingQuestionKeys.contains(key) ||
        _submittedQuestionKeys.contains(key)) {
      return false;
    }
    _respondingQuestionKeys.add(key);
    _submittedQuestionKeys.add(key);
    notifyListeners();
    try {
      await repository.respondHarnessQuestion(
        sessionId,
        questionId: question.id,
        revision: question.revision,
        action: action,
        answer: answer,
      );
      final latest = repository
          .session(sessionId)
          .messages
          .map((message) => message.question)
          .whereType<DemoQuestion>()
          .where((item) => item.id == question.id)
          .firstOrNull;
      if (latest == null ||
          latest.revision != question.revision ||
          !latest.isPending) {
        _submittedQuestionKeys.remove(key);
      }
      return true;
    } catch (_) {
      _submittedQuestionKeys.remove(key);
      rethrow;
    } finally {
      _respondingQuestionKeys.remove(key);
      if (!_disposed) _sync();
    }
  }

  String _questionKey(DemoQuestion question) =>
      '${question.id}:${question.revision}';

  void _clearPendingRequest() {
    _pendingBody = null;
    _pendingClientRequestId = null;
  }

  @override
  void dispose() {
    _disposed = true;
    repository.removeListener(_sync);
    chatController.dispose();
    super.dispose();
  }
}
