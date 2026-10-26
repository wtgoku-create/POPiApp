import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_agent_api.dart';
import '../../core/network/network_api.dart';
import '../../features/session/data/session_repository.dart';
import '../../features/session/domain/conversation_session.dart';
import 'network_provider.dart';
import 'storage_provider.dart';
import 'user_provider.dart';

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  // Session routing metadata belongs to the signed-in account.
  ref.watch(userProvider.select((user) => user?.id));
  final agent = NetworkAgentApi(
    ref.watch(agentDioProvider),
    runtimeDio: ref.watch(runtimeDioProvider),
  );
  ref.onDispose(agent.close);
  return ApiSessionRepository(
    agent,
    NetworkApi(ref.watch(dioProvider)),
    () => ref.read(preferencesStorageProvider),
  );
});

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
  int _pageResetVersion = 0;
  final _known = <String, ConversationSession>{};
  final _insertions = <String>{};
  List<ConversationSession>? _firstPage;
  bool _firstPageHasMore = false;

  int get pageResetVersion => _pageResetVersion;
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
    _known.clear();
    _insertions.clear();
    _firstPage = null;
    _firstPageHasMore = false;
    _pageResetVersion++;
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
    if (token.isCancelled) return const [];
    return _acceptPage(result, append: false);
  }

  Future<ConversationSession?> create([String? title]) => _mutate(
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
    final token = _token ?? CancelToken();
    try {
      final result = await ref
          .read(sessionRepositoryProvider)
          .list(userId, pageSize: pageSize, cancelToken: token);
      if (!token.isCancelled &&
          generation == _generation &&
          ref.read(userProvider)?.id == userId) {
        state = AsyncData(_acceptPage(result, append: false));
      }
    } catch (_) {
      if (generation != _generation || token.isCancelled) {
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
    final nextPage = _page + 1;
    try {
      final result = await ref
          .read(sessionRepositoryProvider)
          .list(userId, page: nextPage, pageSize: pageSize, cancelToken: token);
      if (token.isCancelled ||
          generation != _generation ||
          ref.read(userProvider)?.id != userId) {
        return;
      }
      final merged = _acceptPage(result, append: nextPage > 1);
      _loadingMore = false;
      state = AsyncData(merged);
    } catch (_) {
      if (token.isCancelled || generation != _generation) {
        return;
      }
      rethrow;
    } finally {
      if (generation == _generation && identical(_loadMoreToken, token)) {
        _loadingMore = false;
        state = AsyncData(state.valueOrNull ?? items);
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

  void _setItems(List<ConversationSession> items) {
    state = AsyncData(items);
    if (_loadingMore) {
      state = const AsyncLoading<List<ConversationSession>>().copyWithPrevious(
        state,
        isRefresh: false,
      );
    }
  }

  ConversationSession _remember(ConversationSession incoming) {
    final known = _known[incoming.id];
    return _known[incoming.id] = known == null
        ? incoming
        : known.merge(incoming);
  }

  bool _sameOrder(ConversationSession a, ConversationSession b) =>
      a.isPinned == b.isPinned && a.activityAt.isAtSameMomentAs(b.activityAt);

  /// Preserve the server's page order unless a newer local ordering value exists.
  List<ConversationSession> _acceptPage(
    ConversationSessionPage result, {
    required bool append,
  }) {
    var reorder = false;
    for (final incoming in result.items) {
      final merged = _remember(incoming);
      if (!_sameOrder(incoming, merged)) reorder = true;
      if (incoming.revision >= merged.revision &&
          _sameOrder(incoming, merged)) {
        _insertions.remove(incoming.id);
      }
    }
    final merged = <String, ConversationSession>{};
    for (final item in [if (append) ...?state.valueOrNull, ...result.items]) {
      merged[item.id] = _known[item.id]!;
    }
    if (!append) {
      for (final id in _insertions) {
        if (!merged.containsKey(id)) {
          merged[id] = _known[id]!;
          reorder = true;
        }
      }
    }
    var items = merged.values.where((item) => !item.archived).toList();
    if (reorder) items = SessionRepository.sorted(items);
    _page = result.page;
    _hasMore = result.hasMore || (!append && items.length > pageSize);
    if (!append) {
      items = items.take(pageSize).toList();
      _firstPage = items;
      _firstPageHasMore = _hasMore;
    }
    return List.unmodifiable(items);
  }

  void upsert(ConversationSession session, {bool insertIfMissing = true}) {
    final previous = _known[session.id];
    final merged = _remember(session);
    final interaction = merged.lastMessageAt;
    final newInteraction =
        interaction != null &&
        (previous?.lastMessageAt == null ||
            interaction.isAfter(previous!.lastMessageAt!));
    final orderMutation = previous == null
        ? insertIfMissing
        : previous.isPinned != merged.isPinned ||
              previous.archived != merged.archived;
    if (newInteraction || (orderMutation && !merged.archived)) {
      _insertions.add(session.id);
    }
    // AsyncValue may still retain the previous account's rows during build.
    if (_firstPage == null) return;
    final items = state.valueOrNull;
    if (items == null) return;
    if (newInteraction || orderMutation) _cancelLoadMore();
    if (_page > 1 && (newInteraction || orderMutation)) {
      _returnToFirstPage();
    }
    final visible = state.valueOrNull ?? items;
    final next = [
      for (final item in visible)
        if (item.id != merged.id)
          _known[item.id]!
        else if (!merged.archived)
          merged,
      if (!merged.archived &&
          !visible.any((item) => item.id == merged.id) &&
          (newInteraction || insertIfMissing))
        merged,
    ];
    final reordered = newInteraction || orderMutation
        ? SessionRepository.sorted(next)
        : next;
    _hasMore = _hasMore || (_page <= 1 && reordered.length > pageSize);
    _setItems(
      List.unmodifiable(_page <= 1 ? reordered.take(pageSize) : reordered),
    );
    if (_page <= 1 && _firstPage != null) {
      _firstPage = state.valueOrNull;
      _firstPageHasMore = _hasMore;
    } else if (_firstPage != null) {
      _firstPage = [
        for (final item in _firstPage!)
          if (!_known[item.id]!.archived) _known[item.id]!,
      ];
    }
    if (orderMutation) {
      // Pinning, creation and deletion change page offsets; reconcile on paging.
      _page = 0;
      _hasMore = true;
    }
  }

  void _returnToFirstPage() {
    _pageResetVersion++;
    final cached = _firstPage;
    if (cached == null) {
      _page = 0;
      _hasMore = true;
      // Automatic recovery retains existing data if the network is unavailable.
      unawaited(refresh().catchError((Object _) {}));
      return;
    }
    _page = 1;
    _hasMore = _firstPageHasMore;
    _setItems([
      for (final item in cached)
        if (!_known[item.id]!.archived) _known[item.id]!,
    ]);
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
