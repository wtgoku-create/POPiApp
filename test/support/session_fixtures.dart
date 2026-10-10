import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:popi_ai_app/features/assets/domain/library_work.dart';
import 'package:popi_ai_app/features/session/data/conversation_events.dart';
import 'package:popi_ai_app/features/session/data/session_repository.dart';
import 'package:popi_ai_app/features/session/domain/conversation_session.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';

/// Temporary account-scoped data until the new conversation API is available.
/// Changes survive drawer reopening, but reset when the application restarts.
class FixtureSessionRepository extends SessionRepository {
  final _accounts = <String, List<ConversationSession>>{};
  int _nextId = 0;

  @override
  Future<String> importLibraryWork(
    String userId,
    LibraryWork work, {
    CancelToken? cancelToken,
  }) async => 'media-${work.id}';

  List<ConversationSession> _list(String userId) {
    final sessions = [..._accounts.putIfAbsent(userId, _samples)];
    sessions.sort((a, b) {
      final aPin = a.pinnedAt;
      final bPin = b.pinnedAt;
      if (aPin != null && bPin == null) return -1;
      if (aPin == null && bPin != null) return 1;
      return (bPin ?? b.updatedAt).compareTo(aPin ?? a.updatedAt);
    });
    return List.unmodifiable(sessions);
  }

  @override
  Future<List<ConversationSession>> list(
    String userId, {
    CancelToken? cancelToken,
  }) async => _list(userId);

  @override
  Future<ConversationSession> create(
    String userId,
    String title, {
    CancelToken? cancelToken,
  }) async {
    final session = ConversationSession(
      id: 'mock-new-${++_nextId}',
      title: _validateTitle(title),
      updatedAt: DateTime.now(),
    );
    _list(userId);
    _accounts[userId]!.add(session);
    return session;
  }

  void rename(String userId, String id, String title) {
    final name = _validateTitle(title);
    _update(
      userId,
      id,
      (session) => ConversationSession(
        id: session.id,
        title: name,
        updatedAt: DateTime.now(),
        pinnedAt: session.pinnedAt,
        avatarIcon: session.avatarIcon,
      ),
    );
  }

  void setPinned(String userId, String id, bool pinned) => _update(
    userId,
    id,
    (session) => ConversationSession(
      id: session.id,
      title: session.title,
      updatedAt: session.updatedAt,
      pinnedAt: pinned ? DateTime.now() : null,
      avatarIcon: session.avatarIcon,
    ),
  );

  void delete(String userId, String id) {
    _list(userId);
    if (!_accounts[userId]!.any((session) => session.id == id)) {
      throw StateError('Conversation no longer exists');
    }
    _accounts[userId]!.removeWhere((session) => session.id == id);
  }

  void _update(
    String userId,
    String id,
    ConversationSession Function(ConversationSession) update,
  ) {
    _list(userId);
    final sessions = _accounts[userId]!;
    final index = sessions.indexWhere((session) => session.id == id);
    if (index < 0) throw StateError('Conversation no longer exists');
    sessions[index] = update(sessions[index]);
  }

  String _validateTitle(String title) {
    final name = title.trim();
    if (name.isEmpty || name.runes.length > 200) {
      throw ArgumentError.value(title, 'title');
    }
    return name;
  }

  @override
  Future<ConversationSession> update(
    String userId,
    String id, {
    String? title,
    bool? pinned,
    bool? archived,
    CancelToken? cancelToken,
  }) async {
    final previous = _list(userId).firstWhere((item) => item.id == id);
    if (title != null) rename(userId, id, title);
    if (pinned != null) setPinned(userId, id, pinned);
    if (archived == true) {
      delete(userId, id);
      return ConversationSession(
        id: id,
        title: previous.title,
        updatedAt: previous.updatedAt,
        archived: true,
      );
    }
    return _list(userId).firstWhere((item) => item.id == id);
  }

  @override
  Future<ConversationSnapshot> snapshot(
    String id, {
    CancelToken? cancelToken,
  }) async => ConversationSnapshot.fromJson({
    'session': {
      'id': id,
      'title':
          _accounts.values
              .expand((items) => items)
              .where((item) => item.id == id)
              .firstOrNull
              ?.title ??
          'New session',
      'revision': 1,
      'updatedAt': DateTime.now().toIso8601String(),
    },
    'lastSeq': 0,
    'messages': [],
    'runs': [],
  });

  @override
  Stream<ConversationEvent> events(
    String id,
    int afterSeq,
    CancelToken cancelToken, {
    void Function()? onConnected,
  }) {
    final stream = StreamController<ConversationEvent>();
    onConnected?.call();
    cancelToken.whenCancel.then((_) => stream.close());
    return stream.stream;
  }

  @override
  Future<void> send(
    String userId,
    String id,
    String text,
    List<String> mediaIds, {
    List<String> roleIds = const [],
    CancelToken? cancelToken,
  }) async {}
  @override
  Future<void> stop(
    String userId,
    String id, {
    CancelToken? cancelToken,
  }) async {}
  @override
  Future<void> retry(
    String userId,
    String runId, {
    CancelToken? cancelToken,
  }) async {}
  @override
  Future<String> upload(
    String userId,
    String name,
    Uint8List bytes, {
    CancelToken? cancelToken,
  }) async => '801';
  @override
  Future<ConversationMedia> media(
    String id, {
    CancelToken? cancelToken,
  }) async => ConversationMedia(
    id: id,
    kind: 'image',
    url: 'https://example.com/image.png',
  );
  @override
  Future<void> answer(
    String id,
    ConversationBlock question,
    String action,
    Map<String, Object?> answer, {
    CancelToken? cancelToken,
  }) async {}
  @override
  Future<void> confirm(
    String userId,
    String id,
    ConversationBlock card,
    String action, {
    CancelToken? cancelToken,
  }) async {}

  List<ConversationSession> _samples() {
    final now = DateTime.now();
    return [
      for (final (index, title) in const [
        '也许他还记得那些曾经说过的话...',
        '校园野餐vlog',
        '开心的国庆假期出游',
        '艾露尼斯他木心',
        '请停止这一切',
        '没什么大不了',
        '采蘑菇的小女孩',
        '周末旅行的灵感',
      ].indexed)
        ConversationSession(
          id: 'mock-${index + 1}',
          title: title,
          avatarIcon: switch (index) {
            0 => 'home_drawer_session_pink',
            1 => 'home_drawer_session_blue',
            2 => 'home_drawer_session_peach',
            _ => 'home_drawer_session_neutral',
          },
          updatedAt: now.subtract(Duration(hours: index + 1)),
          pinnedAt: index == 0 ? now : null,
        ),
    ];
  }
}
