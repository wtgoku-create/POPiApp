import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../../core/network/agent_api_exception.dart';
import '../../../core/network/network_agent_api.dart';
import '../../../core/network/network_api.dart';
import '../../../core/storage/preferences_storage.dart';
import '../domain/v2_models.dart';
import '../domain/v2_upload_file.dart';
import 'business_asset_uploader.dart';
import 'v2_repository.dart';

/// Account-owned POPiBot store. Snapshots are authoritative; fixtures never enter it.
class V2RemoteRepository extends V2Repository {
  V2RemoteRepository(
    this.storage,
    this.api, {
    required this.ownerId,
    required this.namespace,
    required this.mediaHeaders,
    required NetworkApi libraryApi,
    this.pollInterval = const Duration(seconds: 2),
  }) : _uploader = BusinessAssetUploader(libraryApi),
       super(storage);

  final PreferencesStorage storage;
  final NetworkAgentApi api;
  final String ownerId;
  final String namespace;
  final Map<String, String> Function(String) mediaHeaders;
  final Duration pollInterval;
  final BusinessAssetUploader _uploader;
  List<V2Session> _sessions = [];
  List<V2Asset> _assets = [];
  List<Map<String, Object?>> _roles = [];
  final Map<String, String> _requests = {};
  final Map<String, int> _watchers = {};
  final Map<String, int> _applied = {};
  final Set<String> _refreshing = {};
  final Map<String, Future<void>> _edits = {};
  final Set<String> _sending = {};
  final Map<String, String> _acceptedRuns = {};
  final Map<String, V2Asset> _uploads = {};
  Timer? _timer;
  bool _disposed = false;
  bool _completed = false;
  int _serial = 0;
  int _assetSerial = 0;
  int _assetsApplied = 0;
  int _assetGeneration = 0;
  int _sessionGeneration = 0;
  int _listSerial = 0;
  Object? syncError;

