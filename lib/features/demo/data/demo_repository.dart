import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/agent_api_exception.dart';
import '../../../core/network/network_agent_api.dart';
import '../../../core/storage/preferences_storage.dart';
import '../../../shared/type/bot_avatar_type.dart';
import '../domain/demo_assistant_profile.dart';
import '../domain/demo_models.dart';
import '../domain/demo_upload_file.dart';
import '../domain/demo_capability_catalog.dart';
import 'demo_fixtures.dart';

export '../domain/demo_capability_catalog.dart';
export '../domain/demo_assistant_profile.dart';

/// The demo store can run against bundled fixtures or the isolated local Harness.
class DemoRepository extends ChangeNotifier {
  DemoRepository(this._storage)
    : _api = null,
      _storageKey = storageKey,
      _pollInterval = Duration.zero,
      _questionPollInterval = Duration.zero,
      _maxPollAttempts = 0,
      _sessions = DemoFixtures.sessions(),
      _assets = DemoFixtures.assets();

  DemoRepository.harness(
    this._storage,
    NetworkAgentApi api, {
    Duration pollInterval = const Duration(milliseconds: 350),
    Duration questionPollInterval = const Duration(seconds: 2),
    int maxPollAttempts = 900,
  }) : _api = api,
       _storageKey = harnessStorageKey,
       _pollInterval = pollInterval,
       _questionPollInterval = questionPollInterval,
       _maxPollAttempts = maxPollAttempts,
       _sessions = [],
       _assets = [];

  static const storageKey = 'popi_ui_demo_v1';
  static const backupStorageKey = 'popi_ui_demo_v1_before_harness';
  static const harnessStorageKey = 'popi_harness_demo_v1';

  final PreferencesStorage _storage;
  final NetworkAgentApi? _api;
  final String _storageKey;
  final Duration _pollInterval;
  final Duration _questionPollInterval;
  final int _maxPollAttempts;
  final Map<String, String> _requestIds = {};
  final Set<String> _stopRequestedSessions = {};
  final Set<String> _runningSessions = {};
  final Map<String, Completer<void>> _questionWaiters = {};
  final Map<String, ({String payloadSignature, Future<void> operation})>
  _questionResponses = {};
  final Map<String, Future<void>> _questionRunWatchers = {};
  final Map<String, Future<void>> _mediaWatchers = {};
  final Map<String, int> _latestAppliedSnapshotRequest = {};
  final Map<String, DemoAsset> _uploadedFiles = {};
  Map<String, Set<String>> _dismissedMediaJobIds = {};
  List<DemoSession> _sessions;
  List<DemoAsset> _assets;
  Future<void> _pending = Future.value();
  int _snapshotRequestSerial = 0;
  int _assetListRequestSerial = 0;
  int _latestAppliedAssetListRequest = 0;
  bool _disposed = false;
  bool _loading = false;
  final Set<String> _loadingSessions = {};

  bool get isHarness => _api != null;
  bool get loading => _loading;
  bool isSessionLoading(String id) => _loadingSessions.contains(id);
  bool isSessionRunning(String id) => _runningSessions.contains(id);
  List<DemoSession> get sessions => List.unmodifiable([
    ..._sessions.where((session) => session.pinned),
    ..._sessions.where((session) => !session.pinned),
  ]);
  List<DemoAsset> get assets => List.unmodifiable(_assets);
  DemoSession session(String id) => _sessions.firstWhere((s) => s.id == id);

  /// Saved conversation identities can be reused without sharing conversation
  /// history or introducing unsupported execution member IDs.
  List<DemoAssistantProfile> get assistantProfiles {
    final profiles = <DemoAssistantProfile>[
      for (final memberId in DemoFixtures.memberImages.keys)
        DemoAssistantProfile(id: 'builtin:$memberId', memberId: memberId),
    ];
    final seen = <String>{};
    for (final session in sessions) {
      for (final memberId in session.members) {
        if (!DemoFixtures.memberImages.containsKey(memberId)) continue;
        final name = session.memberNames[memberId]?.trim() ?? '';
        final instructions = session.memberInstructions[memberId]?.trim() ?? '';
        final savedAvatar = session.memberAvatars[memberId] ?? '';
        final avatar = savedAvatar.isEmpty
            ? ''
            : DemoFixtures.memberImage(memberId, savedImage: savedAvatar);
        final color = session.memberColors[memberId];
        if (name.isEmpty &&
            instructions.isEmpty &&
            avatar.isEmpty &&
            color == null) {
          continue;
        }
        final identity = sha256
            .convert(
              utf8.encode(
                jsonEncode([memberId, name, instructions, avatar, color]),
              ),
            )
            .toString();
        if (!seen.add(identity)) continue;
        profiles.add(
          DemoAssistantProfile(
            id: 'saved:$identity',
            memberId: memberId,
            name: name,
            instructions: instructions,
            avatarAsset: avatar,
            avatarColor: color,
          ),
        );
      }
    }
    return List.unmodifiable(profiles);
  }

  Future<DemoCapabilityCatalog> loadCapabilityCatalog({
    String? sessionId,
  }) async {
    final api = _api;
    if (api == null) return DemoCapabilityCatalog.offline;
    return DemoCapabilityCatalog.fromResponse(
      await api.harnessCapabilities(sessionId: sessionId),
    );
  }

  bool isMediaJobNoticeDismissed(String sessionId, String jobId) {
    final job = _mediaJob(sessionId, jobId);
    return job != null &&
        !job.isPending &&
        (_dismissedMediaJobIds[sessionId]?.contains(jobId) ?? false);
  }

