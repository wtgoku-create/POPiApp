import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/shared/providers/session_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

void main() {
  late ProviderContainer container;
  setUp(
    () => container = ProviderContainer(
      overrides: [userProvider.overrideWith(_TestUserController.new)],
    ),
  );
  tearDown(() => container.dispose());
  Future<void> signIn(String id) => container
      .read(userProvider.notifier)
      .setUser(User(id: id, name: id, email: ''));

  test('guest is empty and cannot mutate history', () {
    expect(container.read(sessionsProvider), isEmpty);
    expect(
      () => container.read(sessionsProvider.notifier).create('New'),
      throwsStateError,
    );
  });

  test('create, rename, pin, unpin and delete update shared state', () async {
    await signIn('a');
    final actions = container.read(sessionsProvider.notifier);
    expect(container.read(sessionsProvider).length, 8);
    final session = actions.create('  New  ');
    expect(session.title, 'New');
    actions.setPinned(session.id, true);
    expect(container.read(sessionsProvider).first.id, session.id);
    actions.rename(session.id, 'Changed');
    expect(container.read(sessionsProvider).first.title, 'Changed');
    actions.setPinned(session.id, false);
    expect(container.read(sessionsProvider).first.id, 'mock-1');
    actions.delete(session.id);
    expect(container.read(sessionsProvider).length, 8);
  });

  test(
    'account changes isolate data and restore each account in memory',
    () async {
      await signIn('a');
      final actions = container.read(sessionsProvider.notifier);
      actions.rename('mock-1', 'Account A');
      await signIn('b');
      expect(container.read(sessionsProvider).first.title, isNot('Account A'));
      actions.delete('mock-1');
      await signIn('a');
      expect(container.read(sessionsProvider).first.title, 'Account A');
      expect(container.read(sessionsProvider).length, 8);
      await signIn('b');
      expect(container.read(sessionsProvider).length, 7);
    },
  );

  test('invalid titles and stale IDs preserve state', () async {
    await signIn('a');
    final actions = container.read(sessionsProvider.notifier);
    final before = container.read(sessionsProvider);
    expect(() => actions.rename('mock-1', '  '), throwsArgumentError);
    expect(() => actions.create('x' * 201), throwsArgumentError);
    expect(() => actions.delete('missing'), throwsStateError);
    expect(() => actions.setPinned('missing', true), throwsStateError);
    expect(container.read(sessionsProvider), same(before));
  });

  test('sample avatar survives rename, pinning and reload', () async {
    await signIn('a');
    final sample = container.read(sessionsProvider).first;
    expect(sample.avatarIcon, 'home_drawer_session_pink');
    final actions = container.read(sessionsProvider.notifier);
    actions.rename(sample.id, 'Updated title');
    actions.setPinned(sample.id, false);
    actions.setPinned(sample.id, true);
    container.invalidate(sessionsProvider);
    expect(
      container.read(sessionsProvider).first.avatarIcon,
      sample.avatarIcon,
    );
  });

  test(
    'logout clears visible state and a new login restores mock edits',
    () async {
      await signIn('a');
      container
          .read(sessionsProvider.notifier)
          .rename('mock-1', 'Saved mock title');
      (container.read(userProvider.notifier) as _TestUserController)
          .becomeGuest();
      expect(container.read(sessionsProvider), isEmpty);
      expect(
        () => container.read(sessionsProvider.notifier).delete('mock-1'),
        throwsStateError,
      );
      await signIn('a');
      expect(container.read(sessionsProvider).first.title, 'Saved mock title');
    },
  );

  test('delete all conversations leaves empty history on reload', () async {
    await signIn('a');
    for (final session in container.read(sessionsProvider)) {
      container.read(sessionsProvider.notifier).delete(session.id);
    }
    expect(container.read(sessionsProvider), isEmpty);
    container.invalidate(sessionsProvider);
    expect(container.read(sessionsProvider), isEmpty);
  });
}

class _TestUserController extends UserController {
  void becomeGuest() => state = null;
}
