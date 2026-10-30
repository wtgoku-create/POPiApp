import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/agent_api_exception.dart';
import '../../../core/network/network_agent_api.dart';
import '../../../core/network/network_api.dart';
import 'business_asset_uploader.dart';
import '../../../core/config/app_config.dart';
import '../../../core/storage/preferences_storage.dart';
import '../domain/demo_preference_options.dart';
import '../../../shared/type/bot_avatar_type.dart';
import '../domain/demo_assistant_profile.dart';
import '../domain/demo_assistant_identity.dart';
import '../domain/demo_models.dart';
import '../domain/demo_upload_file.dart';
import '../domain/demo_capability_catalog.dart';
import 'demo_fixtures.dart';

export '../domain/demo_capability_catalog.dart';
export 'business_asset_uploader.dart'
    show BusinessUploadProgress, BusinessUploadPhase;
export '../domain/demo_assistant_profile.dart';
export '../domain/demo_style_film_models.dart';

/// The demo store can run against bundled fixtures or the isolated local Harness.
class DemoRepository extends ChangeNotifier {
  DemoRepository(this._storage)
    : _api = null,
      _businessUploader = null,
      _businessLibrary = false,
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
    String? userStorageKey,
    NetworkApi? libraryApi,
    bool? businessLibrary,
  }) : _api = api,
       _businessUploader = libraryApi == null
           ? null
           : BusinessAssetUploader(libraryApi),
       _businessLibrary = businessLibrary ?? AppConfig.businessAgentEnabled,
       _storageKey = userStorageKey ?? harnessStorageKey,
       _pollInterval = pollInterval,
       _questionPollInterval = questionPollInterval,
       _maxPollAttempts = maxPollAttempts,
       _sessions = [],
       _assets = [];

  static const storageKey = 'popi_ui_demo_v1';
  static const backupStorageKey = 'popi_ui_demo_v1_before_harness';
  static const harnessStorageKey = 'popi_harness_demo_v1';

  /// 正式用户不导入无归属的测试数据，同一环境和用户可恢复自己的缓存。
  static String businessStorageKey(
    String environment,
    String origin,
    String userId,
  ) =>
      'popi_business_v1_${Uri.encodeComponent(environment)}_${Uri.encodeComponent(origin)}_${Uri.encodeComponent(userId)}';

  final PreferencesStorage _storage;
  final NetworkAgentApi? _api;
  final BusinessAssetUploader? _businessUploader;
  final bool _businessLibrary;
  final String _storageKey;
  final Duration _pollInterval;
  final Duration _questionPollInterval;
  final int _maxPollAttempts;
  final Map<String, String> _requestIds = {};
  final Map<String, String> _pendingBotIds = {};
  final Map<String, Future<void>> _filmReviews = {};
  final Set<String> _stopRequestedSessions = {};
  final Set<String> _runningSessions = {};
  final Map<String, bool> _currentRunCanStop = {};
  final Map<String, String> _acceptedRunAwaitingSnapshot = {};
  final Map<String, Completer<void>> _questionWaiters = {};
  final Map<String, ({String payloadSignature, Future<void> operation})>
  _questionResponses = {};
  final Map<String, Future<void>> _questionRunWatchers = {};
  final Map<String, Future<void>> _mediaWatchers = {};
  final Map<String, int> _latestAppliedSnapshotRequest = {};
  final Map<String, DemoAsset> _uploadedFiles = {};
  final LinkedHashMap<_AssetTextCacheKey, _AssetTextCacheEntry>
  _assetTextCache = LinkedHashMap();
  final Map<_AssetTextCacheKey, Future<String>> _assetTextLoads = {};
  Map<String, Set<String>> _dismissedMediaJobIds = {};
  List<DemoSession> _sessions;
  List<DemoAsset> _assets;
  Future<void> _pending = Future.value();
  int _snapshotRequestSerial = 0;
  int _assetListRequestSerial = 0;
  int _latestAppliedAssetListRequest = 0;
  int _assetTextCacheBytes = 0;
  int _assetTextCacheGeneration = 0;
  bool _disposed = false;
  bool _loading = false;
  final Set<String> _loadingSessions = {};

  bool get isHarness => _api != null;
  bool get supportsDirectUpload => _businessUploader != null;
  bool get usesBusinessLibrary => isHarness && _businessLibrary;

  Future<List<DemoPreferenceStep>> preferenceOptions() async =>
      DemoPreferenceStep.parse(await _api!.preferenceOptions());
  List<Map<String, Object?>> _libraryRoles = [];
  List<Map<String, Object?>> get libraryRoles =>
      List.unmodifiable(_libraryRoles);
  Map<String, Object?>? libraryRole(String id) =>
      _libraryRoles.where((role) => role['id'] == id).firstOrNull;
  DemoRoleProfile? libraryRoleProfile(String id) {
    final role = libraryRole(id);
    return role == null ? null : DemoRoleProfile.fromJson(role);
  }

  String roleImageUrl(String source) {
    var resolved = source;
    if (usesBusinessLibrary && !source.startsWith('/api_agent/')) {
      for (final role in _libraryRoles) {
        final reference = _mapList(role['references'])
            .where(
              (item) => item['url'] == source && item['contentUrl'] is String,
            )
            .firstOrNull;
        if (reference != null) {
          resolved = reference['contentUrl']! as String;
          break;
        }
      }
    }
    return resolved.startsWith('/api_agent/v2/roles/') && _api != null
        ? Uri.parse(_api.dio.options.baseUrl).resolve(resolved).toString()
        : resolved;
  }

  Future<void> refreshRoles() async {
    if (!usesBusinessLibrary) return;
    final roles = <Map<String, Object?>>[];
    for (final category in ['official', 'personal']) {
      var page = 1;
      var loaded = 0;
      while (true) {
        final result = await _api!.libraryRoles(
          page: page++,
          category: category,
        );
        final items = _mapList(result['list']);
        roles.addAll(items);
        loaded += items.length;
        if (loaded >= _int(result['total'], fallback: loaded) ||
            items.isEmpty) {
          break;
        }
      }
    }
    _libraryRoles = roles;
    notifyListeners();
  }

  Future<Map<String, Object?>> saveBusinessRole({
    required String clientRequestId,
    required String name,
    required String instructions,
    required List<DemoUploadFile> files,
  }) async {
    // 固定创建请求可在部分图片上传失败后重放；实际内容由后续编辑一次保存。
    final created = await _api!.saveLibraryRole({
      'clientRequestId': clientRequestId,
      'name': '新角色',
    });
    var role = _map(created['role']);
    final id = role['id']!.toString();
    role = _map((await _api.libraryRole(id))['role']);
    final references = <Map<String, Object?>>[];
    for (final file in files) {
      final cacheKey = 'role-upload:$id:${file.clientRequestId}';
      final revision = _requestIds.putIfAbsent(
        '$cacheKey:revision',
        () => role['revision'].toString(),
      );
      final result = await _api.uploadRoleReference(
        roleId: id,
        requestId: file.clientRequestId,
        revision: revision,
        name: file.name,
        mimeType: file.mimeType,
        bytes: await file.readBytes(),
      );
      // 回放可能返回旧回执，继续操作前读取当前修订号。
      if (result['role'] == null) {
        throw const FormatException('Invalid role upload');
      }
      final mediaId = _map(result['role'])['uploadedMediaId'];
      if (mediaId is! num || mediaId <= 0) {
        throw const FormatException('Missing uploaded reference');
      }
      if (!references.any((item) => item['mediaId'] == mediaId)) {
        references.add({'mediaId': mediaId, 'purpose': 'reference'});
      }
      role = _map((await _api.libraryRole(id))['role']);
    }
    final payload = {
      'name': name,
      'instructions': instructions,
      'revision': role['revision'],
      'references': references,
    };
    final key = 'role-save:$id:${jsonEncode(payload)}';
    final result = await _api.saveLibraryRole({
      ...payload,
      'clientRequestId': _requestIds.putIfAbsent(key, () => const Uuid().v4()),
    }, id: id);
    role = _map(result['role']);
    _libraryRoles = [role, ..._libraryRoles.where((item) => item['id'] != id)];
    notifyListeners();
    return role;
  }

  bool get loading => _loading;
  bool isSessionLoading(String id) => _loadingSessions.contains(id);
  bool isSessionRunning(String id) => _runningSessions.contains(id);
  bool canStopCurrentHarnessRun(String id) => _currentRunCanStop[id] ?? true;
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
        final identity = session.botIdFor(memberId);
        if (!seen.add(identity)) continue;
        profiles.add(
          DemoAssistantProfile(
            id: identity,
            memberId: memberId,
            name: name,
            instructions: instructions,
            avatarAsset: avatar,
            avatarColor: color,
            skillIds: session.skillsFor(memberId),
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

  Future<void> setMemberSkillEnabled(
    String sessionId, {
    required String memberId,
    required String skillId,
    required bool enabled,
  }) {
    if (!isValidDemoSkillId(skillId) ||
        !session(sessionId).members.contains(memberId)) {
      throw ArgumentError('Unknown member skill binding');
    }
    return updateSession(sessionId, (current) {
      if (!current.members.contains(memberId)) {
        throw ArgumentError('The member is no longer in this session');
      }
      final selected = current.skillsFor(memberId).toSet();
      if (enabled) {
        selected.add(skillId);
      } else {
        selected.remove(skillId);
      }
      return current.copyWith(
        memberSkills: {...current.memberSkills, memberId: selected.toList()},
      );
    });
  }

  Future<DemoStyleFilmCatalog> loadStyleFilmCatalog({
    String? q,
    String? category,
    int page = 1,
    int pageSize = 20,
  }) async {
    final api = _api;
    if (api == null) {
      return const DemoStyleFilmCatalog(reasonUnavailable: 'not_connected');
    }
    final response = Map<String, Object?>.from(
      await api.styleFilmCatalog(
        q: q,
        category: category,
        page: page,
        pageSize: pageSize,
      ),
    );
    response['list'] = _mapList(response['list'])
        .map(
          (style) => {
            ...style,
            if (style['posterUrl'] case final String url when url.isNotEmpty)
              'posterUrl': api.resolveStyleFilmPosterUrl(url),
          },
        )
        .toList();
    return DemoStyleFilmCatalog.fromJson(response);
  }

  DemoStyleFilmSelection? styleFilmDraft(String sessionId, String botId) =>
      session(sessionId).filmDrafts[botId];

  Future<String> prepareStyleFilmRequest(
    String sessionId,
    String botId, {
    required String body,
    required String proposedRequestId,
  }) async {
    if (_disposed) throw StateError('Repository is disposed');
    var requestId = proposedRequestId;
    await _commit(
      () => (
        sessions: _sessions.map((item) {
          if (item.id != sessionId) return item;
          if (!item.members.any((member) => item.botIdFor(member) == botId)) {
            throw ArgumentError('Unknown Bot for film request');
          }
          final previous = item.filmPendingRequests[botId];
          if (previous?.body == body) requestId = previous!.clientRequestId;
          return item.copyWith(
            filmPendingRequests: {
              ...item.filmPendingRequests,
              botId: DemoStyleFilmPendingRequest(
                body: body,
                clientRequestId: requestId,
              ),
            },
          );
        }).toList(),
        assets: _assets,
      ),
    );
    return requestId;
  }

  Future<void> updateStyleFilmDraft(
    String sessionId,
    String botId,
    DemoStyleFilmSelection? selection,
  ) {
    final current = session(sessionId);
    if (!current.members.any((member) => current.botIdFor(member) == botId) ||
        (selection != null && !selection.isValid)) {
      throw ArgumentError('Invalid style film draft');
    }
    return _commit(
      () => (
        sessions: _sessions.map((item) {
          if (item.id != sessionId) return item;
          final drafts = {...item.filmDrafts};
          if (selection == null) {
            drafts.remove(botId);
          } else {
            drafts[botId] = selection;
          }
          return item.copyWith(filmDrafts: drafts);
        }).toList(),
        assets: _assets,
      ),
    );
  }

  DemoStyleFilmJob? styleFilmJob(String sessionId, String jobId) => session(
    sessionId,
  ).filmJobs.where((job) => job.jobId == jobId).firstOrNull;

  Future<void> reviewStyleFilm(
    String sessionId,
    String jobId, {
    required int expectedRevision,
    required String action,
    String? notes,
  }) {
    final api = _api;
    if (api == null) throw StateError('Style films require Harness transport');
    final trimmedNotes = notes?.trim();
    if (!const ['approve', 'revise'].contains(action) ||
        (trimmedNotes?.runes.length ?? 0) > 2000) {
      throw ArgumentError('Invalid style film review');
    }
    final key =
        '$sessionId:$jobId:$expectedRevision:$action:${trimmedNotes ?? ''}';
    final pending = _filmReviews[key];
    if (pending != null) return pending;
    final operation = _reviewStyleFilm(
      sessionId,
      jobId,
      expectedRevision,
      action,
      trimmedNotes,
      key,
    );
    _filmReviews[key] = operation;
    unawaited(
      operation.then<void>(
        (_) => _filmReviews.remove(key),
        onError: (Object _, StackTrace _) {
          _filmReviews.remove(key);
        },
      ),
    );
    return operation;
  }

  Future<void> _reviewStyleFilm(
    String sessionId,
    String jobId,
    int revision,
    String action,
    String? notes,
    String key,
  ) async {
    try {
      await _api!.reviewStyleFilm(
        sessionId,
        jobId,
        clientRequestId: _requestId('film-review:$key'),
        expectedRevision: revision,
        action: action,
        notes: notes,
      );
      final snapshot = await _loadSnapshot(
        sessionId,
        fallback: session(sessionId),
      );
      await _applySnapshot(snapshot);
      _requestIds.remove('film-review:$key');
      if (snapshot.hasPendingMediaJobs) _startMediaWatcher(sessionId);
    } on AgentApiException catch (error) {
      if (error.statusCode == 409) {
        _requestIds.remove('film-review:$key');
        try {
          await refreshSession(sessionId);
        } catch (_) {
          /* Keep the review error. */
        }
      }
      rethrow;
    }
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
    _clearAssetTextCache();
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
        await refreshRoles();
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
    if (usesBusinessLibrary) {
      await _commit(() {
        if (requestOrder < _latestAppliedAssetListRequest) {
          return (sessions: _sessions, assets: _assets);
        }
        _latestAppliedAssetListRequest = requestOrder;
        return (sessions: _sessions, assets: listed);
      });
      return;
    }
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
  Future<DemoAsset> uploadFile(
    DemoUploadFile file, {
    BusinessUploadProgress? onProgress,
  }) async {
    if (_disposed) throw StateError('Repository disposed');
    final api = _api;
    if (api == null) {
      throw StateError('File upload is available only in Harness mode');
    }

    var asset = _uploadedFiles[file.clientRequestId];
    if (asset == null) {
      final uploader = _businessUploader;
      if (usesBusinessLibrary && uploader == null) {
        throw StateError('Business upload transport is unavailable');
      }
      final response = uploader != null
          ? await api.importBusinessAsset(
              await uploader.upload(file, onProgress: onProgress),
            )
          : await api.uploadAsset(
              clientRequestId: file.clientRequestId,
              name: file.name,
              mimeType: file.mimeType,
              bytes: await file.readBytes(),
            );
      if (_disposed) throw StateError('Repository disposed');
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

  void cancelFileUpload(String clientRequestId) =>
      _businessUploader?.cancel(clientRequestId);

  Future<Uint8List> readAssetBytes(DemoAsset asset) async {
    final api = _api;
    if (api == null || !asset.isRemote) {
      throw StateError('Only Harness owned assets can be read remotely');
    }
    if (asset.sizeBytes > 0 || asset.businessAssetId.isEmpty) {
      DemoUploadFile.validateMetadata(
        name: asset.title.isEmpty ? asset.id : asset.title,
        mimeType: asset.mimeType,
        sizeBytes: asset.sizeBytes,
        kind: asset.kind,
      );
    }
    final bytes = asset.businessAssetId.isNotEmpty
        ? await api.readBusinessAssetBytes(
            asset.id,
            maxBytes: DemoUploadFile.limitFor(
              asset.kind,
              mimeType: asset.mimeType,
            ),
          )
        : await api.readAssetBytes(asset.contentUrl);
    DemoUploadFile.validateBytes(
      bytes,
      expectedSizeBytes: asset.sizeBytes > 0 ? asset.sizeBytes : bytes.length,
      mimeType: asset.mimeType,
      kind: asset.kind,
    );
    return bytes;
  }

  Future<String> readAssetText(DemoAsset asset) async {
    if (asset.kind != DemoAssetKind.script) {
      throw const DemoUploadException('UNSUPPORTED_TYPE');
    }
    if (asset.isDocument) {
      final api = _api;
      if (api == null ||
          !asset.isRemote ||
          !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(asset.id)) {
        throw const DemoUploadException('UNSUPPORTED_TYPE');
      }
      final response = await api.assetText(asset.id);
      final text = response['text'];
      if (text is! String) throw const DemoUploadException('INVALID_CONTENT');
      return text;
    }
    if (!_cacheableAssetTextMimeTypes.contains(asset.mimeType)) {
      return _readUncachedAssetText(asset);
    }
    DemoUploadFile.validateMetadata(
      name: asset.title.isEmpty ? asset.id : asset.title,
      mimeType: asset.mimeType,
      sizeBytes: asset.sizeBytes,
      kind: asset.kind,
    );
    final key = (
      id: asset.id,
      contentUrl: asset.contentUrl,
      mimeType: asset.mimeType,
      sizeBytes: asset.sizeBytes,
      sha256: asset.sha256,
    );
    final cached = _assetTextCache.remove(key);
    if (cached != null) {
      _assetTextCache[key] = cached;
      return cached.text;
    }
    final pending = _assetTextLoads[key];
    if (pending != null) return pending;

    final generation = _assetTextCacheGeneration;
    late final Future<String> operation;
    operation = _loadAndCacheAssetText(asset, key, generation).whenComplete(() {
      if (identical(_assetTextLoads[key], operation)) {
        _assetTextLoads.remove(key);
      }
    });
    _assetTextLoads[key] = operation;
    return operation;
  }

  Future<String> _loadAndCacheAssetText(
    DemoAsset asset,
    _AssetTextCacheKey key,
    int generation,
  ) async {
    final bytes = await readAssetBytes(asset);
    final text = _decodeAssetText(bytes);
    if (!_disposed && generation == _assetTextCacheGeneration) {
      _cacheAssetText(key, text, bytes.lengthInBytes);
    }
    return text;
  }

  Future<String> _readUncachedAssetText(DemoAsset asset) async {
    final bytes = await readAssetBytes(asset);
    return _decodeAssetText(bytes);
  }

  String _decodeAssetText(Uint8List bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } on FormatException {
      throw const DemoUploadException('INVALID_CONTENT');
    }
  }

  void _cacheAssetText(_AssetTextCacheKey key, String text, int byteLength) {
    final replaced = _assetTextCache.remove(key);
    if (replaced != null) _assetTextCacheBytes -= replaced.byteLength;
    _assetTextCache[key] = (text: text, byteLength: byteLength);
    _assetTextCacheBytes += byteLength;
    while (_assetTextCache.length > _assetTextCacheMaxEntries ||
        _assetTextCacheBytes > _assetTextCacheMaxBytes) {
      final oldestKey = _assetTextCache.keys.first;
      final oldest = _assetTextCache.remove(oldestKey)!;
      _assetTextCacheBytes -= oldest.byteLength;
    }
  }

  void _clearAssetTextCache() {
    _assetTextCacheGeneration += 1;
    _assetTextCache.clear();
    _assetTextLoads.clear();
    _assetTextCacheBytes = 0;
  }

  void validateMessageAttachments(List<String> assetIds) {
    final selected = assetIds
        .map((id) => _assets.where((asset) => asset.id == id).firstOrNull)
        .toList();
    if (selected.any((asset) => asset == null)) {
      throw const AgentApiException(
        code: 'message_attachment_not_found',
        statusCode: 400,
      );
    }
    try {
      DemoUploadFile.validateMessageAttachments(
        selected.whereType<DemoAsset>().toList(),
      );
    } on DemoUploadException catch (error) {
      throw AgentApiException(
        code: switch (error.code) {
          'ATTACHMENT_LIMIT' => 'message_attachment_limit',
          'ATTACHMENTS_TOO_LARGE' => 'message_attachment_too_large',
          _ => 'message_attachment_invalid',
        },
        statusCode: 400,
      );
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
          if (snapshot.hasPendingMediaJobs) _startMediaWatcher(id);
          _stopRequestedSessions.remove(id);
          return;
        }
        if (state == 'failed' || state == 'interrupted') {
          if (snapshot.hasPendingMediaJobs) _startMediaWatcher(id);
          if (_stopRequestedSessions.remove(id)) return;
          if (snapshot.hasFilmJobForRun(observedRunId)) {
            return;
          }
          final error = _map(observedRun?['error']);
          throw HarnessRunTerminalException(
            error['message']?.toString() ?? 'Agent run $state',
          );
        }
        if (attempt == _maxPollAttempts) {
          if (snapshot.hasPendingMediaJobs) _startMediaWatcher(id);
          break;
        }
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
    String direction = '',
    Map<String, String> accountPreferences = const {},
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
                    assistant.avatarColor! > 0xFFFFFFFF)) ||
            assistant.skillIds.toSet().length != assistant.skillIds.length ||
            assistant.skillIds.any((id) => !isValidDemoSkillId(id)))) {
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
    final draftIdentityKey = assistant == null
        ? ''
        : jsonEncode({
            'id': assistant.id,
            'member': assistant.memberId,
            'name': assistant.name,
            'instructions': assistant.instructions,
            'avatar': assistant.avatarAsset,
            'color': assistant.avatarColor,
            'skills': assistant.skillIds,
          });
    final persistentProfile =
        assistant != null &&
        (assistant.id.startsWith('builtin:') ||
            assistant.id.startsWith('bot:') ||
            assistant.id.startsWith('legacy:'));
    final botId = assistant == null
        ? ''
        : persistentProfile
        ? assistant.id
        : _pendingBotIds.putIfAbsent(
            draftIdentityKey,
            () => 'bot:${const Uuid().v4()}',
          );
    final memberBotIds = {
      for (final member in selectedMembers)
        member: assistant != null && member == assistant.memberId
            ? botId
            : 'builtin:$member',
    };
    final memberSkills = <String, List<String>>{
      if (assistant != null) assistant.memberId: List.of(assistant.skillIds),
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
              memberBotIds: memberBotIds,
              memberSkills: memberSkills,
              direction: direction,
              accountPreferences: Map.of(accountPreferences),
              configRevision: 1,
              configurationStatus: 'configured',
            ),
            ..._sessions,
          ],
          assets: _assets,
        ),
      );
      _pendingBotIds.remove(draftIdentityKey);
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
      memberBotIds: memberBotIds,
      memberSkills: memberSkills,
      direction: direction,
      accountPreferences: Map.of(accountPreferences),
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
    _pendingBotIds.remove(draftIdentityKey);
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
              .map(
                (session) => session.id == id
                    ? _normalizeSingleAssistantRename(
                        session,
                        update(_withBotIdentity(session)),
                      )
                    : session,
              )
              .toList(),
          assets: _assets,
        ),
      );
    }
    final current = _withBotIdentity(session(id));
    final next = _normalizeSingleAssistantRename(current, update(current));
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
    _clearAssetTextCache();
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

  DemoSession _normalizeSingleAssistantRename(
    DemoSession current,
    DemoSession next,
  ) {
    if (current.members.length != 1 ||
        next.members.length != 1 ||
        current.members.single != next.members.single) {
      return next;
    }
    final memberId = current.members.single;
    final currentName = current.memberNames[memberId]?.trim() ?? '';
    final nextName = next.memberNames[memberId]?.trim() ?? '';
    final nameChanged = nextName != currentName;
    final titleChanged = next.title.trim() != current.title.trim();
    if (nameChanged && nextName.isNotEmpty) {
      return next.copyWith(title: nextName);
    }
    if (titleChanged && next.title.trim().isNotEmpty) {
      return next.copyWith(
        memberNames: {...next.memberNames, memberId: next.title.trim()},
      );
    }
    return next;
  }

  Future<void> _persistLegacySingleAssistantName(String sessionId) async {
    final current = session(sessionId);
    if (current.members.length != 1) return;
    final memberId = current.members.single;
    final resolved = DemoAssistantIdentity.singleName(current);
    if (resolved == null || current.memberNames[memberId]?.trim() == resolved) {
      return;
    }
    await updateSession(
      sessionId,
      (session) => session.copyWith(
        memberNames: {...session.memberNames, memberId: resolved},
      ),
    );
  }

  Future<void> sendHarnessMessage(
    String sessionId, {
    required String clientRequestId,
    required String text,
    List<String> mediaIds = const [],
    List<String> contextRoleIds = const [],
    DemoStyleFilmInvocation? skillInvocation,
    VoidCallback? onAccepted,
  }) async {
    final api = _api;
    if (api == null) throw StateError('Harness transport is not configured');
    final selectedRoles = session(sessionId).roles;
    final currentSession = session(sessionId);
    final memberId = currentSession.activeMemberId;
    final botId = currentSession.botIdFor(memberId);
    if (skillInvocation != null &&
        (!skillInvocation.selection.isValid ||
            !currentSession
                .skillsFor(memberId)
                .contains(demoStyleFilmSkillId))) {
      throw ArgumentError('The active Bot has not enabled this film skill');
    }
    if (skillInvocation != null &&
        (mediaIds.isNotEmpty || contextRoleIds.isNotEmpty)) {
      throw const AgentApiException(
        code: 'style_film_references_unsupported',
        message: 'Style films currently accept text stories only.',
        statusCode: 400,
      );
    }
    if (contextRoleIds.length > 5 ||
        contextRoleIds.toSet().length != contextRoleIds.length ||
        contextRoleIds.any((id) => !selectedRoles.contains(id))) {
      throw ArgumentError.value(contextRoleIds, 'contextRoleIds');
    }
    validateMessageAttachments(mediaIds);
    await _persistLegacySingleAssistantName(sessionId);
    final accepted = await api.sendSessionMessage(
      sessionId,
      clientRequestId: clientRequestId,
      text: text,
      mediaIds: mediaIds.isEmpty ? null : mediaIds,
      contextRoleIds: contextRoleIds.isEmpty ? null : contextRoleIds,
      skillInvocation: skillInvocation?.toJson(),
    );
    final runId = accepted['runId']?.toString();
    // The accepted response identifies this run before its first snapshot.
    _currentRunCanStop[sessionId] =
        accepted['jobId']?.toString().isNotEmpty != true;
    if (runId != null) _acceptedRunAwaitingSnapshot[sessionId] = runId;
    // A newly accepted run starts a new stop-idempotency lifecycle. Keep an
    // uncertain stop key reusable within one run, but never replay it later.
    _requestIds.remove('stop:$sessionId');
    var state = accepted['state']?.toString() ?? 'queued';
    _runningSessions.add(sessionId);
    notifyListeners();
    onAccepted?.call();
    if (skillInvocation != null) {
      final submitted = skillInvocation.selection.toArguments();
      await _commit(
        () => (
          sessions: _sessions.map((item) {
            if (item.id != sessionId) return item;
            final drafts = {...item.filmDrafts};
            if (jsonEncode(drafts[botId]?.toArguments()) ==
                jsonEncode(submitted)) {
              drafts.remove(botId);
            }
            final requests = {...item.filmPendingRequests};
            if (requests[botId]?.clientRequestId == clientRequestId) {
              requests.remove(botId);
            }
            return item.copyWith(
              filmDrafts: drafts,
              filmPendingRequests: requests,
            );
          }).toList(),
          assets: _assets,
        ),
      );
    }
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
          if (snapshot.hasPendingMediaJobs) _startMediaWatcher(sessionId);
          _stopRequestedSessions.remove(sessionId);
          throw const HarnessRunStoppedException();
        }
        if (state == 'failed' || state == 'interrupted') {
          if (snapshot.hasPendingMediaJobs) _startMediaWatcher(sessionId);
          if (_stopRequestedSessions.remove(sessionId)) {
            throw const HarnessRunStoppedException();
          }
          if (snapshot.hasFilmJobForRun(runId)) {
            return;
          }
          final error = _map(run?['error']);
          throw HarnessRunTerminalException(
            error['message']?.toString() ?? 'Agent run $state',
          );
        }
        if (attempt == _maxPollAttempts) {
          if (snapshot.hasPendingMediaJobs) _startMediaWatcher(sessionId);
          break;
        }
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

  Future<void> renameAsset(String id, String title) async {
    if (usesBusinessLibrary) {
      await _api!.renameAsset(id, title.trim());
    } else {
      _requireOfflineAssets();
    }
    return _commit(
      () => (
        sessions: _sessions,
        assets: _assets
            .map((a) => a.id == id ? a.copyWith(title: title.trim()) : a)
            .toList(),
      ),
    );
  }

  Future<void> deleteAsset(String id) async {
    _clearAssetTextCache();
    if (usesBusinessLibrary) {
      await _api!.deleteAsset(id);
      _uploadedFiles.removeWhere((_, asset) => asset.id == id);
    } else {
      _requireOfflineAssets();
    }
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
    _clearAssetTextCache();
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
        final delay =
            snapshot.session.filmJobs.any((job) => job.isPending) &&
                _pollInterval > Duration.zero
            ? const Duration(seconds: 2)
            : _pollInterval;
        await Future<void>.delayed(delay);
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
    final fallbackMessages = {
      for (final message in fallback?.messages ?? const <DemoMessage>[])
        message.id: message,
    };
    final messages = _mapList(response['messages'])
        .map(
          (record) => _messageFromRecord(
            record,
            fallback: fallbackMessages[record['id']?.toString()],
          ),
        )
        .toList();
    var nextSession = _sessionFromRecord(
      _map(response['session']),
      fallback: fallback,
      messages: messages,
      mediaJobs: _mediaJobsFromSnapshot(response),
      filmJobs: _mapList(response['filmJobs']).map(_filmJobFromRecord).toList(),
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
      _projectCurrentRunStop(snapshot);
      _latestAppliedSnapshotRequest[snapshot.session.id] =
          snapshot.requestOrder;
      return (
        sessions: _sessions
            .map(
              (item) => item.id == snapshot.session.id
                  ? snapshot.session.copyWith(
                      filmDrafts: item.filmDrafts,
                      filmPendingRequests: item.filmPendingRequests,
                      filmJobs: _mergeFilmJobs(
                        item.filmJobs,
                        snapshot.session.filmJobs,
                      ),
                    )
                  : item,
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
          _projectCurrentRunStop(snapshot);
          accepted.add(snapshot);
          sessions.add(
            snapshot.session.copyWith(
              filmDrafts: current?.filmDrafts ?? snapshot.session.filmDrafts,
              filmPendingRequests:
                  current?.filmPendingRequests ??
                  snapshot.session.filmPendingRequests,
              filmJobs: _mergeFilmJobs(
                current?.filmJobs ?? const [],
                snapshot.session.filmJobs,
              ),
            ),
          );
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
        filmJobs: current.filmJobs,
        filmDrafts: current.filmDrafts,
        filmPendingRequests: current.filmPendingRequests,
        lastSeq: current.lastSeq,
      );
    }
    return response.copyWith(
      filmDrafts: current.filmDrafts,
      filmPendingRequests: current.filmPendingRequests,
      filmJobs: _mergeFilmJobs(current.filmJobs, response.filmJobs),
    );
  }

  static DemoSession _withBotIdentity(DemoSession session) => session.copyWith(
    memberBotIds: {
      for (final member in session.members) member: session.botIdFor(member),
    },
  );

  void _projectCurrentRunStop(_HarnessSnapshot snapshot) {
    final id = snapshot.session.id;
    final acceptedRun = _acceptedRunAwaitingSnapshot[id];
    if (acceptedRun != null &&
        !snapshot.runs.any((run) => run['id'] == acceptedRun)) {
      return;
    }
    _currentRunCanStop[id] = snapshot.canStopCurrentRun;
    _acceptedRunAwaitingSnapshot.remove(id);
  }

  static List<DemoStyleFilmJob> _mergeFilmJobs(
    List<DemoStyleFilmJob> current,
    List<DemoStyleFilmJob> incoming,
  ) {
    final existing = {for (final job in current) job.jobId: job};
    return incoming.map((job) {
      final old = existing[job.jobId];
      if (old == null) return job;
      if (job.revision < old.revision) return old;
      final oldTime = DateTime.tryParse(old.updatedAt);
      final newTime = DateTime.tryParse(job.updatedAt);
      if (job.revision == old.revision &&
          oldTime != null &&
          newTime != null &&
          newTime.isBefore(oldTime)) {
        return old;
      }
      return job;
    }).toList();
  }

  DemoStyleFilmJob _filmJobFromRecord(Map<String, Object?> record) {
    final normalized = {...record};
    normalized['storyboard'] = _mapList(record['storyboard']).map((shot) {
      final url = shot['previewUrl']?.toString() ?? '';
      return {
        ...shot,
        'previewUrl': url.isEmpty ? '' : _api!.resolveAssetContentUrl(url),
      };
    }).toList();
    return DemoStyleFilmJob.fromJson(normalized);
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
      creativeMemory: fallback.creativeMemory,
      capabilities: fallback.capabilities,
      memberNames: fallback.memberNames,
      memberInstructions: fallback.memberInstructions,
      memberAvatars: fallback.memberAvatars,
      memberColors: fallback.memberColors,
      memberCapabilities: fallback.memberCapabilities,
      memberSkills: fallback.memberSkills,
      memberBotIds: {
        for (final member in fallback.members)
          member: fallback.botIdFor(member),
      },
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
        mediaJobs: _mediaJobsFromSnapshot(response),
        filmJobs: _mapList(
          response['filmJobs'],
        ).map(_filmJobFromRecord).toList(),
        lastSeq: _int(response['lastSeq'], fallback: server.lastSeq),
      );
    }
  }

  /// Projects deterministic background edits into the existing media-job UI.
  List<DemoMediaJob> _mediaJobsFromSnapshot(Map<String, dynamic> response) => [
    ..._mapList(response['mediaJobs']).map(DemoMediaJob.fromJson),
    ..._mapList(response['videoEditJobs']).map((record) {
      final editState = record['state']?.toString() ?? '';
      final state = switch (editState) {
        'rendering' => 'running',
        'validating' => 'processing',
        'cancel_requested' => 'processing',
        _ => editState,
      };
      final ingestionState = switch (editState) {
        'ingesting' => 'ingesting',
        'completed' => 'completed',
        'failed' => 'failed',
        _ => '',
      };
      return DemoMediaJob.fromJson({
        'jobId': record['jobId'],
        'state': state,
        'operation': 'video-edit',
        'model': 'ffmpeg',
        'runId': record['runId'],
        'memberId': record['memberId'],
        'configRevision': record['configRevision'],
        'assetIds': record['assetIds'],
        'ingestionState': ingestionState,
        'error': record['error'],
      });
    }),
  ];

  DemoMessage _messageFromRecord(
    Map<String, Object?> message, {
    DemoMessage? fallback,
  }) => DemoMessage(
    id: message['id']?.toString() ?? '',
    text: message['text']?.toString() ?? '',
    user: message['role'] == 'user',
    assetIds: _stringList(message['assetIds'] ?? message['assets']),
    status: message['status']?.toString(),
    memberId: message['memberId']?.toString() ?? '',
    memberName: message['memberName']?.toString() ?? '',
    runId: message['runId']?.toString() ?? '',
    configRevision: _int(message['configRevision'], fallback: 0),
    createdAt: _dateTime(message['createdAt']) ?? fallback?.createdAt,
    question: message['question'] is Map
        ? DemoQuestion.fromJson(_map(message['question']))
        : null,
    activity: message['activity'] is Map
        ? DemoActivity.fromJson(_map(message['activity']))
        : null,
    filmJobId: message['filmJobId']?.toString() ?? '',
  );

  DemoSession _sessionFromRecord(
    Map<String, Object?> record, {
    DemoSession? fallback,
    DemoSessionKind? fallbackKind,
    List<DemoMessage>? messages,
    List<DemoMediaJob>? mediaJobs,
    List<DemoStyleFilmJob>? filmJobs,
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
      updatedAt:
          _dateTime(record['updatedAt']) ??
          fallback?.updatedAt ??
          _dateTime(record['createdAt']),
      direction: configured
          ? configuration['direction']?.toString() ?? ''
          : fallback?.direction ?? '',
      positioning: configured
          ? configuration['positioning']?.toString() ?? ''
          : fallback?.positioning ?? '',
      accountPreferences: configured
          ? _stringMap(configuration['accountPreferences'])
          : fallback?.accountPreferences ?? const {},
      creativeMemory: configured
          ? DemoCreativeMemory.fromJson(configuration['creativeMemory'])
          : fallback?.creativeMemory ?? const DemoCreativeMemory(),
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
      memberSkills: configured
          ? _stringListMap(configuration['memberSkills'])
          : fallback?.memberSkills ?? const {},
      memberBotIds: configured && configuration['memberBotIds'] is Map
          ? _stringMap(configuration['memberBotIds'])
          : fallback?.memberBotIds ?? const {},
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
      filmJobs: filmJobs ?? fallback?.filmJobs ?? const [],
      filmDrafts: fallback?.filmDrafts ?? const {},
      filmPendingRequests: fallback?.filmPendingRequests ?? const {},
      pinned: record['pinned'] as bool? ?? fallback?.pinned ?? false,
    );
  }

  DateTime? _dateTime(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
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
    if (sizeBytes > 0 || record['businessAssetId'] == null) {
      DemoUploadFile.validateMetadata(
        name: record['title']?.toString().isNotEmpty == true
            ? record['title']!.toString()
            : id,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        kind: kind,
      );
    }
    final relative =
        record['contentUrl']?.toString() ??
        record['contentPath']?.toString() ??
        '';
    var contentUrl = _api!.resolveAssetContentUrl(relative);
    if (Uri.parse(contentUrl).path != '/api_agent/v2/assets/$id/content') {
      throw const FormatException('Owned asset content URL does not match');
    }
    if (record['businessAssetId'] != null && record['access'] != null) {
      contentUrl = _api.resolveBusinessAccessUrl(record['access']);
    }
    final posterUrl = kind == DemoAssetKind.video
        ? record['businessAssetId'] != null
              ? _api.resolveBusinessPosterUrl(record['access'])
              : _resolveAssetPosterUrl(record['posterUrl'], id)
        : '';
    final thumbnailUrl = kind == DemoAssetKind.image
        ? _resolveAssetThumbnailUrl(record['thumbnailUrl'], id)
        : '';
    return DemoAsset(
      id: id,
      businessAssetId: record['businessAssetId']?.toString() ?? '',
      title: record['title']?.toString() ?? '',
      kind: kind,
      cover: kind == DemoAssetKind.image ? contentUrl : '',
      media: kind == DemoAssetKind.video || kind == DemoAssetKind.audio
          ? contentUrl
          : '',
      contentUrl: contentUrl,
      posterUrl: posterUrl,
      thumbnailUrl: thumbnailUrl,
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
      document: record['document'] is Map
          ? DemoDocumentMetadata.fromJson(_map(record['document']))
          : null,
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
    } else if (cached.businessAssetId.isEmpty &&
        (cached.kind == DemoAssetKind.audio ||
            cached.kind == DemoAssetKind.script)) {
      return null;
    }
    final contentUrl = _api!.resolveAssetContentUrl(
      '/api_agent/v2/assets/${cached.id}/content',
    );
    final posterUrl = _restoreAssetPosterUrl(cached.posterUrl, cached.id);
    final thumbnailUrl = cached.kind == DemoAssetKind.image
        ? _restoreAssetThumbnailUrl(cached.thumbnailUrl, cached.id)
        : '';
    return DemoAsset(
      id: cached.id,
      businessAssetId: cached.businessAssetId,
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
      thumbnailUrl: thumbnailUrl,
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
      document: cached.document,
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

  String _resolveAssetThumbnailUrl(Object? value, String assetId) {
    final relative = value?.toString() ?? '';
    if (relative.isEmpty) return '';
    try {
      final url = _api!.resolveAssetThumbnailUrl(relative);
      return Uri.parse(url).path == '/api_agent/v2/assets/$assetId/thumbnail'
          ? url
          : '';
    } on FormatException {
      return '';
    }
  }

  String _restoreAssetThumbnailUrl(String cachedUrl, String assetId) {
    if (cachedUrl.isEmpty) return '';
    try {
      final expected = _api!.resolveAssetThumbnailUrl(
        '/api_agent/v2/assets/$assetId/thumbnail',
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
      'memberSkills': {
        for (final member in session.members) member: session.skillsFor(member),
      },
      'memberBotIds': {
        for (final member in session.members) member: session.botIdFor(member),
      },
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
      if (session.creativeMemory.text.isNotEmpty ||
          session.creativeMemory.isUserEdited)
        'creativeMemory': session.creativeMemory.toJson(),
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
    return _mergeAuthoritativeAssets(
      current,
      incoming,
      isAuthoritative: (asset) => sessionIds.contains(asset.sessionId),
    );
  }

  static List<DemoAsset> _mergeGlobalUploads(
    List<DemoAsset> current,
    List<DemoAsset> sessionless,
  ) => _mergeAuthoritativeAssets(
    current,
    sessionless,
    isAuthoritative: (asset) =>
        asset.sessionId == null || asset.sessionId!.isEmpty,
  );

  /// Keeps existing cards in place while applying an authoritative subset.
  /// Newly discovered assets are prepended in server order.
  static List<DemoAsset> _mergeAuthoritativeAssets(
    List<DemoAsset> current,
    Iterable<DemoAsset> incoming, {
    required bool Function(DemoAsset asset) isAuthoritative,
  }) {
    final incomingById = <String, DemoAsset>{};
    final incomingIds = <String>[];
    for (final asset in incoming) {
      if (incomingById.containsKey(asset.id)) continue;
      incomingById[asset.id] = asset;
      incomingIds.add(asset.id);
    }

    final currentIds = <String>{};
    final retained = <DemoAsset>[];
    for (final asset in current) {
      if (!currentIds.add(asset.id)) continue;
      final replacement = incomingById[asset.id];
      if (replacement != null) {
        retained.add(replacement);
      } else if (!isAuthoritative(asset)) {
        retained.add(asset);
      }
    }

    return [
      for (final id in incomingIds)
        if (!currentIds.contains(id)) incomingById[id]!,
      ...retained,
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
    _businessUploader?.dispose();
    _clearAssetTextCache();
    for (final waiter in _questionWaiters.values) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _questionWaiters.clear();
    _questionResponses.clear();
    _questionRunWatchers.clear();
    _mediaWatchers.clear();
    _filmReviews.clear();
    _pendingBotIds.clear();
    _currentRunCanStop.clear();
    _acceptedRunAwaitingSnapshot.clear();
    super.dispose();
  }
}

const _cacheableAssetTextMimeTypes = {'text/plain', 'text/markdown'};
const _assetTextCacheMaxEntries = 16;
const _assetTextCacheMaxBytes = 8 * 1024 * 1024;

typedef _AssetTextCacheKey = ({
  String id,
  String contentUrl,
  String mimeType,
  int sizeBytes,
  String sha256,
});
typedef _AssetTextCacheEntry = ({String text, int byteLength});

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

  bool get canStopCurrentRun {
    final reversed = runs.reversed;
    final active =
        reversed
            .where(
              (run) => const [
                'running',
                'waiting_user',
                'stopping',
                'cancel_requested',
              ].contains(run['state']),
            )
            .firstOrNull ??
        reversed.where((run) => run['state'] == 'queued').firstOrNull;
    return active?['filmJobId']?.toString().isNotEmpty != true;
  }

  bool get hasPendingMediaJobs =>
      session.mediaJobs.any((job) => job.isPending) ||
      session.filmJobs.any((job) => job.isPending);
  bool get hasPendingQuestions =>
      session.messages.any((message) => message.question?.isPending ?? false);

  bool hasFilmJobForRun(String? runId) =>
      runId != null && session.filmJobs.any((job) => job.runId == runId);

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
