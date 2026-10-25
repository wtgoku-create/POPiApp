import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat;
import 'package:uuid/uuid.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../data/demo_fixtures.dart';
import '../data/demo_repository.dart';
import '../domain/demo_models.dart';
import 'demo_assistant_display.dart';

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
  DemoMessage? _provisionalActivityMessage;
  Set<String> _messageIdsBeforeSend = const {};
  bool _serverReplyObserved = false;
  final Set<String> _respondingQuestionKeys = {};
  final Set<String> _submittedQuestionKeys = {};
  bool get sending => _sending;
  bool get running => repository.isSessionRunning(sessionId);
  bool get canStop => repository.canStopCurrentHarnessRun(sessionId);
  bool get busy => sending || running || repository.isSessionLoading(sessionId);
  bool get waitingForResponse =>
      sending || running || _provisionalActivityMessage != null;
  bool get hasVisibleMessages => chatController.messages.isNotEmpty;
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
        if (!_disposed) notifyListeners();
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
    final persisted = currentSession.messages
        .where(_hasVisibleContent)
        .toList();
    if (!_serverReplyObserved && _provisionalActivityMessage != null) {
      _serverReplyObserved = persisted.any(
        (message) =>
            !message.user &&
            !_messageIdsBeforeSend.contains(message.id) &&
            (message.activity != null ||
                message.question != null ||
                message.filmJobId.isNotEmpty ||
                message.text.trim().isNotEmpty ||
                message.assetIds.isNotEmpty),
      );
    }
    final next = <chat.TextMessage>[
      ...persisted.map(_chatMessage),
      if (_provisionalActivityMessage case final provisional?)
        if (!_serverReplyObserved) _chatMessage(provisional),
    ];
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
    metadata: {
      'demo': message,
      if (message.filmJobId.isNotEmpty)
        'filmJobFingerprint': jsonEncode(
          session.filmJobs
              .where((job) => job.jobId == message.filmJobId)
              .firstOrNull
              ?.toJson(),
        ),
    },
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
        oldDemo.filmJobId == nextDemo.filmJobId &&
        old.metadata?['filmJobFingerprint'] ==
            next.metadata?['filmJobFingerprint'] &&
        jsonEncode(oldDemo.question?.toJson()) ==
            jsonEncode(nextDemo.question?.toJson()) &&
        jsonEncode(oldDemo.activity?.toJson()) ==
            jsonEncode(nextDemo.activity?.toJson()) &&
        listEquals(oldDemo.assetIds, nextDemo.assetIds);
  }

  bool _hasVisibleContent(DemoMessage message) {
    if (message.status == 'skipped') return false;
    return message.text.trim().isNotEmpty ||
        message.filmJobId.isNotEmpty ||
        message.assetIds.isNotEmpty ||
        message.question != null ||
        message.activity != null;
  }

  /// Reconciles a completed assistant turn with asynchronous media workers.
  ///
  /// A model reply can finish before its image, video, or audio job. Matching
  /// run jobs therefore remain visible as real generation progress until the
  /// worker and asset ingestion reach a terminal state.
  DemoActivity? activityFor(DemoMessage message) {
    final activity = message.activity;
    if (activity == null ||
        message.question != null ||
        message.runId.isEmpty ||
        activity.status != 'completed') {
      return activity;
    }
    final mediaAnchor = session.messages.reversed
        .where(
          (candidate) =>
              !candidate.user &&
              candidate.question == null &&
              candidate.activity != null &&
              candidate.runId == message.runId &&
              (candidate.memberId.isEmpty ||
                  message.memberId.isEmpty ||
                  candidate.memberId == message.memberId),
        )
        .firstOrNull;
    if (mediaAnchor?.id != message.id) return activity;
    final jobs = session.mediaJobs
        .where(
          (job) =>
              job.runId == message.runId &&
              (job.memberId.isEmpty ||
                  message.memberId.isEmpty ||
                  job.memberId == message.memberId),
        )
        .toList();
    if (jobs.isEmpty) return activity;

    final jobSteps = jobs.map(
      (job) => DemoActivityStep(
        id: 'media-job:${job.jobId}',
        kind: _activityKindForJob(job),
        status: _activityStatusForJob(job),
      ),
    );
    final allSteps = <DemoActivityStep>[
      ...activity.steps.where(
        (step) => !jobSteps.any((jobStep) => jobStep.id == step.id),
      ),
      ...jobSteps,
    ];
    final mergedSteps = allSteps.length <= 12
        ? allSteps
        : allSteps.sublist(allSteps.length - 12);
    final pending = jobs.where((job) => job.isPending).firstOrNull;
    if (pending != null) {
      return activity.copyWith(
        kind: _activityKindForJob(pending),
        status: 'running',
        steps: mergedSteps,
      );
    }
    final failed = jobs.where((job) {
      return const {'failed', 'unknown', 'error'}.contains(job.state) ||
          job.ingestionState == 'failed';
    }).firstOrNull;
    if (failed != null) {
      return activity.copyWith(
        kind: _activityKindForJob(failed),
        status: 'failed',
        steps: mergedSteps,
      );
    }
    final stopped = jobs.where((job) {
      return const {'canceled', 'cancelled', 'stopped'}.contains(job.state);
    }).firstOrNull;
    if (stopped != null) {
      return activity.copyWith(
        kind: _activityKindForJob(stopped),
        status: 'stopped',
        steps: mergedSteps,
      );
    }
    return activity.copyWith(status: 'completed', steps: mergedSteps);
  }

  String _activityKindForJob(DemoMediaJob job) {
    final operation = job.operation.toLowerCase();
    for (final kind in const ['image', 'video']) {
      if (operation.contains(kind)) return kind;
    }
    if (const ['audio', 'tts', 'music', 'speech'].any(operation.contains)) {
      return 'audio';
    }
    return 'tool';
  }

  String _activityStatusForJob(DemoMediaJob job) {
    if (job.isPending) return 'running';
    if (const {'failed', 'unknown', 'error'}.contains(job.state) ||
        job.ingestionState == 'failed') {
      return 'failed';
    }
    if (const {'canceled', 'cancelled', 'stopped'}.contains(job.state)) {
      return 'stopped';
    }
    return 'completed';
  }

  chat.User resolveUser(String id, AppLocalizations localizations) {
    if (id == 'demo-user') return chat.User(id: id);
    final snapshotName = session.messages.reversed
        .where((message) => message.memberId == id)
        .map((message) => message.memberName.trim())
        .where((name) => name.isNotEmpty && name != id)
        .firstOrNull;
    final knownMember = DemoFixtures.memberImages.containsKey(id);
    return chat.User(
      id: id,
      name:
          knownMember ||
              snapshotName != null ||
              session.memberNames.containsKey(id)
          ? demoSessionMemberName(
              localizations,
              session,
              id,
              snapshotName: snapshotName,
            )
          : id,
      imageSource: DemoFixtures.memberImage(
        id,
        savedImage: session.memberAvatars[id],
      ),
    );
  }

  Future<bool> send(
    String text,
    List<String> assets,
    AppLocalizations l, {
    List<String> contextRoleIds = const [],
    DemoStyleFilmInvocation? skillInvocation,
    VoidCallback? onAccepted,
  }) async {
    if (busy || (text.trim().isEmpty && assets.isEmpty)) return false;
    _sending = true;
    notifyListeners();
    try {
      if (repository.isHarness) {
        final invocation =
            session
                .skillsFor(session.activeMemberId)
                .contains(demoStyleFilmSkillId)
            ? skillInvocation
            : null;
        final normalizedText = text.trim();
        final body = jsonEncode({
          'text': normalizedText,
          'assets': assets,
          'contextRoleIds': contextRoleIds,
          if (invocation != null) 'skillInvocation': invocation.toJson(),
          if (invocation != null)
            'botId': session.botIdFor(session.activeMemberId),
        });
        if (_pendingBody != body) {
          _pendingBody = body;
          _pendingClientRequestId = const Uuid().v4();
        }
        if (invocation != null) {
          _pendingClientRequestId = await repository.prepareStyleFilmRequest(
            sessionId,
            session.botIdFor(session.activeMemberId),
            body: body,
            proposedRequestId: _pendingClientRequestId!,
          );
        }
        await _showProvisionalActivity(_pendingClientRequestId!, l);
        final clientRequestId = _pendingClientRequestId!;
        var acceptedNotified = false;
        try {
          await repository.sendHarnessMessage(
            sessionId,
            clientRequestId: clientRequestId,
            text: normalizedText,
            mediaIds: assets,
            contextRoleIds: contextRoleIds,
            skillInvocation: invocation,
            onAccepted: () {
              if (acceptedNotified) return;
              acceptedNotified = true;
              if (invocation != null) _clearPendingRequest();
              _sending = false;
              if (!_disposed) notifyListeners();
              onAccepted?.call();
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
      final memberName = demoSessionMemberName(l, session, memberId);
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
      _clearProvisionalActivity();
      if (!_disposed) _sync();
    }
  }

  Future<void> stop() async {
    if (!repository.isHarness || !running || !canStop) return;
    try {
      await repository.stopHarnessSession(sessionId);
    } finally {
      _clearProvisionalActivity();
      if (!_disposed) _sync();
    }
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

  Future<void> _showProvisionalActivity(
    String clientRequestId,
    AppLocalizations localizations,
  ) async {
    final currentSession = session;
    final memberId =
        currentSession.members.contains(currentSession.activeMemberId)
        ? currentSession.activeMemberId
        : currentSession.members.firstOrNull ?? 'popi';
    final provisional = DemoMessage(
      id: 'local-activity:$clientRequestId',
      text: '',
      status: 'pending',
      memberId: memberId,
      memberName: demoSessionMemberName(
        localizations,
        currentSession,
        memberId,
      ),
      configRevision: currentSession.configRevision,
      activity: const DemoActivity(
        kind: 'thinking',
        status: 'running',
        steps: [
          DemoActivityStep(id: 'thinking', kind: 'thinking', status: 'running'),
        ],
      ),
    );
    _messageIdsBeforeSend = currentSession.messages
        .map((message) => message.id)
        .toSet();
    _serverReplyObserved = false;
    _provisionalActivityMessage = provisional;
    if (!chatController.messages.any(
      (message) => message.id == provisional.id,
    )) {
      await chatController.insertMessage(_chatMessage(provisional));
    }
    if (!_disposed) notifyListeners();
  }

  void _clearProvisionalActivity() {
    if (_provisionalActivityMessage == null) return;
    _provisionalActivityMessage = null;
    _messageIdsBeforeSend = const {};
    _serverReplyObserved = false;
  }

  @override
  void dispose() {
    _disposed = true;
    repository.removeListener(_sync);
    chatController.dispose();
    super.dispose();
  }
}
