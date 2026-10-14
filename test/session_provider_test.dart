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

class _FailingRepository extends FixtureSessionRepository {
  @override
  Future<List<ConversationSession>> list(
    String userId, {
    CancelToken? cancelToken,
  }) async => throw StateError('offline');
}

class _RefreshingRepository extends FixtureSessionRepository {
  Completer<List<ConversationSession>>? pending;
  CancelToken? token;

  @override
  Future<List<ConversationSession>> list(
    String userId, {
    CancelToken? cancelToken,
  }) {
    token = cancelToken;
    return pending?.future ?? super.list(userId, cancelToken: cancelToken);
  }
}
