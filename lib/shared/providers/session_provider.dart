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
  static const pageSize = 20;
  CancelToken? _token;
  CancelToken? _loadMoreToken;
  bool _mutating = false;
  bool _refreshing = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 0;
  int _generation = 0;

  bool get hasMore => _hasMore;
  bool get loadingMore => state.isLoading && _loadingMore;
  bool get initialLoading => state.isLoading && !_loadingMore;

  @override
  Future<List<ConversationSession>> build() async {
    final userId = ref.watch(userProvider.select((user) => user?.id));
    final repository = ref.watch(sessionRepositoryProvider);
    _generation++;
    _mutating = false;
    _refreshing = false;
    _loadingMore = false;
    _loadMoreToken?.cancel();
    _page = 0;
    _hasMore = false;
    final token = CancelToken();
    _token = token;
    ref.onDispose(() {
      _generation++;
      token.cancel();
      _loadMoreToken?.cancel();
    });
    if (userId == null) return const [];
    final result = await repository.list(
      userId,
      pageSize: pageSize,
      cancelToken: token,
    );
    if (!token.isCancelled) {
      _page = result.page;
      _hasMore = result.hasMore;
    }
    return result.items;
  }

  Future<ConversationSession?> create(String title) => _mutate(
    (repository, userId, token) =>
        repository.create(userId, title, cancelToken: token),
  );

  Future<ConversationSession?> createFromContent() => _mutate(
    (repository, userId, token) =>
        repository.createFromContent(userId, cancelToken: token),
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

  Future<void> refresh() async {
    final userId = ref.read(userProvider)?.id;
    if (userId == null || _refreshing || _mutating || initialLoading) return;
    _cancelLoadMore();
    _refreshing = true;
    final generation = _generation;
    final previous = state;
    final token = _token ?? CancelToken();
    try {
      final result = await ref
          .read(sessionRepositoryProvider)
          .list(userId, pageSize: pageSize, cancelToken: token);
      // A refresh must not overwrite a newer account or completed mutation.
      if (!token.isCancelled &&
          generation == _generation &&
          ref.read(userProvider)?.id == userId &&
          identical(state, previous)) {
        _page = result.page;
        _hasMore = result.hasMore;
        state = AsyncData(result.items);
      }
    } catch (_) {
      if (generation != _generation ||
          token.isCancelled ||
          !identical(state, previous)) {
        return;
      }
      rethrow;
    } finally {
      if (generation == _generation) _refreshing = false;
    }
  }

  Future<void> loadMore() async {
    final userId = ref.read(userProvider)?.id;
    final items = state.valueOrNull;
    if (userId == null ||
        items == null ||
        state.isLoading ||
        !_hasMore ||
        _mutating ||
        _refreshing) {
      return;
    }
    final generation = _generation;
    final token = _loadMoreToken = CancelToken();
    _loadingMore = true;
    state = const AsyncLoading<List<ConversationSession>>().copyWithPrevious(
      state,
      isRefresh: false,
    );
    final loading = state;
    try {
      final result = await ref
          .read(sessionRepositoryProvider)
          .list(
            userId,
            page: _page + 1,
            pageSize: pageSize,
            cancelToken: token,
          );
      if (token.isCancelled ||
          generation != _generation ||
          ref.read(userProvider)?.id != userId ||
          !identical(state, loading)) {
        return;
      }
      _page = result.page;
      _hasMore = result.hasMore;
      _loadingMore = false;
      final merged = {
        for (final item in result.items) item.id: item,
        for (final item in items) item.id: item,
      };
      state = AsyncData(SessionRepository.sorted(merged.values));
    } catch (_) {
      if (token.isCancelled ||
          generation != _generation ||
          !identical(state, loading)) {
        return;
      }
      rethrow;
    } finally {
      if (generation == _generation && identical(state, loading)) {
        _loadingMore = false;
        state = AsyncData(items);
      }
      if (identical(_loadMoreToken, token)) _loadMoreToken = null;
    }
  }

  void _cancelLoadMore() {
    final wasLoading = loadingMore;
    _loadMoreToken?.cancel();
    _loadMoreToken = null;
    _loadingMore = false;
    if (wasLoading) state = AsyncData(state.requireValue);
  }

  void upsert(ConversationSession session) {
    final items = state.valueOrNull;
    if (items == null) return;
    _cancelLoadMore();
    // Mutations can shift page offsets. Reconcile from page one on the next pull.
    _page = 0;
    _hasMore = true;
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
    _cancelLoadMore();
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