  String get _completionKey => '$namespace:onboarding';
  void _check() {
    if (_disposed) throw StateError('Account repository disposed');
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String _request(String key) =>
      _requests.putIfAbsent(key, () => const Uuid().v4());

  @override
  bool get isRemote => true;
  @override
  List<V2Session> get sessions => List.unmodifiable(_sessions);
  @override
  List<V2Asset> get assets => List.unmodifiable(_assets);
  @override
  V2Session session(String id) => _sessions.firstWhere((s) => s.id == id);
  @override
  bool hasCompletedOnboarding(String userId) => userId == ownerId && _completed;
  @override
  void restore() => _completed = storage.getString(_completionKey) != null;

  @override
  Future<void> refresh() async {
    _check();
    final serial = ++_listSerial;
    final generation = _sessionGeneration;
    final records = <Map<String, Object?>>[];
    for (var page = 1; ; page++) {
      final response = await api.sessionsPage(page: page, pageSize: 100);
      _check();
      records.addAll(_maps(response['list']));
      if (page >= _integer(_map(response['pageInfo'])['pageCount'], 1)) break;
    }
    if (serial != _listSerial || generation != _sessionGeneration) return;
    _sessions = records.map((record) {
      final previous = _sessions.where((s) => s.id == record['id']).firstOrNull;
      final incoming = _session(record, fallback: previous);
      return previous != null &&
              (incoming.serverRevision < previous.serverRevision ||
                  incoming.configRevision < previous.configRevision)
          ? previous
          : incoming;
    }).toList();
    // Archived sessions also prove prior use, even on a new device.
    if (!_completed && _sessions.isEmpty) {
      final archived = await api.sessionsPage(archived: true, pageSize: 1);
      _check();
      _completed = _maps(archived['list']).isNotEmpty;
    }
    _completed = _completed || _sessions.isNotEmpty;
    if (_completed && storage.getString(_completionKey) == null) {
      await storage.setString(_completionKey, 'completed');
    }
    _check();
    _notify();
    _startPolling();
    // Bound parallel requests while loading the conversation previews.
    final ids = _sessions.map((s) => s.id).toList();
    for (var start = 0; start < ids.length; start += 4) {
      _check();
      await Future.wait(ids.skip(start).take(4).map(_poll));
    }
  }

  @override
  Future<String> createSession(
    String title,
    V2SessionKind kind, {
    Map<String, String> memberNames = const {},
    Map<String, String> memberInstructions = const {},
    Map<String, String> memberAvatars = const {},
    Map<String, int> memberColors = const {},
  }) => _create(
    V2Session(
      id: '',
      title: title.trim(),
      kind: kind,
      members: kind == V2SessionKind.workflow
          ? ['popi', 'writer', 'director']
          : ['popi'],
      roles: const [],
      messages: const [],
      memberNames: memberNames,
      memberInstructions: memberInstructions,
      memberAvatars: memberAvatars,
      memberColors: memberColors,
    ),
  );

  Future<String> _create(V2Session draft, {String? requestId}) async {
    _check();
    final config = _configuration(draft);
    final key =
        'create:${draft.kind.name}:${draft.title}:${jsonEncode(config)}';
    final record = await api.createHarnessSession(
      clientRequestId: requestId ?? _request(key),
      title: draft.title,
      kind: draft.kind.name,
      configuration: config,
    );
    _check();
    final saved = _session(record, fallback: draft);
    if (saved.id.isEmpty) throw const FormatException('Missing session ID');
    _sessionGeneration++;
    _sessions = [saved, ..._sessions.where((s) => s.id != saved.id)];
    _requests.remove(key);
    _notify();
    return saved.id;
  }

  @override
  Future<String> completeOnboarding({
    required String userId,
    required String requestId,
    required String title,
    required Map<String, Object?> profile,
  }) async {
    _check();
    if (userId != ownerId) throw StateError('Onboarding owner changed');
    final existing = storage.getString(_completionKey);
    if (existing != null && existing != 'completed') return existing;
    String selected(String key) => _strings(profile[key]).join(' / ');
    final id = await _create(
      V2Session(
        id: '',
        title: title.trim(),
        kind: V2SessionKind.project,
        members: const ['popi'],
        roles: const [],
        messages: const [],
        direction: selected('contentDirections'),
        positioning: selected('presentationFormats'),
        accountPreferences: {
          'feeling': selected('audienceFeelings'),
          'format': selected('creativeConstraints'),
          'audience': selected('targetAudience'),
        },
      ),
      requestId: requestId,
    );
    await storage.setString(_completionKey, id);
    _check();
    _completed = true;
    return id;
  }

  Map<String, Object?> _configuration(V2Session s) {
    Map<String, Object?> memberMap(Object? value) => {
      for (final entry in _map(value).entries)
        if (s.members.contains(entry.key)) entry.key: entry.value,
    };
    return {
      ...s.configuration,
      'members': s.members,
      'roles': s.roles,
      'capabilities': s.capabilities,
      'direction': s.direction,
      'positioning': s.positioning,
      'accountPreferences': s.accountPreferences,
      'memberNames': memberMap(s.memberNames),
      'memberInstructions': memberMap(s.memberInstructions),
      'memberAvatars': memberMap(s.memberAvatars),
      'memberColors': memberMap(s.memberColors),
      'memberCapabilities': memberMap(s.configuration['memberCapabilities']),
      'memberSkills': memberMap(s.configuration['memberSkills']),
      'memberBotIds': memberMap(s.configuration['memberBotIds']),
      'workMode': s.configuration['workMode'] ?? 'onDemand',
      'activeMemberId': s.members.contains(s.configuration['activeMemberId'])
          ? s.configuration['activeMemberId']
          : s.members.first,
      'roleProfiles': {
        for (final id in s.roles)
          id: _map(s.configuration['roleProfiles'])[id] ?? _roleProfile(id),
      },
    };
  }

  Map<String, Object?> _roleProfile(String id) {
    final role = _roles.where((r) => r['id'] == id).firstOrNull;
    if (role == null) return {};
    return {
      'name': role['name'],
      'instructions': role['instructions'],
      'revision': role['revision'],
      'referenceAssetIds': role['referenceAssetIds'] ?? [],
      'referenceImageUrls': role['referenceImageUrls'] ?? [],
      if (role['binding'] != null) 'binding': role['binding'],
    };
  }

  @override
  Future<void> updateSession(String id, V2Session Function(V2Session) update) {
    // Concurrent settings edits are based on the latest successful revision.
    final operation = (_edits[id] ?? Future.value())
        .catchError((Object _) {})
        .then((_) => _update(id, update));
    _edits[id] = operation;
    return operation;
  }

  Future<void> _update(String id, V2Session Function(V2Session) update) async {
    _check();
    final current = session(id);
    final next = update(current);
    if (next.roles.length > 5 || next.members.isEmpty) {
      throw ArgumentError('Invalid session configuration');
    }
    final config = _configuration(next);
    if (jsonEncode(current.capabilities) != jsonEncode(next.capabilities)) {
      config['memberCapabilities'] = {
        for (final member in next.members) member: next.capabilities,
      };
    }
    final changed = jsonEncode(config) != jsonEncode(_configuration(current));
    if (!changed && next.title == current.title) return;
    final key =
        'update:$id:${current.configRevision}:${next.title}:${jsonEncode(config)}';
    try {
      final record = await api.updateSession(
        id,
        clientRequestId: _request(key),
        title: next.title != current.title ? next.title : null,
        configuration: changed ? config : null,
        expectedConfigRevision: changed ? current.configRevision : null,
      );
      _check();
      final saved = _session(record, fallback: next);
      final latest = session(id);
      if (saved.configRevision >= latest.configRevision &&
          saved.serverRevision >= latest.serverRevision) {
        _replace(
          saved.copyWith(
            messages: latest.messages,
            lastSeq: latest.lastSeq,
            serverRevision: saved.serverRevision > latest.serverRevision
                ? saved.serverRevision
                : latest.serverRevision,
            running: latest.running,
            canStop: latest.canStop,
          ),
        );
      }
      _requests.remove(key);
    } on AgentApiException catch (error) {
      if (error.code == 'config_conflict') {
        _requests.remove(key);
        await refreshSession(id);
      }
      rethrow;
    }
  }

  void _replace(V2Session next) {
    _sessions = _sessions.map((s) => s.id == next.id ? next : s).toList();
    _notify();
  }

  @override
  Future<void> deleteSession(String id) async {
    _check();
    await api.archiveSession(id, clientRequestId: _request('delete:$id'));
    _check();
    _sessionGeneration++;
    _sessions = _sessions.where((s) => s.id != id).toList();
    _watchers.remove(id);
    _requests.remove('delete:$id');
    _notify();
  }

  @override
  Future<void> refreshSession(String id) async {
    _check();
    final serial = ++_serial;
    final assetGeneration = _assetGeneration;
    final snapshot = await api.sessionSnapshot(id);
    _check();
    final current = _sessions.where((s) => s.id == id).firstOrNull;
    if (current == null || serial < (_applied[id] ?? 0)) return;
    var next = _session(_map(snapshot['session']), fallback: current);
    final seq = _integer(snapshot['lastSeq']);
    if (seq < current.lastSeq ||
        next.configRevision < current.configRevision ||
        next.serverRevision < current.serverRevision) {
      return;
    }
    final runs = _maps(snapshot['runs']);
    final accepted = _acceptedRuns[id];
    final acceptedRun = runs.where((r) => r['id'] == accepted).firstOrNull;
    final run = acceptedRun ?? runs.lastOrNull;
    final mediaBusy = _maps(snapshot['mediaJobs']).any(
      (j) =>
          !const {
            'failed',
            'unknown',
            'cancelled',
            'stopped',
          }.contains(j['state']) &&
          (const {
                'submitting',
                'pending',
                'queued',
                'running',
                'processing',
                'ingesting',
              }.contains(j['state']) ||
              const {'pending', 'ingesting'}.contains(j['ingestionState'])),
    );
    final filmBusy = _maps(snapshot['filmJobs']).any(
      (j) =>
          !j['state'].toString().startsWith('failed') &&
          !const {'completed', 'cancelled', 'stopped'}.contains(j['state']),
    );
    final busy = mediaBusy || filmBusy;
    next = next.copyWith(
      messages: _maps(snapshot['messages'])
          .map(
            (m) => V2Message(
              id: m['id'].toString(),
              text: m['text']?.toString() ?? '',
              user: m['role'] == 'user',
              assetIds: _strings(m['assetIds'] ?? m['assets']),
              status: m['status']?.toString() ?? '',
              question: m['question'] is Map
                  ? V2Question.fromJson(_map(m['question']))
                  : null,
            ),
          )
          .toList(),
      lastSeq: seq,
      running:
          (accepted != null && acceptedRun == null) ||
          busy ||
          const {
            'queued',
            'running',
            'waiting',
            'waiting_input',
            'waiting_for_input',
            'waiting_user',
            'stopping',
            'cancel_requested',
          }.contains(run?['state']),
      canStop: run == null
          ? current.canStop
          : const {
                  'queued',
                  'running',
                  'waiting_user',
                  'stopping',
                  'cancel_requested',
                }.contains(run['state']) &&
                (run['filmJobId']?.toString().isEmpty ?? true),
    );
    _applied[id] = serial;
    if (acceptedRun != null) _acceptedRuns.remove(id);
    if (snapshot['assets'] is List && assetGeneration == _assetGeneration) {
      final incoming = _maps(snapshot['assets']).map(_asset).toList();
      _assets = [
        ...incoming,
        ..._assets.where(
          (a) => a.sessionId != id && !incoming.any((n) => n.id == a.id),
        ),
      ];
    }
    _replace(next);
  }

  @override
  Future<void> sendMessage(String id, String text, List<String> assets) async {
    _check();
    if (!_sending.add(id)) throw StateError('Message submission in progress');
    try {
      final selected = assets
          .map((id) => _assets.firstWhere((a) => a.id == id))
          .toList();
      V2UploadFile.validateMessageAttachments(selected);
      final key = 'send:$id:${text.trim()}:${jsonEncode(assets)}';
      final response = await api.sendSessionMessage(
        id,
        clientRequestId: _request(key),
        text: text.trim(),
        mediaIds: assets.isEmpty ? null : assets,
      );
      _check();
      if (response['runId'] is String) {
        _acceptedRuns[id] = response['runId']! as String;
      }
      _requests.remove(key);
      _requests.remove('stop:$id');
      _replace(
        session(id).copyWith(
          running: true,
          canStop: response['jobId']?.toString().isNotEmpty != true,
        ),
      );
      // Acceptance is final for the composer. Poll failures must not resend input.
      unawaited(_poll(id));
      _startPolling();
    } finally {
      _sending.remove(id);
    }
  }

  @override
  Future<void> stopSession(String id) async {
    _check();
    await api.stopSession(id, clientRequestId: _request('stop:$id'));
    _check();
    _requests.remove('stop:$id');
    unawaited(_poll(id));
  }

  @override
  Future<void> respondQuestion(
    String id,
    V2Question question,
    String action,
    Map<String, Object?> answer,
  ) async {
    _check();
    final current = session(id).messages
        .map((m) => m.question)
        .whereType<V2Question>()
        .where((q) => q.id == question.id)
        .firstOrNull;
    if (current == null ||
        !current.isPending ||
        current.revision != question.revision) {
      throw StateError('Question changed');
    }
    final key =
        'question:$id:${question.id}:${question.revision}:$action:${jsonEncode(answer)}';
    await api.respondQuestion(
      id,
      question.id,
      clientRequestId: _request(key),
      revision: question.revision,
      action: action,
      answer: action == 'submit' ? answer : null,
    );
    _check();
    _requests.remove(key);
    unawaited(_poll(id));
  }

  @override
  void watchSession(String id) {
    _watchers[id] = (_watchers[id] ?? 0) + 1;
    unawaited(_poll(id));
    _startPolling();
  }

  @override
  void unwatchSession(String id) {
    final count = (_watchers[id] ?? 1) - 1;
    if (count <= 0) {
      _watchers.remove(id);
    } else {
      _watchers[id] = count;
    }
  }

  void _startPolling() {
    _timer ??= Timer.periodic(pollInterval, (_) {
      for (final s in _sessions) {
        if (_watchers.containsKey(s.id) || s.running) unawaited(_poll(s.id));
      }
    });
  }

  Future<void> _poll(String id) async {
    if (_disposed || !_refreshing.add(id)) return;
    try {
      await refreshSession(id);
      syncError = null;
    } catch (error) {
      if (!_disposed && syncError == null) {
        syncError = error;
        _notify();
      }
    } finally {
      _refreshing.remove(id);
    }
  }

  @override
  Future<void> refreshAssets() async {
    _check();
    final serial = ++_assetSerial;
    final generation = _assetGeneration;
    final response = await api.assets();
    _check();
    if (serial < _assetsApplied || generation != _assetGeneration) return;
    _assetsApplied = serial;
    _assets = _maps(response['list']).map(_asset).toList();
    _notify();
  }

  @override
  Future<V2Asset> uploadFile(V2UploadFile file) async {
    _check();
    if (_uploads[file.clientRequestId] case final saved?) return saved;
    final imported = await api.importBusinessAsset(
      await _uploader.upload(file),
    );
    _check();
    final asset = _asset(_map(imported['asset']));
    _uploads[file.clientRequestId] = asset;
    _assets = [asset, ..._assets.where((a) => a.id != asset.id)];
    _assetGeneration++;
    _notify();
    return asset;
  }

  @override
  Future<void> renameAsset(String id, String title) async {
    _check();
    await api.renameAsset(id, title.trim());
    _check();
    _assetGeneration++;
    _assets = _assets
        .map((a) => a.id == id ? a.copyWith(title: title.trim()) : a)
        .toList();
    _notify();
  }

  @override
  Future<void> deleteAsset(String id) async {
    _check();
    await api.deleteAsset(id);
    _check();
    _assetGeneration++;
    _assets = _assets.where((a) => a.id != id).toList();
    _uploads.removeWhere((_, a) => a.id == id);
    _notify();
  }

  @override
  Future<Uint8List> readAssetBytes(V2Asset asset) async {
    _check();
    final bytes = asset.businessAssetId.isNotEmpty
        ? await api.readBusinessAssetBytes(
            asset.id,
            maxBytes: V2UploadFile.limitFor(
              asset.kind,
              mimeType: asset.mimeType,
            ),
          )
        : await api.readAssetBytes(asset.contentUrl);
    _check();
    if (bytes.length >
        V2UploadFile.limitFor(asset.kind, mimeType: asset.mimeType)) {
      throw const V2UploadException('FILE_TOO_LARGE');
    }
    return bytes;
  }

  @override
  Future<String> readAssetText(V2Asset asset) async {
    _check();
    if (!V2UploadFile.isDocumentMimeType(asset.mimeType)) {
      return utf8.decode(await readAssetBytes(asset), allowMalformed: false);
    }
    final response = await api.assetText(asset.id);
    _check();
    return response['text']?.toString() ?? '';
  }

  @override
  Future<void> refreshRoles() async {
    final roles = <Map<String, Object?>>[];
    for (final category in ['official', 'personal']) {
      for (var page = 1; ; page++) {
        _check();
        final response = await api.libraryRoles(page: page, category: category);
        _check();
        final items = _maps(response['list']);
        roles.addAll(items);
        if (items.isEmpty || page * 100 >= _integer(response['total'])) break;
      }
    }
    _roles = roles;
    _notify();
  }

  @override
  List<V2Character> get characters => _roles.map((r) {
    final images = _strings(r['referenceImageUrls']);
    final refs = _maps(r['references']);
    final source = r['avatarUrl']?.toString().isNotEmpty == true
        ? r['avatarUrl']!.toString()
        : refs.firstOrNull?['contentUrl']?.toString() ??
              images.firstOrNull ??
              '';
    final uri = Uri.tryParse(source);
    final image = uri == null || source.isEmpty
        ? ''
        : Uri.parse(api.dio.options.baseUrl).resolveUri(uri).toString();
    return V2Character(
      r['id'].toString(),
      r['name']?.toString() ?? '',
      image,
      instructions: r['instructions']?.toString() ?? '',
      category: r['category']?.toString() ?? 'personal',
      headers: mediaHeaders(image),
    );
  }).toList();
  @override
  V2Character character(String id) {
    final listed = characters.where((r) => r.id == id).firstOrNull;
    if (listed != null) return listed;
    final profile =
        _sessions
            .map((s) => _map(_map(s.configuration['roleProfiles'])[id]))
            .where((p) => p.isNotEmpty)
            .firstOrNull ??
        {};
    final source = _strings(profile['referenceImageUrls']).firstOrNull ?? '';
    final image = source.isEmpty
        ? ''
        : Uri.parse(api.dio.options.baseUrl).resolve(source).toString();
    return V2Character(
      id,
      profile['name']?.toString() ?? id,
      image,
      instructions: profile['instructions']?.toString() ?? '',
      category: 'personal',
      headers: mediaHeaders(image),
    );
  }

  @override
  Future<V2Character> createRole({
    required String requestId,
    required String name,
    required String instructions,
    required List<V2UploadFile> files,
  }) async {
    _check();
    final created = await api.saveLibraryRole({
      'clientRequestId': requestId,
      'name': '新角色',
    });
    _check();
    var role = _map(created['role']);
    final id = role['id'].toString();
    role = _map((await api.libraryRole(id))['role']);
    final references = <Map<String, Object?>>[];
    for (final file in files) {
      _check();
      final key = 'role:$id:${file.clientRequestId}:revision';
      final revision = _requests.putIfAbsent(
        key,
        () => role['revision'].toString(),
      );
      final result = await api.uploadRoleReference(
        roleId: id,
        requestId: file.clientRequestId,
        revision: revision,
        name: file.name,
        mimeType: file.mimeType,
        bytes: await file.readBytes(),
      );
      final mediaId = _map(result['role'])['uploadedMediaId'];
      if (mediaId is! num || mediaId <= 0) {
        throw const FormatException('Missing reference');
      }
      references.add({'mediaId': mediaId, 'purpose': 'reference'});
      role = _map((await api.libraryRole(id))['role']);
    }
    final payload = {
      'name': name,
      'instructions': instructions,
      'revision': role['revision'],
      'references': references,
    };
    final result = await api.saveLibraryRole({
      ...payload,
      'clientRequestId': _request('role-save:$id:${jsonEncode(payload)}'),
    }, id: id);
    _check();
    role = _map(result['role']);
    _roles = [role, ..._roles.where((r) => r['id'] != id)];
    _notify();
    return character(id);
  }

  V2Session _session(Map<String, Object?> r, {V2Session? fallback}) {
    final c = r['configuration'] is Map
        ? _map(r['configuration'])
        : fallback?.configuration ?? {};
    final members = _strings(c['members']);
    return V2Session(
      id: r['id']?.toString() ?? fallback?.id ?? '',
      title: r['title']?.toString() ?? fallback?.title ?? '',
      kind:
          V2SessionKind.values.where((k) => k.name == r['kind']).firstOrNull ??
          fallback?.kind ??
          V2SessionKind.conversation,
      members: members.isEmpty ? fallback?.members ?? ['popi'] : members,
      roles: _strings(c['roles']),
      messages: fallback?.messages ?? [],
      direction: c['direction']?.toString() ?? '',
      positioning: c['positioning']?.toString() ?? '',
      capabilities: c['capabilities'] is List
          ? _strings(c['capabilities'])
          : const ['character', 'script', 'image'],
      memberNames: _stringMap(c['memberNames']),
      memberInstructions: _stringMap(c['memberInstructions']),
      memberAvatars: _stringMap(c['memberAvatars']),
      memberColors: _map(
        c['memberColors'],
      ).map((k, v) => MapEntry(k, _integer(v))),
      accountPreferences: _stringMap(c['accountPreferences']),
      configuration: c,
      configRevision: _integer(
        r['configRevision'],
        fallback?.configRevision ?? 0,
      ),
      serverRevision: _integer(r['revision'], fallback?.serverRevision ?? 0),
      lastSeq: fallback?.lastSeq ?? 0,
      running: fallback?.running ?? false,
      canStop: fallback?.canStop ?? true,
    );
  }

  V2Asset _asset(Map<String, Object?> r) {
    final id = r['id'].toString();
    final kind = V2AssetKind.values.byName(r['kind'].toString());
    final owned = api.resolveAssetContentUrl(
      r['contentUrl']?.toString() ?? r['contentPath']?.toString() ?? '',
    );
    if (Uri.parse(owned).path != '/api_agent/v2/assets/$id/content') {
      throw const FormatException('Asset content does not match its ID');
    }
    final business = r['businessAssetId']?.toString() ?? '';
    final content = business.isNotEmpty && r['access'] is Map
        ? api.resolveBusinessAccessUrl(r['access'])
        : owned;
    var cover = kind == V2AssetKind.image ? content : '';
    if (kind == V2AssetKind.video) {
      cover = business.isNotEmpty
          ? api.resolveBusinessPosterUrl(r['access'])
          : '';
      if (cover.isEmpty && r['posterUrl'] is String) {
        final poster = api.resolveAssetPosterUrl(r['posterUrl']! as String);
        if (Uri.parse(poster).path == '/api_agent/v2/assets/$id/poster') {
          cover = poster;
        }
      }
    }
    return V2Asset(
      id: id,
      title: r['title']?.toString() ?? '',
      kind: kind,
      cover: cover,
      contentUrl: content,
      businessAssetId: business,
      media: kind == V2AssetKind.video || kind == V2AssetKind.audio
          ? content
          : '',
      mimeType: r['mimeType']?.toString() ?? '',
      sizeBytes: _integer(r['sizeBytes']),
      durationSeconds: (r['durationSeconds'] as num?)?.toDouble() ?? 0,
      sessionId: r['sessionId']?.toString(),
      headers: mediaHeaders(content),
    );
  }

  @override
  Future<void> importSample(V2AssetKind kind) =>
      throw UnsupportedError('Choose a file to upload');
  @override
  Future<void> reset() => throw UnsupportedError('Remote data cannot be reset');
  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _uploader.dispose();
    api.close();
    super.dispose();
  }
}

Map<String, Object?> _map(Object? value) =>
    value is Map ? Map<String, Object?>.from(value) : {};
List<Map<String, Object?>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map((m) => Map<String, Object?>.from(m)).toList()
    : [];
List<String> _strings(Object? value) =>
    value is List ? value.map((v) => v.toString()).toList() : [];
Map<String, String> _stringMap(Object? value) =>
    _map(value).map((k, v) => MapEntry(k, v.toString()));
int _integer(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : fallback;
