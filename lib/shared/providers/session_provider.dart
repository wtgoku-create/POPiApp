import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_agent_api.dart';
import '../../core/network/network_api.dart';
import '../../features/session/data/session_repository.dart';
import '../../features/session/domain/conversation_session.dart';
import 'network_provider.dart';
import 'storage_provider.dart';
import 'user_provider.dart';

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => ApiSessionRepository(
    NetworkAgentApi(ref.watch(agentDioProvider)),
    NetworkApi(ref.watch(dioProvider)),
    () => ref.read(preferencesStorageProvider),
  ),
);

final sessionsProvider =
    AsyncNotifierProvider<SessionsController, List<ConversationSession>>(
      SessionsController.new,
    );

/// Shared history cancels obsolete requests when the signed-in account changes.
class SessionsController extends AsyncNotifier<List<ConversationSession>> {
  CancelToken? _token;
  bool _mutating = false;
  int _generation = 0;

  @override
  Future<List<ConversationSession>> build() async {
    final userId = ref.watch(userProvider.select((user) => user?.id));
    final repository = ref.watch(sessionRepositoryProvider);
    _generation++;
    _mutating = false;
    final token = CancelToken();
    _token = token;
    ref.onDispose(token.cancel);
    if (userId == null) return const [];
    return repository.list(userId, cancelToken: token);
  }

  Future<ConversationSession?> create(String title) => _mutate(
    (repository, userId, token) =>
        repository.create(userId, title, cancelToken: token),
  );

  Future<void> rename(String id, String title) async {
    await _mutate(
      (repository, userId, token) =>
          repository.update(userId, id, title: title, cancelToken: token),
    );
  }

  Future<void> setPinned(String id, bool pinned) async {
    await _mutate(
      (repository, userId, token) =>
          repository.update(userId, id, pinned: pinned, cancelToken: token),
    );
  }

  Future<void> delete(String id) async {
    await _mutate(
      (repository, userId, token) =>
          repository.update(userId, id, archived: true, cancelToken: token),
    );
  }

  void upsert(ConversationSession session) {
    final items = state.valueOrNull;
    if (items == null) return;
    state = AsyncData(
      SessionRepository.sorted([
        ...items.where((item) => item.id != session.id),
        session,
      ]),
    );
  }

  Future<ConversationSession?> _mutate(
    Future<ConversationSession> Function(SessionRepository, String, CancelToken)
    action,
  ) async {
    final userId = ref.read(userProvider)?.id;
    if (userId == null) throw StateError('Sign in required');
    if (_mutating) throw StateError('Session mutation already pending');
    final generation = _generation;
    _mutating = true;
    final token = _token ?? CancelToken();
    try {
      final session = await action(
        ref.read(sessionRepositoryProvider),
        userId,
        token,
      );
      if (generation != _generation || ref.read(userProvider)?.id != userId) {
        return null;
      }
      upsert(session);
      if (!state.hasValue) ref.invalidateSelf();
      return session;
    } catch (_) {
      if (generation != _generation || ref.read(userProvider)?.id != userId) {
        return null;
      }
      rethrow;
    } finally {
      if (generation == _generation) _mutating = false;
    }
  }
}
