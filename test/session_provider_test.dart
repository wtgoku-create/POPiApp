import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/session/domain/conversation_session.dart';
import 'package:popi_ai_app/shared/providers/session_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

import 'support/session_fixtures.dart';

void main() {
  late ProviderContainer container;
  late FixtureSessionRepository repository;
  setUp(() {
    repository = FixtureSessionRepository();
    container = ProviderContainer(
      overrides: [
        userProvider.overrideWith(_TestUserController.new),
        sessionRepositoryProvider.overrideWith((ref) => repository),
      ],
    );
  });
  tearDown(() => container.dispose());
  Future<void> signIn(String id) async {
    await container
        .read(userProvider.notifier)
        .setUser(User(id: id, name: id, email: ''));
    await container.read(sessionsProvider.future);
  }

  test('guest starts empty and cannot mutate server history', () async {
    expect(await container.read(sessionsProvider.future), isEmpty);
    await container.read(sessionsProvider.notifier).refresh();
    await expectLater(
      container.read(sessionsProvider.notifier).create('New'),
      throwsStateError,
    );
  });

  Future<_PagingRepository> preparePages() async {
    final paging = _PagingRepository();
    repository = paging;
    for (var index = 0; index < 37; index++) {
      await paging.create('a', 'History $index');
    }
    await signIn('a');
    return paging;
  }

  test(
    'initial load fetches twenty; further pages append only on demand',
    () async {
      final paging = await preparePages();
      final controller = container.read(sessionsProvider.notifier);
      expect(paging.requests, [(1, 20)]);
      expect(container.read(sessionsProvider).requireValue, hasLength(20));
      expect(controller.hasMore, isTrue);
      final next = await paging.serverPage('a', 2);
      paging.pending = Completer<ConversationSessionPage>();
      final more = controller.loadMore();
      expect(controller.loadingMore, isTrue);
      expect(container.read(sessionsProvider).valueOrNull, hasLength(20));
      await controller.loadMore();
      expect(paging.requests, [(1, 20), (2, 20)]);
      paging.pending!.complete(next);
      await more;
      expect(controller.loadingMore, isFalse);
      expect(container.read(sessionsProvider).requireValue, hasLength(40));
      paging.pending = null;
      await controller.loadMore();
      expect(container.read(sessionsProvider).requireValue, hasLength(45));
      expect(controller.hasMore, isFalse);
      await controller.loadMore();
      expect(paging.requests, [(1, 20), (2, 20), (3, 20)]);
    },
  );

  test('page failures keep visible history and retry the same page', () async {
    final paging = await preparePages();
    final controller = container.read(sessionsProvider.notifier);
    final before = container.read(sessionsProvider).requireValue;
    paging.failNext = true;
    await expectLater(controller.loadMore(), throwsStateError);
    expect(container.read(sessionsProvider).requireValue, same(before));
    expect(controller.hasMore, isTrue);
    expect(controller.loadingMore, isFalse);
    await controller.loadMore();
    expect(paging.requests, [(1, 20), (2, 20), (2, 20)]);
    expect(container.read(sessionsProvider).requireValue, hasLength(40));
    await controller.refresh();
    expect(paging.requests.last, (1, 20));
    expect(container.read(sessionsProvider).requireValue, hasLength(20));
    await controller.loadMore();
    expect(paging.requests.last, (2, 20));
  });

  test(
    'overlapping pages do not duplicate or overwrite visible sessions',
    () async {
      final paging = await preparePages();
      final controller = container.read(sessionsProvider.notifier);
      final before = container.read(sessionsProvider).requireValue;
      final next = await paging.serverPage('a', 2);
      paging.pending = Completer<ConversationSessionPage>();
      final more = controller.loadMore();
      paging.pending!.complete(
        ConversationSessionPage(
          items: [before.first, ...next.items.skip(1)],
          page: 2,
          pageCount: 3,
        ),
      );
      await more;
      final items = container.read(sessionsProvider).requireValue;
      expect(items, hasLength(39));
      expect(items.map((item) => item.id).toSet(), hasLength(39));
      expect(items.first, same(before.first));
    },
  );

  test(
    'account changes cancel pagination and discard the previous account page',
    () async {
      final paging = await preparePages();
      final controller = container.read(sessionsProvider.notifier);
      final next = await paging.serverPage('a', 2);
      paging.pending = Completer<ConversationSessionPage>();
      final pending = paging.pending!;
      final more = controller.loadMore();
      final token = paging.token!;
      paging.pending = null;
      await signIn('b');
      expect(token.isCancelled, isTrue);
      pending.complete(next);
      await more;
      expect(container.read(sessionsProvider).requireValue, hasLength(8));
      expect(controller.hasMore, isFalse);
      expect(controller.loadingMore, isFalse);
    },
  );

  test(
    'refresh cancels a pending page and restarts pagination from page one',
    () async {
      final paging = await preparePages();
      final controller = container.read(sessionsProvider.notifier);
      final next = await paging.serverPage('a', 2);
      paging.pending = Completer<ConversationSessionPage>();
      final pending = paging.pending!;
      final more = controller.loadMore();
      final token = paging.token!;
      paging.pending = null;
      await controller.refresh();
      expect(token.isCancelled, isTrue);
      pending.complete(next);
      await more;
      expect(container.read(sessionsProvider).requireValue, hasLength(20));
      await controller.loadMore();
      expect(paging.requests, [(1, 20), (2, 20), (1, 20), (2, 20)]);
    },
  );

  test(
    'a mutation cancels old pagination and reconciles shifted offsets',
    () async {
      final paging = await preparePages();
      final controller = container.read(sessionsProvider.notifier);
      final next = await paging.serverPage('a', 2);
      paging.pending = Completer<ConversationSessionPage>();
      final pending = paging.pending!;
      final more = controller.loadMore();
      final token = paging.token!;
      await controller.delete('mock-1');
      expect(token.isCancelled, isTrue);
      pending.complete(next);
      await more;
      paging.pending = null;
      await controller.loadMore();
      expect(paging.requests.last, (1, 20));
      await controller.loadMore();
      expect(paging.requests.last, (2, 20));
      expect(container.read(sessionsProvider).requireValue, hasLength(40));
      expect(
        container.read(sessionsProvider).requireValue.map((item) => item.id),
        isNot(contains('mock-1')),
      );
    },
  );

  test('refresh updates shared history with server changes', () async {
    await signIn('a');
    final session = await repository.create('a', 'Created elsewhere');
    expect(container.read(sessionsProvider).requireValue.length, 8);
    await container.read(sessionsProvider.notifier).refresh();
    expect(
      container.read(sessionsProvider).requireValue.map((item) => item.id),
      contains(session.id),
    );
  });

  test('failed refresh preserves history and a later pull recovers', () async {
    final refreshing = _RefreshingRepository();
    repository = refreshing;
    await signIn('a');
    final before = container.read(sessionsProvider).requireValue;
    refreshing.pending = Completer<List<ConversationSession>>();
    final refresh = container.read(sessionsProvider.notifier).refresh();
    final failure = expectLater(refresh, throwsStateError);
    refreshing.pending!.completeError(StateError('offline'));
    await failure;
    expect(container.read(sessionsProvider).requireValue, same(before));
    refreshing.pending = null;
    await repository.create('a', 'Created elsewhere');
    await container.read(sessionsProvider.notifier).refresh();
    expect(container.read(sessionsProvider).requireValue.length, 9);
  });

  test('refresh cannot overwrite a newer session mutation', () async {
    final refreshing = _RefreshingRepository();
    repository = refreshing;
    await signIn('a');
    final previous = container.read(sessionsProvider).requireValue;
    refreshing.pending = Completer<List<ConversationSession>>();
    final actions = container.read(sessionsProvider.notifier);
    final refresh = actions.refresh();
    await actions.rename('mock-1', 'Changed while refreshing');
    refreshing.pending!.complete(previous);
    await refresh;
    expect(
      container.read(sessionsProvider).requireValue.first.title,
      'Changed while refreshing',
    );
  });

  test('account switch cancels refresh and ignores its old result', () async {
    final refreshing = _RefreshingRepository();
    repository = refreshing;
    await signIn('a');
    await container
        .read(sessionsProvider.notifier)
        .rename('mock-1', 'Account A');
    final previous = container.read(sessionsProvider).requireValue;
    final pending = Completer<List<ConversationSession>>();
    refreshing.pending = pending;
    final refresh = container.read(sessionsProvider.notifier).refresh();
    final token = refreshing.token!;
    refreshing.pending = null;
    await signIn('b');
    expect(token.isCancelled, isTrue);
    pending.complete(previous);
    await refresh;
    expect(
      container.read(sessionsProvider).requireValue.first.title,
      isNot('Account A'),
    );
  });

  test(
    'server create, rename, pin, unpin and archive update shared state',
    () async {
      await signIn('a');
      final actions = container.read(sessionsProvider.notifier);
      final session = (await actions.create('  New  '))!;
      expect(session.title, 'New');
      await actions.setPinned(session.id, true);
      expect(
        container.read(sessionsProvider).requireValue.first.id,
        session.id,
      );
      await actions.rename(session.id, 'Changed');
      expect(
        container.read(sessionsProvider).requireValue.first.title,
        'Changed',
      );
      await actions.setPinned(session.id, false);
      expect(container.read(sessionsProvider).requireValue.first.id, 'mock-1');
      await actions.delete(session.id);
      expect(container.read(sessionsProvider).requireValue.length, 8);
      container.invalidate(sessionsProvider);
      expect((await container.read(sessionsProvider.future)).length, 8);
    },
  );

  test(
    'account changes reload authoritative history and logout clears it',
    () async {
      await signIn('a');
      await container
          .read(sessionsProvider.notifier)
          .rename('mock-1', 'Account A');
      await signIn('b');
      expect(
        container.read(sessionsProvider).requireValue.first.title,
        isNot('Account A'),
      );
      await signIn('a');
      expect(
        container.read(sessionsProvider).requireValue.first.title,
        'Account A',
      );
      (container.read(userProvider.notifier) as _TestUserController)
          .becomeGuest();
      expect(await container.read(sessionsProvider.future), isEmpty);
    },
  );

  test('invalid titles and stale IDs preserve visible history', () async {
    await signIn('a');
    final actions = container.read(sessionsProvider.notifier);
    final before = container.read(sessionsProvider).requireValue;
    await expectLater(actions.rename('mock-1', '  '), throwsArgumentError);
    await expectLater(actions.create('x' * 201), throwsArgumentError);
    await expectLater(actions.delete('missing'), throwsStateError);
    expect(container.read(sessionsProvider).requireValue, same(before));
  });

  test(
    'old account mutation is canceled and cannot enter the new list',
    () async {
      final pending = _PendingRepository();
      repository = pending;
      await signIn('a');
      final action = container
          .read(sessionsProvider.notifier)
          .create('Old account');
      await signIn('b');
      expect(pending.token!.isCancelled, isTrue);
      pending.result.complete(
        ConversationSession(
          id: 'old',
          title: 'Old account',
          updatedAt: DateTime.now(),
        ),
      );
      expect(await action, isNull);
      expect(
        container
            .read(sessionsProvider)
            .requireValue
            .any((item) => item.id == 'old'),
        isFalse,
      );
    },
  );

  test('load failure is exposed and retry recovers', () async {
    repository = _FailingRepository();
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: 'a', name: 'a', email: ''));
    await expectLater(
      container.read(sessionsProvider.future),
      throwsStateError,
    );
    expect(container.read(sessionsProvider).hasError, isTrue);
    repository = FixtureSessionRepository();
    container.invalidate(sessionRepositoryProvider);
    expect((await container.read(sessionsProvider.future)).length, 8);
  });
}

