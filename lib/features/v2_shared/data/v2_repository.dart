import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/preferences_storage.dart';
import '../domain/v2_models.dart';
import 'v2_fixtures.dart';

/// A local, transactional store isolated from account data and network services.
class V2Repository extends ChangeNotifier {
  V2Repository(this._storage);
  static const storageKey = 'popi_ui_demo_v1';
  final PreferencesStorage _storage;
  List<V2Session> _sessions = V2Fixtures.sessions();
  List<V2Asset> _assets = V2Fixtures.assets();
  Map<String, String> _onboardingSessions = {};
  Future<void> _pending = Future.value();
  List<V2Session> get sessions => List.unmodifiable(_sessions);
  List<V2Asset> get assets => List.unmodifiable(_assets);
  V2Session session(String id) => _sessions.firstWhere((s) => s.id == id);
  bool hasCompletedOnboarding(String userId) =>
      _onboardingSessions.containsKey(userId);

  void restore() {
    final raw = _storage.getString(storageKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      final sessions = (json['sessions'] as List)
          .map((s) => V2Session.fromJson(Map<String, Object?>.from(s as Map)))
          .toList();
      final assets = (json['assets'] as List)
          .map((a) => V2Asset.fromJson(Map<String, Object?>.from(a as Map)))
          .toList();
      final onboardingSessions = Map<String, String>.from(
        json['onboardingSessions'] as Map? ?? {},
      );
      if (sessions.map((s) => s.id).toSet().length != sessions.length ||
          assets.map((a) => a.id).toSet().length != assets.length) {
        throw const FormatException('Duplicate demo identifiers');
      }
      _sessions = sessions;
      _assets = assets;
      _onboardingSessions = onboardingSessions;
    } catch (_) {
      // A stale or incomplete demo snapshot falls back to the bundled fixtures.
      _sessions = V2Fixtures.sessions();
      _assets = V2Fixtures.assets();
    }
  }

  // Serialize edits so overlapping actions cannot replace a newer snapshot.
  Future<void> _commit(
    ({List<V2Session> sessions, List<V2Asset> assets}) Function() change, {
    MapEntry<String, String>? onboardingSession,
  }) {
    final operation = _pending.then((_) async {
      final next = change();
      final onboardingSessions = {
        ..._onboardingSessions,
        if (onboardingSession != null &&
            !_onboardingSessions.containsKey(onboardingSession.key))
          onboardingSession.key: onboardingSession.value,
      };
      await _storage.setString(
        storageKey,
        jsonEncode({
          'sessions': next.sessions.map((s) => s.toJson()).toList(),
          'assets': next.assets.map((a) => a.toJson()).toList(),
          'onboardingSessions': onboardingSessions,
        }),
      );
      _sessions = next.sessions;
      _assets = next.assets;
      _onboardingSessions = onboardingSessions;
      notifyListeners();
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> updateSession(String id, V2Session Function(V2Session) update) =>
      _commit(
        () => (
          sessions: _sessions.map((s) => s.id == id ? update(s) : s).toList(),
          assets: _assets,
        ),
      );

  Future<String> createSession(
    String title,
    V2SessionKind kind, {
    Map<String, String> memberNames = const {},
    Map<String, String> memberInstructions = const {},
    Map<String, String> memberAvatars = const {},
    Map<String, int> memberColors = const {},
  }) async {
    final id = const Uuid().v4();
    await _commit(
      () => (
        sessions: [
          V2Session(
            id: id,
            title: title.trim(),
            kind: kind,
            members: kind == V2SessionKind.workflow
                ? ['popi', 'writer', 'director']
                : ['popi'],
            roles: const [],
            messages: const [],
            memberNames: Map.of(memberNames),
            memberInstructions: Map.of(memberInstructions),
            memberAvatars: Map.of(memberAvatars),
            memberColors: Map.of(memberColors),
          ),
          ..._sessions,
        ],
        assets: _assets,
      ),
    );
    return id;
  }

  Future<void> deleteSession(String id) => _commit(
    () => (
      sessions: _sessions.where((s) => s.id != id).toList(),
      assets: _assets,
    ),
  );

  /// Commits the first session and account completion marker atomically.
  Future<String> completeOnboarding({
    required String userId,
    required String requestId,
    required String title,
    required Map<String, Object?> profile,
  }) async {
    String selected(String key) => (profile[key] as List<String>).join(' / ');
    var id = requestId;
    await _commit(() {
      final existing = _onboardingSessions[userId];
      if (existing != null) {
        id = existing;
        return (sessions: _sessions, assets: _assets);
      }
      return (
        sessions: [
          V2Session(
            id: id,
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
          ..._sessions,
        ],
        assets: _assets,
      );
    }, onboardingSession: MapEntry(userId, requestId));
    return id;
  }

  Future<void> addMessage(String sessionId, V2Message message) => updateSession(
    sessionId,
    (s) => s.copyWith(messages: [...s.messages, message], unread: 0, time: ''),
  );

  /// Deterministic local results stand in for the future Agent service.
  Future<void> reply(
    String sessionId,
    String prompt, {
    required String text,
    required String imageText,
    required String scriptText,
    required String audioText,
    required String videoText,
  }) async {
    final lower = prompt.toLowerCase();
    final kind = RegExp(r'视频|成片|video').hasMatch(lower)
        ? V2AssetKind.video
        : RegExp(r'音乐|音频|配音|audio|music').hasMatch(lower)
        ? V2AssetKind.audio
        : RegExp(r'脚本|分镜|script').hasMatch(lower)
        ? V2AssetKind.script
        : RegExp(r'图|场景|image|picture').hasMatch(lower)
        ? V2AssetKind.image
        : null;
    final batch = RegExp(r'批量|五|5|batch').hasMatch(lower);
    final sources = kind == null
        ? <V2Asset>[]
        : V2Fixtures.assets().where((a) => a.kind == kind).toList();
    final selected = kind == V2AssetKind.image && batch
        ? sources.where((a) => a.id.startsWith('scene')).toList()
        : sources.take(1).toList();
    final generated = selected
        .map(
          (a) => V2Asset(
            id: const Uuid().v4(),
            title: a.title,
            kind: a.kind,
            cover: a.cover,
            body: a.body,
            media: a.media,
            sessionId: sessionId,
          ),
        )
        .toList();
    final replyText = switch (kind) {
      V2AssetKind.image => imageText,
      V2AssetKind.video => videoText,
      V2AssetKind.script => scriptText,
      V2AssetKind.audio => audioText,
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
                        V2Message(
                          id: const Uuid().v4(),
                          text: replyText,
                          assetIds: generated.map((a) => a.id).toList(),
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

  Future<void> renameAsset(String id, String title) => _commit(
    () => (
      sessions: _sessions,
      assets: _assets
          .map((a) => a.id == id ? a.copyWith(title: title.trim()) : a)
          .toList(),
    ),
  );
  Future<void> deleteAsset(String id) => _commit(
    () => (
      sessions: _sessions,
      assets: _assets.where((a) => a.id != id).toList(),
    ),
  );
  Future<void> importSample(V2AssetKind kind) => _commit(() {
    final a = V2Fixtures.assets().firstWhere((a) => a.kind == kind);
    return (
      sessions: _sessions,
      assets: [
        V2Asset(
          id: const Uuid().v4(),
          title: a.title,
          kind: kind,
          cover: a.cover,
          body: a.body,
          media: a.media,
        ),
        ..._assets,
      ],
    );
  });
  Future<void> reset() => _commit(
    () => (sessions: V2Fixtures.sessions(), assets: V2Fixtures.assets()),
  );
}
