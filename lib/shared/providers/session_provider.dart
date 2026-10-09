import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/session/data/mock_session_repository.dart';
import '../../features/session/domain/conversation_session.dart';
import 'user_provider.dart';

final sessionRepositoryProvider = Provider<MockSessionRepository>(
  (ref) => MockSessionRepository(),
);

final sessionsProvider =
    NotifierProvider<SessionsController, List<ConversationSession>>(
      SessionsController.new,
    );

/// Shares mock conversations across pages without calling the project APIs.
class SessionsController extends Notifier<List<ConversationSession>> {
  @override
  List<ConversationSession> build() {
    final userId = ref.watch(userProvider.select((user) => user?.id));
    final repository = ref.watch(sessionRepositoryProvider);
    return userId == null ? const [] : repository.list(userId);
  }

  String get _userId =>
      ref.read(userProvider)?.id ?? (throw StateError('Sign in required'));

  ConversationSession create(String title) {
    final repository = ref.read(sessionRepositoryProvider);
    final userId = _userId;
    final session = repository.create(userId, title);
    state = repository.list(userId);
    return session;
  }

  void rename(String id, String title) =>
      _mutate((repository, userId) => repository.rename(userId, id, title));

  void setPinned(String id, bool pinned) =>
      _mutate((repository, userId) => repository.setPinned(userId, id, pinned));

  void delete(String id) =>
      _mutate((repository, userId) => repository.delete(userId, id));

  void _mutate(void Function(MockSessionRepository, String) action) {
    final userId = _userId;
    final repository = ref.read(sessionRepositoryProvider);
    action(repository, userId);
    state = repository.list(userId);
  }
}
