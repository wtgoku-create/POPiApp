import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/preferences_storage.dart';
import '../domain/demo_models.dart';
import 'demo_fixtures.dart';

/// A local, transactional store isolated from account data and network services.
class DemoRepository extends ChangeNotifier {
  DemoRepository(this._storage);
  static const storageKey = 'popi_ui_demo_v1';
  final PreferencesStorage _storage;
  List<DemoSession> _sessions = DemoFixtures.sessions();
  List<DemoAsset> _assets = DemoFixtures.assets();
  Future<void> _pending = Future.value();
  List<DemoSession> get sessions => List.unmodifiable(_sessions);
  List<DemoAsset> get assets => List.unmodifiable(_assets);
  DemoSession session(String id) => _sessions.firstWhere((s) => s.id == id);

  void restore() {
    final raw = _storage.getString(storageKey);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, Object?>;
      final sessions = (json['sessions'] as List)
          .map((s) => DemoSession.fromJson(Map<String, Object?>.from(s as Map)))
          .toList();
      final assets = (json['assets'] as List)
          .map((a) => DemoAsset.fromJson(Map<String, Object?>.from(a as Map)))
          .toList();
      if (sessions.map((s) => s.id).toSet().length != sessions.length ||
          assets.map((a) => a.id).toSet().length != assets.length) {
        throw const FormatException('Duplicate demo identifiers');
      }
      _sessions = sessions;
      _assets = assets;
    } catch (_) {
      // A stale or incomplete demo snapshot falls back to the bundled fixtures.
      _sessions = DemoFixtures.sessions();
      _assets = DemoFixtures.assets();
    }
  }

  // Serialize edits so overlapping actions cannot replace a newer snapshot.
  Future<void> _commit(
    ({List<DemoSession> sessions, List<DemoAsset> assets}) Function() change,
  ) {
    final operation = _pending.then((_) async {
      final next = change();
      await _storage.setString(
        storageKey,
        jsonEncode({
          'sessions': next.sessions.map((s) => s.toJson()).toList(),
          'assets': next.assets.map((a) => a.toJson()).toList(),
        }),
      );
      _sessions = next.sessions;
      _assets = next.assets;
      notifyListeners();
    });
    _pending = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> updateSession(
    String id,
    DemoSession Function(DemoSession) update,
  ) => _commit(
    () => (
      sessions: _sessions.map((s) => s.id == id ? update(s) : s).toList(),
      assets: _assets,
    ),
  );

  Future<String> createSession(String title, DemoSessionKind kind) async {
    final id = const Uuid().v4();
    await _commit(
      () => (
        sessions: [
          DemoSession(
            id: id,
            title: title.trim(),
            kind: kind,
            members: kind == DemoSessionKind.workflow
                ? ['popi', 'writer', 'director']
                : ['popi'],
            roles: const [],
            messages: const [],
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

  Future<void> addMessage(String sessionId, DemoMessage message) =>
      updateSession(
        sessionId,
        (s) =>
            s.copyWith(messages: [...s.messages, message], unread: 0, time: ''),
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
  Future<void> importSample(DemoAssetKind kind) => _commit(() {
    final a = DemoFixtures.assets().firstWhere((a) => a.kind == kind);
    return (
      sessions: _sessions,
      assets: [
        DemoAsset(
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
    () => (sessions: DemoFixtures.sessions(), assets: DemoFixtures.assets()),
  );
}
