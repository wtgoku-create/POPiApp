import '../domain/conversation_session.dart';

/// Temporary account-scoped data until the new conversation API is available.
/// Changes survive drawer reopening, but reset when the application restarts.
class MockSessionRepository {
  final _accounts = <String, List<ConversationSession>>{};
  int _nextId = 0;

  List<ConversationSession> list(String userId) {
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

  ConversationSession create(String userId, String title) {
    final session = ConversationSession(
      id: 'mock-new-${++_nextId}',
      title: _validateTitle(title),
      updatedAt: DateTime.now(),
    );
    list(userId);
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
        avatarAsset: session.avatarAsset,
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
      avatarAsset: session.avatarAsset,
    ),
  );

  void delete(String userId, String id) {
    list(userId);
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
    list(userId);
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
          avatarAsset: 'assets/images/role_guide_avatar_${index + 1}.png',
          updatedAt: now.subtract(Duration(hours: index + 1)),
          pinnedAt: index == 0 ? now : null,
        ),
    ];
  }
}