  /// Hides a completed media notice without changing its task or assets.
  Future<void> dismissMediaJobNotice(String sessionId, String jobId) {
    final operation = _pending.then((_) async {
      if (_disposed) return;
      final job = _mediaJob(sessionId, jobId);
      if (job == null || job.isPending) return;
      if (_dismissedMediaJobIds[sessionId]?.contains(jobId) ?? false) return;

      final next = {
        for (final entry in _dismissedMediaJobIds.entries)
          entry.key: Set<String>.of(entry.value),
      };
      next.putIfAbsent(sessionId, () => <String>{}).add(jobId);
      await _storage.setString(
        _dismissedMediaJobsStorageKey,
        _encodeDismissedMediaJobs(next),
      );
      if (_disposed) return;
      _dismissedMediaJobIds = next;
      notifyListeners();
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  /// Preserves the original offline demo once and starts Harness storage empty.
  static Future<void> prepareHarnessStorage(PreferencesStorage storage) async {
    if (storage.getString(backupStorageKey) == null) {
      await storage.setString(
        backupStorageKey,
        storage.getString(storageKey) ??
            _encodeSnapshot(DemoFixtures.sessions(), DemoFixtures.assets()),
      );
    }
    if (storage.getString(harnessStorageKey) == null) {
      await storage.setString(harnessStorageKey, _encodeSnapshot([], []));
    }
  }

  void restore() {
    _restoreDismissedMediaJobs();
    final raw = _storage.getString(_storageKey);
    if (raw == null) return;
    try {
      final decoded = _decodeSnapshot(raw);
      _sessions = decoded.sessions;
      _assets = isHarness
          ? decoded.assets
                .map(_restoreHarnessAsset)
                .whereType<DemoAsset>()
                .toList()
          : decoded.assets;
    } catch (_) {
      _sessions = isHarness ? [] : DemoFixtures.sessions();
      _assets = isHarness ? [] : DemoFixtures.assets();
    }
  }

  Future<void> refreshSessions() async {
    final api = _api;
    if (api == null || _loading) return;
    _loading = true;
    notifyListeners();
    try {
      final records = <Map<String, Object?>>[];
      var page = 1;
      var pageCount = 1;
      do {
        final response = await api.sessionsPage(
          page: page,
          pageSize: 100,
          archived: false,
        );
        records.addAll(_mapList(response['list']));
        final pageInfo = _map(response['pageInfo']);
        pageCount = _int(pageInfo['pageCount'], fallback: 1);
        page += 1;
      } while (page <= pageCount);

      final previous = {for (final session in _sessions) session.id: session};
      final snapshots = await Future.wait(
        records.map((record) async {
          final id = record['id']?.toString() ?? '';
          final listed = _sessionFromRecord(record, fallback: previous[id]);
          return _loadSnapshot(id, fallback: listed, migrateLegacy: true);
        }),
      );
      await _applySessionListSnapshots(snapshots);
      try {
        await refreshAssets();
      } catch (_) {
        // Session refresh still succeeds if an older Harness has no global
        // asset listing yet. A later library refresh will reconcile it.
      }
      for (final snapshot in snapshots) {
        if (snapshot.hasPendingMediaJobs) {
          _startMediaWatcher(snapshot.session.id);
        }
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshSession(String id) async {
    if (_api == null || _loadingSessions.contains(id)) return;
    _loadingSessions.add(id);
    notifyListeners();
    try {
      final snapshot = await _loadSnapshot(
        id,
        fallback: session(id),
        migrateLegacy: true,
      );
      await _applySnapshot(snapshot);
      if (!snapshot.hasPendingQuestions) _wakeQuestionWaiter(id);
      if (snapshot.hasPendingMediaJobs) _startMediaWatcher(id);
    } finally {
      _loadingSessions.remove(id);
      notifyListeners();
    }
  }

  /// Reconciles sessionless uploads from the global owned-asset listing.
  Future<void> refreshAssets() async {
    final api = _api;
    if (api == null) return;
    final requestOrder = ++_assetListRequestSerial;
    final response = await api.assets();
    final listed = _mapList(response['list']).map(_assetFromRecord).toList();
    final sessionless = listed
        .where((asset) => asset.sessionId == null || asset.sessionId!.isEmpty)
        .toList();
    await _commit(() {
      if (requestOrder < _latestAppliedAssetListRequest) {
        return (sessions: _sessions, assets: _assets);
      }
      _latestAppliedAssetListRequest = requestOrder;
      return (
        sessions: _sessions,
        assets: _mergeGlobalUploads(_assets, [
          ...sessionless,
          ..._uploadedFiles.values.where(
            (asset) => asset.sessionId == null || asset.sessionId!.isEmpty,
          ),
        ]),
      );
    });
  }

  /// Uploads a locally selected file to the Harness owned-asset library.
  Future<DemoAsset> uploadFile(DemoUploadFile file) async {
    final api = _api;
    if (api == null) {
      throw StateError('File upload is available only in Harness mode');
    }

    var asset = _uploadedFiles[file.clientRequestId];
    if (asset == null) {
      final bytes = await file.readBytes();
      final response = await api.uploadAsset(
        clientRequestId: file.clientRequestId,
        name: file.name,
        mimeType: file.mimeType,
        bytes: bytes,
      );
      asset = _assetFromRecord(_map(response['asset']));
      _uploadedFiles[file.clientRequestId] = asset;
    }

    final uploaded = asset;
    await _commit(
      () => (
        sessions: _sessions,
        assets: [uploaded, ..._assets.where((item) => item.id != uploaded.id)],
      ),
    );
    return uploaded;
  }

  Future<Uint8List> readAssetBytes(DemoAsset asset) async {
    final api = _api;
    if (api == null || !asset.isRemote) {
      throw StateError('Only Harness owned assets can be read remotely');
    }
    DemoUploadFile.validateMetadata(
      name: asset.title.isEmpty ? asset.id : asset.title,
      mimeType: asset.mimeType,
      sizeBytes: asset.sizeBytes,
      kind: asset.kind,
    );
    final bytes = await api.readAssetBytes(asset.contentUrl);
    DemoUploadFile.validateBytes(
      bytes,
      expectedSizeBytes: asset.sizeBytes,
      mimeType: asset.mimeType,
      kind: asset.kind,
    );
    return bytes;
  }

  Future<String> readAssetText(DemoAsset asset) async {
    if (asset.kind != DemoAssetKind.script) {
      throw const DemoUploadException('UNSUPPORTED_TYPE');
    }
    final bytes = await readAssetBytes(asset);
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw const DemoUploadException('INVALID_CONTENT');
    }
  }

  /// Resumes UI observation of a run that outlived a browser refresh.
  Future<void> resumeHarnessSession(String id) async {
    if (_api == null || _loadingSessions.contains(id)) return;
    _loadingSessions.add(id);
    notifyListeners();
    try {
      String? observedRunId;
      var attempt = 0;
      while (!_disposed) {
        final snapshot = await _loadSnapshot(
          id,
          fallback: session(id),
          migrateLegacy: true,
        );
        final questionWaiter = snapshot.hasPendingQuestionForRun(observedRunId)
            ? _questionWaiter(id)
            : null;
        await _applySnapshot(snapshot);
        Map<String, Object?>? observedRun;
        if (observedRunId == null) {
          final activeRuns = snapshot.runs.where((run) {
            final state = run['state'];
            return state == 'queued' ||
                state == 'running' ||
                state == 'waiting_user' ||
                state == 'stopping' ||
                state == 'cancel_requested';
          });
          observedRun = activeRuns.firstOrNull;
          observedRunId = observedRun?['id']?.toString();
          if (observedRunId == null) {
            if (snapshot.hasPendingMediaJobs) _startMediaWatcher(id);
            return;
          }
          _runningSessions.add(id);
          notifyListeners();
        } else {
          observedRun = snapshot.runs
              .where((run) => run['id']?.toString() == observedRunId)
              .firstOrNull;
        }
        final state = observedRun?['state']?.toString();
        final pendingQuestion = snapshot.hasPendingQuestionForRun(
          observedRunId,
        );
        if (pendingQuestion) {
          await Future.any<void>([
            questionWaiter!.future,
            Future<void>.delayed(_questionPollInterval),
          ]);
          continue;
        }
        _wakeQuestionWaiter(id);
        if (state == null || state == 'completed') {
          if (snapshot.hasPendingMediaJobs) _startMediaWatcher(id);
          _stopRequestedSessions.remove(id);
          return;
        }
        if (state == 'stopped') {
          _stopRequestedSessions.remove(id);
          return;
        }
        if (state == 'failed' || state == 'interrupted') {
          if (_stopRequestedSessions.remove(id)) return;
          final error = _map(observedRun?['error']);
          throw HarnessRunTerminalException(
            error['message']?.toString() ?? 'Agent run $state',
          );
        }
        if (attempt == _maxPollAttempts) break;
        attempt += 1;
        await Future<void>.delayed(_pollInterval);
      }
      if (_disposed) return;
      throw TimeoutException('Agent run did not finish in time');
    } finally {
      _runningSessions.remove(id);
      _loadingSessions.remove(id);
      notifyListeners();
    }
  }

  Future<String> createSession(
    String title,
    DemoSessionKind kind, {
    List<String>? members,
    DemoAssistantProfile? assistant,
  }) async {
    final selectedMembers = List<String>.unmodifiable(
      members ?? [assistant?.memberId ?? 'popi'],
    );
    if (selectedMembers.isEmpty ||
        selectedMembers.length > 5 ||
        selectedMembers.toSet().length != selectedMembers.length ||
        selectedMembers.any(
          (id) => !DemoFixtures.memberImages.containsKey(id),
        )) {
      throw ArgumentError.value(members, 'members', 'Choose one to five Bots');
    }
    if (assistant != null &&
        (selectedMembers.length != 1 ||
            selectedMembers.single != assistant.memberId ||
            assistant.name.trim().runes.length > 120 ||
            assistant.instructions.trim().length > 12000 ||
            (assistant.avatarAsset.isNotEmpty &&
                BotAvatarCharacter.fromStillAsset(assistant.avatarAsset) ==
                    null) ||
            (assistant.avatarColor != null &&
                (assistant.avatarColor! < 0 ||
                    assistant.avatarColor! > 0xFFFFFFFF)))) {
      throw ArgumentError.value(
        assistant,
        'assistant',
        'Invalid assistant profile',
      );
    }
    final memberNames = <String, String>{
      if (assistant != null && assistant.name.trim().isNotEmpty)
        assistant.memberId: assistant.name.trim(),
    };
    final memberInstructions = <String, String>{
      if (assistant != null && assistant.instructions.trim().isNotEmpty)
        assistant.memberId: assistant.instructions.trim(),
    };
    final memberAvatars = <String, String>{
      if (assistant != null && assistant.avatarAsset.isNotEmpty)
        assistant.memberId: assistant.avatarAsset,
    };
    final memberColors = <String, int>{
      if (assistant?.avatarColor case final color?) assistant!.memberId: color,
    };
    final api = _api;
    if (api == null) {
      final id = const Uuid().v4();
      await _commit(
        () => (
          sessions: [
            DemoSession(
              id: id,
              title: title.trim(),
              kind: kind,
              members: selectedMembers,
              roles: const [],
              messages: const [],
              activeMemberId: selectedMembers.first,
              memberNames: memberNames,
              memberInstructions: memberInstructions,
              memberAvatars: memberAvatars,
              memberColors: memberColors,
              configRevision: 1,
              configurationStatus: 'configured',
            ),
            ..._sessions,
          ],
          assets: _assets,
        ),
      );
      return id;
    }

    final draft = DemoSession(
      id: '',
      title: title.trim(),
      kind: kind,
      members: selectedMembers,
      roles: const [],
      messages: const [],
      activeMemberId: selectedMembers.first,
      memberNames: memberNames,
      memberInstructions: memberInstructions,
      memberAvatars: memberAvatars,
      memberColors: memberColors,
      configRevision: 1,
      configurationStatus: 'configured',
    );
    final requestKey =
        'create:${jsonEncode({'kind': kind.name, 'title': title.trim(), 'configuration': _configurationJson(draft)})}';
    final record = await api.createHarnessSession(
      clientRequestId: _requestId(requestKey),
      title: title.trim(),
      kind: kind.name,
      configuration: _configurationJson(draft),
    );
    final created =
        _sessionFromRecord(
          Map<String, Object?>.from(record),
          fallback: draft,
          fallbackKind: kind,
        ).copyWith(
          configRevision: _int(record['configRevision'], fallback: 1),
          configurationStatus:
              record['configurationStatus']?.toString() ?? 'configured',
        );
    await _replace(sessions: [created, ..._sessions], assets: _assets);
    _requestIds.remove(requestKey);
    return created.id;
  }

  Future<void> updateSession(
    String id,
    DemoSession Function(DemoSession) update,
  ) async {
    if (_api == null) {
      return _commit(
        () => (
          sessions: _sessions
              .map((session) => session.id == id ? update(session) : session)
              .toList(),
          assets: _assets,
        ),
      );
    }
    final current = session(id);
    final next = update(current);
    final api = _api;
    final currentConfiguration = _configurationJson(current);
    final nextConfiguration = _configurationJson(next);
    final configurationChanged =
        jsonEncode(currentConfiguration) != jsonEncode(nextConfiguration);
    final titleChanged = current.title != next.title;
    final pinnedChanged = current.pinned != next.pinned;
    if (titleChanged || pinnedChanged || configurationChanged) {
      final requestKey =
          'update:$id:${current.configRevision}:${next.title}:${next.pinned}:${jsonEncode(nextConfiguration)}';
      try {
        final record = await api.updateSession(
          id,
          clientRequestId: _requestId(requestKey),
          title: titleChanged ? next.title : null,
          pinned: pinnedChanged ? next.pinned : null,
          configuration: configurationChanged ? nextConfiguration : null,
          expectedConfigRevision: configurationChanged
              ? current.configRevision
              : null,
        );
        _requestIds.remove(requestKey);
        final saved = _sessionFromRecord(
          Map<String, Object?>.from(record),
          fallback: next,
        );
        await _commit(() {
          final latest = _sessions
              .where((session) => session.id == id)
              .firstOrNull;
          final merged = latest == null
              ? saved
              : _mergeUpdateResponse(latest, saved);
          return (
            sessions: _sessions
                .map((session) => session.id == id ? merged : session)
                .toList(),
            assets: _assets,
          );
        });
        return;
      } on AgentApiException catch (error) {
        if (error.code == 'config_conflict') {
          _requestIds.remove(requestKey);
          final authoritative = await _loadSnapshot(
            id,
            fallback: current,
            migrateLegacy: false,
          );
          await _applySnapshot(authoritative);
        }
        rethrow;
      }
    }
    await _commit(
      () => (
        sessions: _sessions.map((s) => s.id == id ? next : s).toList(),
        assets: _assets,
      ),
    );
  }

  Future<void> deleteSession(String id) async {
    final api = _api;
    if (api != null) {
      final requestKey = 'archive:$id';
      await api.archiveSession(id, clientRequestId: _requestId(requestKey));
      _requestIds.remove(requestKey);
    }
    await _commit(
      () => (
        sessions: _sessions.where((s) => s.id != id).toList(),
        assets: _assets,
      ),
    );
  }

  Future<void> addMessage(String sessionId, DemoMessage message) {
    if (isHarness) {
      throw StateError('Harness messages must be sent through the Agent API');
    }
    return updateSession(
      sessionId,
      (s) =>
          s.copyWith(messages: [...s.messages, message], unread: 0, time: ''),
    );
  }

  Future<void> sendHarnessMessage(
    String sessionId, {
    required String clientRequestId,
    required String text,
    List<String> mediaIds = const [],
    List<String> contextRoleIds = const [],
    VoidCallback? onAccepted,
  }) async {
    final api = _api;
    if (api == null) throw StateError('Harness transport is not configured');
    final selectedRoles = session(sessionId).roles;
    if (contextRoleIds.length > 5 ||
        contextRoleIds.toSet().length != contextRoleIds.length ||
        contextRoleIds.any((id) => !selectedRoles.contains(id))) {
      throw ArgumentError.value(contextRoleIds, 'contextRoleIds');
    }
    final accepted = await api.sendSessionMessage(
      sessionId,
      clientRequestId: clientRequestId,
      text: text,
      mediaIds: mediaIds.isEmpty ? null : mediaIds,
      contextRoleIds: contextRoleIds.isEmpty ? null : contextRoleIds,
    );
    final runId = accepted['runId']?.toString();
    // A newly accepted run starts a new stop-idempotency lifecycle. Keep an
    // uncertain stop key reusable within one run, but never replay it later.
    _requestIds.remove('stop:$sessionId');
    var state = accepted['state']?.toString() ?? 'queued';
    _runningSessions.add(sessionId);
    notifyListeners();
    onAccepted?.call();
    var handedOffQuestionRun = false;
    try {
      var attempt = 0;
      while (!_disposed) {
        final snapshot = await _loadSnapshot(
          sessionId,
          fallback: session(sessionId),
          migrateLegacy: true,
        );
        await _applySnapshot(snapshot);
        final matchingRuns = snapshot.runs.where((item) => item['id'] == runId);
        final run = matchingRuns.firstOrNull;
        state = run?['state']?.toString() ?? state;
        if (snapshot.hasPendingQuestionForRun(runId)) {
          handedOffQuestionRun = true;
          _startQuestionRunWatcher(sessionId);
          return;
        }
        if (state == 'completed') {
          if (snapshot.hasPendingMediaJobs) _startMediaWatcher(sessionId);
          _stopRequestedSessions.remove(sessionId);
          return;
        }
        if (state == 'stopped') {
          _stopRequestedSessions.remove(sessionId);
          throw const HarnessRunStoppedException();
        }
        if (state == 'failed' || state == 'interrupted') {
          if (_stopRequestedSessions.remove(sessionId)) {
            throw const HarnessRunStoppedException();
          }
          final error = _map(run?['error']);
          throw HarnessRunTerminalException(
            error['message']?.toString() ?? 'Agent run $state',
          );
        }
        if (attempt == _maxPollAttempts) break;
        attempt += 1;
        await Future<void>.delayed(_pollInterval);
      }
      if (_disposed) return;
      throw TimeoutException('Agent run did not finish in time');
    } finally {
      if (!handedOffQuestionRun) _runningSessions.remove(sessionId);
      notifyListeners();
    }
  }

  Future<void> respondHarnessQuestion(
    String sessionId, {
    required String questionId,
    required int revision,
    required String action,
    required Map<String, Object?> answer,
  }) {
    final operationKey = '$sessionId:$questionId:$revision';
    final question = _pendingQuestion(
      sessionId,
      questionId: questionId,
      revision: revision,
    );
    final normalized = _normalizeQuestionAnswer(question, action, answer);
    final payloadSignature = jsonEncode({
      'action': action,
      if (action == 'submit') 'answer': normalized,
    });
    final pending = _questionResponses[operationKey];
    if (pending != null) {
      if (pending.payloadSignature == payloadSignature) {
        return pending.operation;
      }
      throw StateError('A different question response is already in progress');
    }
    final operation = _performQuestionResponse(
      sessionId,
      questionId: questionId,
      revision: revision,
      action: action,
      normalizedAnswer: normalized,
    );
    _questionResponses[operationKey] = (
      payloadSignature: payloadSignature,
      operation: operation,
    );
    unawaited(
      operation.then(
        (_) {
          if (identical(
            _questionResponses[operationKey]?.operation,
            operation,
          )) {
            _questionResponses.remove(operationKey);
          }
        },
        onError: (Object _, StackTrace __) {
          if (identical(
            _questionResponses[operationKey]?.operation,
            operation,
          )) {
            _questionResponses.remove(operationKey);
          }
        },
      ),
    );
    return operation;
  }

  Future<void> _performQuestionResponse(
    String sessionId, {
    required String questionId,
    required int revision,
    required String action,
    required Map<String, Object?> normalizedAnswer,
  }) async {
    final api = _api;
    if (api == null) throw StateError('Harness transport is not configured');
    final requestKey =
        'question:$sessionId:$questionId:$revision:$action:${jsonEncode(normalizedAnswer)}';
    await api.respondQuestion(
      sessionId,
      questionId,
      clientRequestId: _requestId(requestKey),
      revision: revision,
      action: action,
      answer: action == 'submit' ? normalizedAnswer : null,
    );
    _wakeQuestionWaiter(sessionId);
    await refreshSession(sessionId);
    _requestIds.remove(requestKey);
    if (!_disposed && !isSessionRunning(sessionId)) {
      _startQuestionRunWatcher(sessionId);
    }
  }

  DemoQuestion _pendingQuestion(
    String sessionId, {
    required String questionId,
    required int revision,
  }) {
    final question = session(sessionId).messages
        .map((message) => message.question)
        .whereType<DemoQuestion>()
        .where((item) => item.id == questionId)
        .firstOrNull;
    if (question == null || question.revision != revision) {
      throw StateError('Question changed; refresh before responding');
    }
    if (!question.isPending) {
      throw StateError('Question is no longer pending');
    }
    return question;
  }

  Map<String, Object?> _normalizeQuestionAnswer(
    DemoQuestion question,
    String action,
    Map<String, Object?> answer,
  ) {
    if (action == 'cancel') return const {};
    if (action != 'submit') {
      throw ArgumentError.value(
        action,
        'action',
        'Unsupported question action',
      );
    }
    final fieldIds = question.questions.map((field) => field.id).toSet();
    if (answer.keys.any((id) => !fieldIds.contains(id))) {
      throw ArgumentError.value(answer, 'answer', 'Unknown question field');
    }
    final normalized = <String, Object?>{};
    for (final field in question.questions) {
      final value = answer[field.id];
      final values = switch (value) {
        String text => [text.trim()],
        List items => items.map((item) => item.toString().trim()).toList(),
        _ => const <String>[],
      }.where((item) => item.isNotEmpty).toSet().toList();
      if (values.isEmpty || (!field.multiSelect && values.length != 1)) {
        throw ArgumentError.value(
          value,
          field.id,
          field.multiSelect
              ? 'Choose at least one answer'
              : 'Choose one answer',
        );
      }
      normalized[field.id] = field.multiSelect ? values : values.single;
    }
    return normalized;
  }

  Future<void> stopHarnessSession(String sessionId) async {
    final api = _api;
    if (api == null) return;
    final requestKey = 'stop:$sessionId';
    _stopRequestedSessions.add(sessionId);
    try {
      await api.stopSession(sessionId, clientRequestId: _requestId(requestKey));
      _requestIds.remove(requestKey);
      _wakeQuestionWaiter(sessionId);
      await refreshSession(sessionId);
    } catch (_) {
      _stopRequestedSessions.remove(sessionId);
      rethrow;
    }
  }

  /// Deterministic local results remain available only to the offline demo.
  Future<void> reply(
    String sessionId,
    String prompt, {
    required String text,
    required String imageText,
    required String scriptText,
    required String audioText,
    required String videoText,
  }) async {
    if (isHarness) {
      throw StateError('Harness replies come from the Agent snapshot');
    }
    final currentSession = session(sessionId);
    final memberId =
        currentSession.members.contains(currentSession.activeMemberId)
        ? currentSession.activeMemberId
        : currentSession.members.firstOrNull ?? 'popi';
    final lower = prompt.toLowerCase();
    final kind = RegExp(r'视频|成片|video').hasMatch(lower)
        ? DemoAssetKind.video
        : RegExp(r'音乐|音频|配音|audio|music').hasMatch(lower)
        ? DemoAssetKind.audio
        : RegExp(r'脚本|分镜|script').hasMatch(lower)
        ? DemoAssetKind.script
        : RegExp(r'图|场景|image|picture').hasMatch(lower)
        ? DemoAssetKind.image
        : null;
    final batch = RegExp(r'批量|五|5|batch').hasMatch(lower);
    final sources = kind == null
        ? <DemoAsset>[]
        : DemoFixtures.assets().where((a) => a.kind == kind).toList();
    final selected = kind == DemoAssetKind.image && batch
        ? sources.where((a) => a.id.startsWith('scene')).toList()
        : sources.take(1).toList();
    final generated = selected
        .map(
          (a) => DemoAsset(
            id: const Uuid().v4(),
            title: a.title,
            kind: a.kind,
            cover: a.cover,
            body: a.body,
            media: a.media,
            sessionId: sessionId,
            memberId: memberId,
            configRevision: currentSession.configRevision,
          ),
        )
        .toList();
    final replyText = switch (kind) {
      DemoAssetKind.image => imageText,
      DemoAssetKind.video => videoText,
      DemoAssetKind.script => scriptText,
      DemoAssetKind.audio => audioText,
      null => text,
    };
    await _commit(
      () => (
        sessions: _sessions
            .map(
              (s) => s.id == sessionId
                  ? s.copyWith(
                      messages: [
                        ...s.messages,
                        DemoMessage(
                          id: const Uuid().v4(),
                          text: replyText,
                          assetIds: generated.map((a) => a.id).toList(),
                          memberId: memberId,
                          memberName:
                              currentSession.memberNames[memberId] ?? '',
                          configRevision: currentSession.configRevision,
                        ),
                      ],
                    )
                  : s,
            )
            .toList(),
        assets: [...generated, ..._assets],
      ),
    );
  }

  Future<void> renameAsset(String id, String title) {
    _requireOfflineAssets();
    return _commit(
      () => (
        sessions: _sessions,
        assets: _assets
            .map((a) => a.id == id ? a.copyWith(title: title.trim()) : a)
            .toList(),
      ),
    );
  }

  Future<void> deleteAsset(String id) {
    _requireOfflineAssets();
    return _commit(
      () => (
        sessions: _sessions,
        assets: _assets.where((a) => a.id != id).toList(),
      ),
    );
  }

  Future<void> importSample(DemoAssetKind kind) => importSamples([kind]);

  /// Publishes the selected offline samples in one durable snapshot.
  Future<void> importSamples(List<DemoAssetKind> kinds) {
    _requireOfflineAssets();
    final selected = List<DemoAssetKind>.unmodifiable(kinds);
    if (selected.isEmpty) return Future.value();
    return _commit(() {
      final fixtures = DemoFixtures.assets();
      final imported = [
        for (final kind in selected)
          for (final asset in [
            fixtures.firstWhere((asset) => asset.kind == kind),
          ])
            DemoAsset(
              id: const Uuid().v4(),
              title: asset.title,
              kind: kind,
              cover: asset.cover,
              body: asset.body,
              media: asset.media,
            ),
      ];
      return (sessions: _sessions, assets: [...imported, ..._assets]);
    });
  }

  Future<void> reset() async {
    if (!isHarness) {
      await _commit(
        () =>
            (sessions: DemoFixtures.sessions(), assets: DemoFixtures.assets()),
      );
      await _clearDismissedMediaJobs();
      return;
    }
    for (final current in List<DemoSession>.of(_sessions)) {
      await deleteSession(current.id);
    }
    await _clearDismissedMediaJobs();
  }

  void _requireOfflineAssets() {
    if (isHarness) {
      throw UnsupportedError('Harness media upload is not connected yet');
    }
  }

  String _requestId(String key) =>
      _requestIds.putIfAbsent(key, () => const Uuid().v4());

  Completer<void> _questionWaiter(String sessionId) =>
      _questionWaiters.putIfAbsent(sessionId, Completer<void>.new);

  void _wakeQuestionWaiter(String sessionId) {
    final waiter = _questionWaiters.remove(sessionId);
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  void _startQuestionRunWatcher(String sessionId) {
    if (_disposed || _questionRunWatchers.containsKey(sessionId)) return;
    final watcher = _observeQuestionRun(sessionId);
    _questionRunWatchers[sessionId] = watcher;
    unawaited(
      watcher.whenComplete(() {
        if (identical(_questionRunWatchers[sessionId], watcher)) {
          _questionRunWatchers.remove(sessionId);
        }
      }),
    );
  }

  Future<void> _observeQuestionRun(String sessionId) async {
    try {
      await resumeHarnessSession(sessionId);
    } catch (_) {
      // Snapshot refresh or reopening the chat can resume this observation.
    }
  }

  void _startMediaWatcher(String sessionId) {
    if (_disposed || _mediaWatchers.containsKey(sessionId)) return;
    final watcher = _observeMediaJobs(sessionId);
    _mediaWatchers[sessionId] = watcher;
    unawaited(
      watcher.whenComplete(() {
        if (identical(_mediaWatchers[sessionId], watcher)) {
          _mediaWatchers.remove(sessionId);
        }
      }),
    );
  }

  Future<void> _observeMediaJobs(String sessionId) async {
    try {
      for (var attempt = 0; attempt <= _maxPollAttempts; attempt++) {
        if (_disposed) return;
        final fallback = _sessions
            .where((item) => item.id == sessionId)
            .firstOrNull;
        if (fallback == null) return;
        final snapshot = await _loadSnapshot(
          sessionId,
          fallback: fallback,
          migrateLegacy: true,
        );
        if (_disposed) return;
        await _applySnapshot(snapshot);
        if (!snapshot.hasPendingMediaJobs) return;
        if (attempt == _maxPollAttempts) return;
        await Future<void>.delayed(_pollInterval);
      }
    } catch (_) {
      // Background observation is best effort. Server workers own generation;
      // an explicit refresh can resume observation without replaying a POST.
    }
  }

  Future<_HarnessSnapshot> _loadSnapshot(
    String id, {
    DemoSession? fallback,
    bool migrateLegacy = false,
  }) async {
    final requestOrder = ++_snapshotRequestSerial;
    final response = await _api!.sessionSnapshot(id);
    final messages = _mapList(
      response['messages'],
    ).map(_messageFromRecord).toList();
    var nextSession = _sessionFromRecord(
      _map(response['session']),
      fallback: fallback,
      messages: messages,
      mediaJobs: _mapList(
        response['mediaJobs'],
      ).map(DemoMediaJob.fromJson).toList(),
      lastSeq: _int(response['lastSeq'], fallback: fallback?.lastSeq ?? 0),
    );
    if (migrateLegacy &&
        fallback != null &&
        nextSession.configurationStatus == 'legacy') {
      nextSession = await _migrateLegacyConfiguration(nextSession, fallback);
    }
    final hasAssets = response.containsKey('assets');
    final assets = hasAssets
        ? _mapList(response['assets']).map(_assetFromRecord).toList()
        : const <DemoAsset>[];
    return _HarnessSnapshot(
      session: nextSession,
      runs: _mapList(response['runs']),
      assets: assets,
      assetsAuthoritative: hasAssets,
      requestOrder: requestOrder,
    );
  }

  Future<void> _applySnapshot(_HarnessSnapshot snapshot) {
    if (_disposed) return Future.value();
    return _commit(() {
      final current = _sessions
          .where((item) => item.id == snapshot.session.id)
          .firstOrNull;
      if (!_acceptSnapshot(snapshot, current)) {
        return (sessions: _sessions, assets: _assets);
      }
      _latestAppliedSnapshotRequest[snapshot.session.id] =
          snapshot.requestOrder;
      return (
        sessions: _sessions
            .map(
              (item) =>
                  item.id == snapshot.session.id ? snapshot.session : item,
            )
            .toList(),
        assets: _mergeSnapshotAssets(_assets, [snapshot]),
      );
    });
  }

  Future<void> _applySessionListSnapshots(List<_HarnessSnapshot> snapshots) {
    if (_disposed) return Future.value();
    return _commit(() {
      final currentById = {for (final item in _sessions) item.id: item};
      final accepted = <_HarnessSnapshot>[];
      final sessions = <DemoSession>[];
      for (final snapshot in snapshots) {
        final current = currentById[snapshot.session.id];
        if (_acceptSnapshot(snapshot, current)) {
          accepted.add(snapshot);
          sessions.add(snapshot.session);
          _latestAppliedSnapshotRequest[snapshot.session.id] =
              snapshot.requestOrder;
        } else if (current != null) {
          sessions.add(current);
        }
      }
      return (
        sessions: sessions,
        assets: _mergeSnapshotAssets(_assets, accepted),
      );
    });
  }

  bool _acceptSnapshot(_HarnessSnapshot snapshot, DemoSession? current) {
    final latestRequest =
        _latestAppliedSnapshotRequest[snapshot.session.id] ?? 0;
    if (snapshot.requestOrder < latestRequest) return false;
    if (current == null) return true;
    final next = snapshot.session;
    if (next.serverRevision < current.serverRevision ||
        next.configRevision < current.configRevision ||
        next.lastSeq < current.lastSeq) {
      return false;
    }
    return true;
  }

  DemoSession _mergeUpdateResponse(DemoSession current, DemoSession response) {
    if (response.serverRevision < current.serverRevision ||
        response.configRevision < current.configRevision) {
      return current;
    }
    if (response.lastSeq <= current.lastSeq) {
      return response.copyWith(
        messages: current.messages,
        mediaJobs: current.mediaJobs,
        lastSeq: current.lastSeq,
      );
    }
    return response;
  }

  Future<DemoSession> _migrateLegacyConfiguration(
    DemoSession server,
    DemoSession fallback,
  ) async {
    final migrated = server.copyWith(
      members: fallback.members,
      roles: fallback.roles,
      direction: fallback.direction,
      positioning: fallback.positioning,
      accountPreferences: fallback.accountPreferences,
      capabilities: fallback.capabilities,
      memberNames: fallback.memberNames,
      memberInstructions: fallback.memberInstructions,
      memberAvatars: fallback.memberAvatars,
      memberColors: fallback.memberColors,
      memberCapabilities: fallback.memberCapabilities,
      workMode: fallback.workMode,
      activeMemberId: fallback.members.contains(fallback.activeMemberId)
          ? fallback.activeMemberId
          : fallback.members.first,
      roleProfiles: fallback.roleProfiles,
    );
    final requestKey = 'migrate:${server.id}:${server.configRevision}';
    try {
      final response = await _api!.updateSession(
        server.id,
        clientRequestId: _requestId(requestKey),
        pinned: fallback.pinned,
        configuration: _configurationJson(migrated),
        expectedConfigRevision: server.configRevision,
      );
      _requestIds.remove(requestKey);
      return _sessionFromRecord(
        Map<String, Object?>.from(response),
        fallback: migrated,
      ).copyWith(
        configRevision: _int(
          response['configRevision'],
          fallback: server.configRevision + 1,
        ),
        configurationStatus:
            response['configurationStatus']?.toString() ?? 'configured',
      );
    } on AgentApiException catch (error) {
      if (error.code != 'config_conflict') rethrow;
      _requestIds.remove(requestKey);
      final response = await _api!.sessionSnapshot(server.id);
      return _sessionFromRecord(
        _map(response['session']),
        fallback: server,
        messages: _mapList(
          response['messages'],
        ).map(_messageFromRecord).toList(),
        mediaJobs: _mapList(
          response['mediaJobs'],
        ).map(DemoMediaJob.fromJson).toList(),
        lastSeq: _int(response['lastSeq'], fallback: server.lastSeq),
      );
    }
  }

  DemoMessage _messageFromRecord(Map<String, Object?> message) => DemoMessage(
    id: message['id']?.toString() ?? '',
    text: message['text']?.toString() ?? '',
    user: message['role'] == 'user',
    assetIds: _stringList(message['assetIds'] ?? message['assets']),
    status: message['status']?.toString(),
    memberId: message['memberId']?.toString() ?? '',
    memberName: message['memberName']?.toString() ?? '',
    runId: message['runId']?.toString() ?? '',
    configRevision: _int(message['configRevision'], fallback: 0),
    question: message['question'] is Map
        ? DemoQuestion.fromJson(_map(message['question']))
        : null,
  );

  DemoSession _sessionFromRecord(
    Map<String, Object?> record, {
    DemoSession? fallback,
    DemoSessionKind? fallbackKind,
    List<DemoMessage>? messages,
    List<DemoMediaJob>? mediaJobs,
    int? lastSeq,
  }) {
    final kindName = record['kind']?.toString();
    final matchingKinds = DemoSessionKind.values.where(
      (candidate) => candidate.name == kindName,
    );
    final kind = matchingKinds.firstOrNull;
    final configuration = _map(record['configuration']);
    final configurationStatus = record['configurationStatus']?.toString();
    final configured = configurationStatus == 'configured';
    if (configured && configuration.isEmpty) {
      throw const FormatException(
        'Configured Agent session is missing its configuration',
      );
    }
    final members = configured
        ? _stringList(configuration['members'])
        : fallback?.members ?? const ['popi'];
    final roles = configured
        ? _stringList(configuration['roles'])
        : fallback?.roles ?? const [];
    return DemoSession(
      id: record['id']?.toString() ?? fallback?.id ?? '',
      title: record['title']?.toString() ?? fallback?.title ?? '新会话',
      kind:
          kind ??
          fallback?.kind ??
          fallbackKind ??
          DemoSessionKind.conversation,
      members: members,
      roles: roles,
      messages: messages ?? fallback?.messages ?? const [],
      unread: 0,
      time: '',
      direction: configured
          ? configuration['direction']?.toString() ?? ''
          : fallback?.direction ?? '',
      positioning: configured
          ? configuration['positioning']?.toString() ?? ''
          : fallback?.positioning ?? '',
      accountPreferences: configured
          ? _stringMap(configuration['accountPreferences'])
          : fallback?.accountPreferences ?? const {},
      capabilities: configured
          ? _stringList(configuration['capabilities'])
          : fallback?.capabilities ?? DemoSession.defaultCapabilities,
      memberNames: configured
          ? _stringMap(configuration['memberNames'])
          : fallback?.memberNames ?? const {},
      memberInstructions: configured
          ? _stringMap(configuration['memberInstructions'])
          : fallback?.memberInstructions ?? const {},
      memberAvatars: configured
          ? _stringMap(configuration['memberAvatars'])
          : fallback?.memberAvatars ?? const {},
      memberColors: configured
          ? _colorMap(configuration['memberColors'])
          : fallback?.memberColors ?? const {},
      memberCapabilities: configured
          ? _stringListMap(configuration['memberCapabilities'])
          : fallback?.memberCapabilities ?? const {},
      workMode: configured
          ? configuration['workMode']?.toString() ?? 'onDemand'
          : fallback?.workMode ?? 'onDemand',
      activeMemberId: configured
          ? configuration['activeMemberId']?.toString() ?? members.first
          : fallback?.activeMemberId ?? members.first,
      roleProfiles: configured
          ? _roleProfileMap(configuration['roleProfiles'])
          : fallback?.roleProfiles ?? const {},
      configRevision: _int(
        record['configRevision'],
        fallback: fallback?.configRevision ?? 0,
      ),
      configurationStatus:
          configurationStatus ??
          (configured
              ? 'configured'
              : fallback?.configurationStatus ?? 'legacy'),
      serverRevision: _int(
        record['revision'],
        fallback: fallback?.serverRevision ?? 0,
      ),
      lastSeq: lastSeq ?? fallback?.lastSeq ?? 0,
      mediaJobs: mediaJobs ?? fallback?.mediaJobs ?? const [],
      pinned: record['pinned'] as bool? ?? fallback?.pinned ?? false,
    );
  }

  DemoAsset _assetFromRecord(Map<String, Object?> record) {
    final id = record['id']?.toString() ?? '';
    final kindName = record['kind']?.toString();
    if (id.isEmpty ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id) ||
        !DemoAssetKind.values.map((kind) => kind.name).contains(kindName)) {
      throw const FormatException('Invalid owned asset');
    }
    final kind = DemoAssetKind.values.byName(kindName!);
    final mimeType = record['mimeType']?.toString() ?? '';
    final sizeBytes = _int(record['sizeBytes'], fallback: 0);
    DemoUploadFile.validateMetadata(
      name: record['title']?.toString().isNotEmpty == true
          ? record['title']!.toString()
          : id,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      kind: kind,
    );
    final relative =
        record['contentUrl']?.toString() ??
        record['contentPath']?.toString() ??
        '';
    final contentUrl = _api!.resolveAssetContentUrl(relative);
    if (Uri.parse(contentUrl).path != '/api_agent/v2/assets/$id/content') {
      throw const FormatException('Owned asset content URL does not match');
    }
    final posterUrl = kind == DemoAssetKind.video
        ? _resolveAssetPosterUrl(record['posterUrl'], id)
        : '';
    return DemoAsset(
      id: id,
      title: record['title']?.toString() ?? '',
      kind: kind,
      cover: kind == DemoAssetKind.image ? contentUrl : '',
      media: kind == DemoAssetKind.video || kind == DemoAssetKind.audio
          ? contentUrl
          : '',
      contentUrl: contentUrl,
      posterUrl: posterUrl,
      sessionId: record['sessionId']?.toString(),
      jobId: record['jobId']?.toString() ?? '',
      runId: record['runId']?.toString() ?? '',
      memberId: record['memberId']?.toString() ?? '',
      configRevision: _int(record['configRevision'], fallback: 0),
      mimeType: mimeType,
      sha256: record['sha256']?.toString() ?? '',
      sizeBytes: sizeBytes,
      width: _int(record['width'], fallback: 0),
      height: _int(record['height'], fallback: 0),
      durationSeconds: _double(record['durationSeconds'], fallback: 0),
      hasAudio: record['hasAudio'] as bool? ?? false,
      createdAt: record['createdAt']?.toString() ?? '',
    );
  }

  DemoAsset? _restoreHarnessAsset(DemoAsset cached) {
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(cached.id) ||
        cached.title.isEmpty ||
        (cached.kind == DemoAssetKind.video &&
            cached.mimeType.isNotEmpty &&
            cached.mimeType != 'video/mp4')) {
      return null;
    }
    if (cached.mimeType.isNotEmpty && cached.sizeBytes > 0) {
      try {
        DemoUploadFile.validateMetadata(
          name: cached.title,
          mimeType: cached.mimeType,
          sizeBytes: cached.sizeBytes,
          kind: cached.kind,
        );
      } on DemoUploadException {
        return null;
      }
    } else if (cached.kind == DemoAssetKind.audio ||
        cached.kind == DemoAssetKind.script) {
      return null;
    }
    final contentUrl = _api!.resolveAssetContentUrl(
      '/api_agent/v2/assets/${cached.id}/content',
    );
    final posterUrl = _restoreAssetPosterUrl(cached.posterUrl, cached.id);
    return DemoAsset(
      id: cached.id,
      title: cached.title,
      kind: cached.kind,
      cover: cached.kind == DemoAssetKind.image ? contentUrl : '',
      sessionId: cached.sessionId,
      body: cached.body,
      media:
          cached.kind == DemoAssetKind.video ||
              cached.kind == DemoAssetKind.audio
          ? contentUrl
          : '',
      contentUrl: contentUrl,
      posterUrl: posterUrl,
      jobId: cached.jobId,
      runId: cached.runId,
      memberId: cached.memberId,
      configRevision: cached.configRevision,
      mimeType: cached.mimeType,
      sha256: cached.sha256,
      sizeBytes: cached.sizeBytes,
      width: cached.width,
      height: cached.height,
      durationSeconds: cached.durationSeconds,
      hasAudio: cached.hasAudio,
      createdAt: cached.createdAt,
    );
  }

  String _resolveAssetPosterUrl(Object? value, String assetId) {
    final relative = value?.toString() ?? '';
    if (relative.isEmpty) return '';
    try {
      final posterUrl = _api!.resolveAssetPosterUrl(relative);
      return Uri.parse(posterUrl).path == '/api_agent/v2/assets/$assetId/poster'
          ? posterUrl
          : '';
    } on FormatException {
      return '';
    }
  }

  String _restoreAssetPosterUrl(String cachedUrl, String assetId) {
    if (cachedUrl.isEmpty) return '';
    try {
      final expected = _api!.resolveAssetPosterUrl(
        '/api_agent/v2/assets/$assetId/poster',
      );
      return Uri.parse(cachedUrl) == Uri.parse(expected) ? expected : '';
    } on FormatException {
      return '';
    }
  }

  static Map<String, Object?> _configurationJson(DemoSession session) {
    final members = session.members.toSet();
    final roles = session.roles.toSet();
    final memberCapabilities = <String, List<String>>{
      for (final memberId in session.members)
        memberId: List<String>.from(session.capabilitiesFor(memberId)),
    };
    final capabilities = <String>{...session.capabilities};
    for (final selected in memberCapabilities.values) {
      capabilities.addAll(selected);
    }
    return {
      'members': session.members,
      'roles': session.roles,
      'capabilities': capabilities.toList(),
      'memberCapabilities': memberCapabilities,
      'memberNames': {
        for (final entry in session.memberNames.entries)
          if (members.contains(entry.key)) entry.key: entry.value,
      },
      'memberInstructions': {
        for (final entry in session.memberInstructions.entries)
          if (members.contains(entry.key)) entry.key: entry.value,
      },
      'memberAvatars': {
        for (final entry in session.memberAvatars.entries)
          if (members.contains(entry.key)) entry.key: entry.value,
      },
      'memberColors': {
        for (final entry in session.memberColors.entries)
          if (members.contains(entry.key)) entry.key: entry.value,
      },
      'workMode': session.workMode,
      'activeMemberId': members.contains(session.activeMemberId)
          ? session.activeMemberId
          : session.members.first,
      'direction': session.direction,
      'positioning': session.positioning,
      'accountPreferences': session.accountPreferences,
      'roleProfiles': {
        for (final entry in session.roleProfiles.entries)
          if (roles.contains(entry.key)) entry.key: entry.value.toJson(),
      },
    };
  }

  static List<DemoAsset> _mergeSnapshotAssets(
    List<DemoAsset> current,
    Iterable<_HarnessSnapshot> snapshots,
  ) {
    final authoritative = snapshots
        .where((snapshot) => snapshot.assetsAuthoritative)
        .toList();
    if (authoritative.isEmpty) return current;
    final sessionIds = authoritative
        .map((snapshot) => snapshot.session.id)
        .toSet();
    final incoming = authoritative.expand((snapshot) => snapshot.assets);
    final seen = <String>{};
    return [
      for (final asset in incoming)
        if (seen.add(asset.id)) asset,
      for (final asset in current)
        if (!sessionIds.contains(asset.sessionId) && seen.add(asset.id)) asset,
    ];
  }

  static List<DemoAsset> _mergeGlobalUploads(
    List<DemoAsset> current,
    List<DemoAsset> sessionless,
  ) {
    final seen = <String>{};
    return [
      for (final asset in sessionless)
        if (seen.add(asset.id)) asset,
      for (final asset in current)
        if (asset.sessionId != null &&
            asset.sessionId!.isNotEmpty &&
            seen.add(asset.id))
          asset,
    ];
  }

  Future<void> _replace({
    required List<DemoSession> sessions,
    required List<DemoAsset> assets,
  }) => _commit(() => (sessions: sessions, assets: assets));

  String get _dismissedMediaJobsStorageKey =>
      '${_storageKey}_dismissed_media_jobs_v1';

  DemoMediaJob? _mediaJob(String sessionId, String jobId) => _sessions
      .where((session) => session.id == sessionId)
      .expand((session) => session.mediaJobs)
      .where((job) => job.jobId == jobId)
      .firstOrNull;

  void _restoreDismissedMediaJobs() {
    final raw = _storage.getString(_dismissedMediaJobsStorageKey);
    if (raw == null) {
      _dismissedMediaJobIds = {};
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException();
      final restored = <String, Set<String>>{};
      for (final entry in decoded.entries) {
        if (entry.key is! String || entry.value is! List) continue;
        final jobs = {
          for (final value in entry.value as List)
            if (value is String && value.isNotEmpty) value,
        };
        if (jobs.isEmpty) continue;
        restored[entry.key as String] = jobs;
      }
      _dismissedMediaJobIds = restored;
    } catch (_) {
      _dismissedMediaJobIds = {};
    }
  }

  static String _encodeDismissedMediaJobs(Map<String, Set<String>> dismissed) =>
      jsonEncode({
        for (final entry in dismissed.entries) entry.key: entry.value.toList(),
      });

  Future<void> _clearDismissedMediaJobs() {
    final operation = _pending.then((_) async {
      if (_disposed) return;
      if (_storage.getString(_dismissedMediaJobsStorageKey) != null) {
        await _storage.remove(_dismissedMediaJobsStorageKey);
      }
      if (_disposed) return;
      final changed = _dismissedMediaJobIds.isNotEmpty;
      _dismissedMediaJobIds = {};
      if (changed) notifyListeners();
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _commit(
    ({List<DemoSession> sessions, List<DemoAsset> assets}) Function() change,
  ) {
    final operation = _pending.then((_) async {
      if (_disposed) return;
      final next = change();
      await _storage.setString(
        _storageKey,
        _encodeSnapshot(next.sessions, next.assets),
      );
      if (_disposed) return;
      _sessions = next.sessions;
      _assets = next.assets;
      notifyListeners();
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  static String _encodeSnapshot(
    List<DemoSession> sessions,
    List<DemoAsset> assets,
  ) => jsonEncode({
    'sessions': sessions.map((session) => session.toJson()).toList(),
    'assets': assets.map((asset) => asset.toJson()).toList(),
  });

  static ({List<DemoSession> sessions, List<DemoAsset> assets}) _decodeSnapshot(
    String raw,
  ) {
    final json = jsonDecode(raw) as Map<String, Object?>;
    final sessions = (json['sessions'] as List)
        .map(
          (item) =>
              DemoSession.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList();
    final assets = (json['assets'] as List)
        .map(
          (item) => DemoAsset.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList();
    if (sessions.map((item) => item.id).toSet().length != sessions.length ||
        assets.map((item) => item.id).toSet().length != assets.length) {
      throw const FormatException('Duplicate demo identifiers');
    }
    return (sessions: sessions, assets: assets);
  }

  static Map<String, Object?> _map(Object? value) =>
      value is Map ? Map<String, Object?>.from(value) : const {};

  static List<Map<String, Object?>> _mapList(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, Object?>.from(item))
            .toList()
      : const [];

  static List<String> _stringList(Object? value) =>
      value is List ? value.map((item) => item.toString()).toList() : const [];

  static Map<String, String> _stringMap(Object? value) => value is Map
      ? value.map(
          (key, item) => MapEntry(key.toString(), item?.toString() ?? ''),
        )
      : const {};

  static Map<String, int> _colorMap(Object? value) => value is Map
      ? value.map((key, item) {
          final text = item?.toString() ?? '';
          final parsed = item is num
              ? item.toInt()
              : int.tryParse(text) ??
                    int.tryParse(text.replaceFirst('#', ''), radix: 16) ??
                    0;
          return MapEntry(key.toString(), parsed);
        })
      : const {};

  static Map<String, List<String>> _stringListMap(Object? value) => value is Map
      ? value.map((key, item) => MapEntry(key.toString(), _stringList(item)))
      : const {};

  static Map<String, DemoRoleProfile> _roleProfileMap(Object? value) =>
      value is Map
      ? value.map(
          (key, item) =>
              MapEntry(key.toString(), DemoRoleProfile.fromJson(_map(item))),
        )
      : const {};

  static int _int(Object? value, {required int fallback}) =>
      value is num ? value.toInt() : fallback;

  static double _double(Object? value, {required double fallback}) =>
      value is num ? value.toDouble() : fallback;

  @override
  void dispose() {
    _disposed = true;
    for (final waiter in _questionWaiters.values) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _questionWaiters.clear();
    _questionResponses.clear();
    _questionRunWatchers.clear();
    _mediaWatchers.clear();
    super.dispose();
  }
}

class _HarnessSnapshot {
  const _HarnessSnapshot({
    required this.session,
    required this.runs,
    required this.assets,
    required this.assetsAuthoritative,
    required this.requestOrder,
  });

  final DemoSession session;
  final List<Map<String, Object?>> runs;
  final List<DemoAsset> assets;
  final bool assetsAuthoritative;
  final int requestOrder;

  bool get hasPendingMediaJobs => session.mediaJobs.any((job) => job.isPending);
  bool get hasPendingQuestions =>
      session.messages.any((message) => message.question?.isPending ?? false);

  bool hasPendingQuestionForRun(String? runId) => session.messages.any(
    (message) =>
        (message.question?.isPending ?? false) &&
        (runId == null || message.runId.isEmpty || message.runId == runId),
  );
}

class HarnessRunStoppedException implements Exception {
  const HarnessRunStoppedException();
}

class HarnessRunTerminalException implements Exception {
  const HarnessRunTerminalException(this.message);

  final String message;

  @override
  String toString() => message;
}