class _TestUserController extends UserController {
  void becomeGuest() => state = null;
}

class _PendingRepository extends FixtureSessionRepository {
  final result = Completer<ConversationSession>();
  CancelToken? token;
  @override
  Future<ConversationSession> create(
    String userId,
    String title, {
    CancelToken? cancelToken,
  }) {
    token = cancelToken;
    return result.future;
  }
}

class _PagingRepository extends FixtureSessionRepository {
  final requests = <(int, int)>[];
  Completer<ConversationSessionPage>? pending;
  bool failNext = false;
  CancelToken? token;

  Future<ConversationSessionPage> serverPage(String userId, int page) =>
      super.list(userId, page: page);

  @override
  Future<ConversationSessionPage> list(
    String userId, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    requests.add((page, pageSize));
    token = cancelToken;
    if (failNext) {
      failNext = false;
      throw StateError('offline');
    }
    return pending?.future ??
        super.list(
          userId,
          page: page,
          pageSize: pageSize,
          cancelToken: cancelToken,
        );
  }
}

class _FailingRepository extends FixtureSessionRepository {
  @override
  Future<ConversationSessionPage> list(
    String userId, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async => throw StateError('offline');
}

class _RefreshingRepository extends FixtureSessionRepository {
  Completer<List<ConversationSession>>? pending;
  CancelToken? token;

  @override
  Future<ConversationSessionPage> list(
    String userId, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) {
    token = cancelToken;
    return pending?.future.then(
          (items) => ConversationSessionPage(
            items: items,
            page: page,
            pageCount: page,
          ),
        ) ??
        super.list(
          userId,
          page: page,
          pageSize: pageSize,
          cancelToken: cancelToken,
        );
  }
}
