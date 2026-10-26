import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'list_page_fixtures.dart';
export 'list_page_fixtures.dart';
import 'package:popi_ai_app/features/assets/domain/library_work.dart';
import 'package:popi_ai_app/features/session/data/conversation_events.dart';
import 'package:popi_ai_app/features/session/data/session_repository.dart';
import 'package:popi_ai_app/features/session/domain/conversation_session.dart';
import 'package:popi_ai_app/features/session/domain/conversation_snapshot.dart';
import 'package:popi_ai_app/features/session/domain/conversation_generation.dart';
import 'package:popi_ai_app/features/role_guide/domain/home_creation.dart';
import 'package:popi_ai_app/features/role_guide/domain/session_media_preferences.dart';

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
    return SessionRepository.sorted(sessions);
  }

  @override
  Future<ConversationSessionPage> list(
    String userId, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    final items = _list(userId);
    return ConversationSessionPage(
      items: items.skip((page - 1) * pageSize).take(pageSize).toList(),
      page: page,
      pageCount: (items.length / pageSize).ceil().clamp(1, 10000),
    );
  }

  @override
  Future<ConversationSession> createFromContent(
    String userId, {
    CancelToken? cancelToken,
  }) async {
    final session = ConversationSession(
      id: 'mock-new-${++_nextId}',
      title: '新会话',
      updatedAt: DateTime.now(),
      createdAt: DateTime.now(),
      bindingStatus: 'ready',
    );
    _list(userId);
    _accounts[userId]!.add(session);
    return session;
  }

  @override
  Future<ConversationSession> create(
    String userId,
    String? title, {
    CancelToken? cancelToken,
  }) async {
    final session = ConversationSession(
      id: 'mock-new-${++_nextId}',
      title: _validateTitle(title ?? '新会话'),
      updatedAt: DateTime.now(),
      createdAt: DateTime.now(),
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
        createdAt: session.createdAt,
        lastMessageAt: session.lastMessageAt,
        revision: session.revision + 1,
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
      createdAt: session.createdAt,
      lastMessageAt: session.lastMessageAt,
      revision: session.revision + 1,
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
        createdAt: previous.createdAt,
        lastMessageAt: previous.lastMessageAt,
        revision: previous.revision + 1,
        archived: true,
      );
    }
    return _list(userId).firstWhere((item) => item.id == id);
  }

  @override
  Future<ConversationSnapshot> snapshot(
    String id, {
    CancelToken? cancelToken,
  }) async {
    final known = _accounts.values
        .expand((items) => items)
        .where((item) => item.id == id)
        .firstOrNull;
    return ConversationSnapshot.fromJson({
      'session': {
        'id': id,
        'title': known?.title ?? 'New session',
        'revision': known?.revision ?? 1,
        'updatedAt': (known?.updatedAt ?? DateTime.now()).toIso8601String(),
        'createdAt': known?.createdAt?.toIso8601String(),
        'lastMessageAt': known?.lastMessageAt?.toIso8601String(),
        'pinnedAt': known?.pinnedAt?.toIso8601String(),
        'bindingStatus': known?.bindingStatus ?? 'pending',
      },
      'lastSeq': 0,
      'messages': [],
      'runs': [],
    });
  }

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
  Future<void> updateCast(
    String userId,
    String id,
    List<String> roleIds, {
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
    String? sessionId,
    CancelToken? cancelToken,
  }) async {}
  @override
  Future<String> upload(
    String userId,
    String name,
    Uint8List bytes, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
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

  @override
  Future<void> topicAction(
    String userId,
    String sessionId,
    ConversationBlock topic, {
    bool refresh = false,
    CancelToken? cancelToken,
  }) async {}
  @override
  Future<ConversationGenerationOptions> generationOptions(
    String userId,
    String sessionId,
    ConversationBlock card, {
    CancelToken? cancelToken,
  }) async => ConversationGenerationOptions(
    models: [
      HomeModel.fromJson({
        'id': 'model',
        'name': 'Model',
        'available': true,
        'mediaType': card.mediaType.isEmpty ? 'video' : card.mediaType,
        'parameters': [],
      }),
    ],
    preferences: SessionMediaPreferences.fromJson({
      'revision': 1,
      'video': {'modelId': 'model', 'params': {}},
      'image': {
        'modelId': 'model',
        'params': {'ratio': '16:9'},
      },
    }),
  );
  @override
  Future<num> estimateGeneration(
    String mediaType,
    HomeConfig config, {
    CancelToken? cancelToken,
  }) async => 10;
  @override
  Future<ListPage<ConversationRoleTemplate>> roleTemplates({
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async => fixturePage([], page: page, pageSize: pageSize);
  @override
  Future<void> confirmGeneration(
    String userId,
    String sessionId,
    ConversationBlock card,
    ConversationGenerationSelection selection, {
    CancelToken? cancelToken,
  }) async {}
  @override
  Future<Map<String, Object?>> taskCapabilities(
    String id, {
    CancelToken? cancelToken,
  }) async => {
    'revision': 1,
    'allowedActions': ['pause', 'cancel'],
  };
  @override
  Future<void> controlTask(
    String userId,
    ConversationBlock task,
    String action, {
    Map<String, Object?>? capabilities,
    CancelToken? cancelToken,
  }) async {}
  @override
  Future<void> respondProposal(
    String userId,
    ConversationBlock task,
    Map<String, Object?> proposal,
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
          createdAt: now.subtract(Duration(hours: index + 1)),
          lastMessageAt: now.subtract(Duration(hours: index + 1)),
          pinnedAt: index == 0 ? now : null,
        ),
    ];
  }
}
