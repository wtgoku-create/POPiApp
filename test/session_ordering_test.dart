import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/session/data/session_repository.dart';
import 'package:popi_ai_app/features/session/domain/conversation_session.dart';
import 'package:popi_ai_app/shared/providers/session_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

import 'support/session_fixtures.dart';

DateTime _time(int hour) => DateTime.utc(2026, 10, 15, hour);

ConversationSession _session(
  String id, {
  int? interaction,
  int created = 0,
  int updated = 0,
  int? pinned,
  int revision = 1,
  String? title,
}) => ConversationSession(
  id: id,
  title: title ?? id,
  revision: revision,
  createdAt: _time(created),
  lastMessageAt: interaction == null ? null : _time(interaction),
  updatedAt: _time(updated),
  pinnedAt: pinned == null ? null : _time(pinned),
);

void main() {
  test('local ordering uses pin group, interaction/creation time, then ID', () {
    final sessions = SessionRepository.sorted([
      _session('a', interaction: 5, updated: 90),
      _session('b', interaction: 5),
      _session('fallback', created: 6),
      _session('older', interaction: 4, updated: 100),
      _session('pin-old', interaction: 1, pinned: 20),
      _session('pin-new', interaction: 2, pinned: 10),
    ]);
    expect(sessions.map((s) => s.id), [
      'pin-new',
      'pin-old',
      'fallback',
      'b',
      'a',
      'older',
    ]);
  });

  test('session parsing and merge advance revision and time independently', () {
    final local = ConversationSession.fromJson({
      'id': 'a',
      'title': 'local',
      'revision': 3,
      'createdAt': _time(1).toIso8601String(),
      'lastMessageAt': _time(4).toIso8601String(),
      'updatedAt': _time(6).toIso8601String(),
    });
    final merged = local.merge(
      _session('a', revision: 2, title: 'old', interaction: 5),
    );
    expect(merged.title, 'local');
    expect(merged.revision, 3);
    expect(merged.createdAt, _time(1));
    expect(merged.lastMessageAt, _time(5));
    final newer = merged.merge(
      _session('a', revision: 4, title: 'renamed', interaction: 2),
    );
    expect(newer.title, 'renamed');
    expect(newer.lastMessageAt, _time(5));
    expect(newer.merge(_session('a', revision: 5)).lastMessageAt, _time(5));
  });

  late _OrderedRepository repository;
  late ProviderContainer container;
  setUp(() {
    repository = _OrderedRepository();
    container = ProviderContainer(
      overrides: [
        userProvider.overrideWith(_UserController.new),
        sessionRepositoryProvider.overrideWithValue(repository),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> signIn([String id = 'a']) async {
    await container
        .read(userProvider.notifier)
        .setUser(User(id: id, name: id, email: ''));
    await container.read(sessionsProvider.future);
  }

  List<ConversationSession> items() =>
      container.read(sessionsProvider).requireValue;
  List<String> ids() => items().map((s) => s.id).toList();

  test(
    'normal pages preserve backend order without sorting each page',
    () async {
      repository.rows = [
        _session('a', interaction: 1),
        _session('z', interaction: 4),
        ...List.generate(18, (i) => _session('middle-$i')),
        _session('page2', interaction: 8, pinned: 1),
      ];
      await signIn();
      expect(ids().take(2), ['a', 'z']);
      await container.read(sessionsProvider.notifier).loadMore();
      expect(ids(), repository.rows.map((s) => s.id));
      expect(repository.requests, [1, 2]);
    },
  );

  test(
    'first-page interaction reorders locally with pin priority and no fetch',
    () async {
      repository.rows = [
        _session('pin', interaction: 1, pinned: 1),
        _session('a', interaction: 3),
        _session('b', interaction: 2),
      ];
      await signIn();
      final controller = container.read(sessionsProvider.notifier);
      controller.upsert(_session('b', interaction: 4));
      expect(ids(), ['pin', 'b', 'a']);
      controller.upsert(
        _session('a', interaction: 2, revision: 2, updated: 100),
      );
      expect(ids(), ['pin', 'b', 'a']);
      expect(items().last.lastMessageAt, _time(3));
      controller.upsert(
        _session('a', interaction: 3, revision: 3, updated: 200),
      );
      expect(ids(), ['pin', 'b', 'a']);
      expect(repository.requests, [1]);
    },
  );

  test('later pages return to cached page one on interaction', () async {
    await signIn();
    final controller = container.read(sessionsProvider.notifier);
    await controller.loadMore();
    expect(items(), hasLength(40));
    final reset = controller.pageResetVersion;
    controller.upsert(_session('row-30', interaction: 100));
    expect(items(), hasLength(20));
    expect(ids().first, 'row-30');
    expect(controller.pageResetVersion, reset + 1);
    expect(repository.requests, [1, 2]);
    await controller.loadMore();
    expect(repository.requests, [1, 2, 2]);
  });

  test('rename or older interaction retains loaded pages and order', () async {
    await signIn();
    final controller = container.read(sessionsProvider.notifier);
    await controller.loadMore();
    final before = ids();
    final reset = controller.pageResetVersion;
    controller.upsert(
      _session(
        'row-30',
        interaction: 0,
        revision: 2,
        updated: 100,
        title: 'Renamed',
      ),
    );
    expect(ids(), before);
    expect(items()[30].title, 'Renamed');
    expect(items()[30].lastMessageAt, repository.rows[30].lastMessageAt);
    expect(controller.pageResetVersion, reset);
    expect(repository.requests, [1, 2]);
  });

  test('metadata received during pagination survives stale response', () async {
    await signIn();
    final controller = container.read(sessionsProvider.notifier);
    final response = repository.page(2);
    repository.pending = Completer<ConversationSessionPage>();
    final more = controller.loadMore();
    controller.upsert(
      _session('row-0', interaction: 60, revision: 3, title: 'New title'),
    );
    expect(repository.token!.isCancelled, isFalse);
    repository.pending!.complete(
      ConversationSessionPage(
        items: [repository.rows.first, ...response.items],
        page: 2,
        pageCount: 3,
      ),
    );
    await more;
    expect(items(), hasLength(40));
    expect(items().first.title, 'New title');
    expect(items().first.revision, 3);
  });

  test(
    'interaction cancels pending next page and keeps current page',
    () async {
      await signIn();
      final controller = container.read(sessionsProvider.notifier);
      repository.pending = Completer<ConversationSessionPage>();
      final more = controller.loadMore();
      final token = repository.token!;
      controller.upsert(_session('row-10', interaction: 100));
      expect(token.isCancelled, isTrue);
      repository.pending!.complete(repository.page(2));
      await more;
      expect(items(), hasLength(20));
      expect(ids().first, 'row-10');
      expect(repository.requests, [1, 2]);
    },
  );

  test(
    'refresh preserves live row missing from stale server first page',
    () async {
      await signIn();
      final controller = container.read(sessionsProvider.notifier);
      await controller.loadMore();
      repository.pending = Completer<ConversationSessionPage>();
      final refresh = controller.refresh();
      controller.upsert(
        _session('row-30', interaction: 100, revision: 4, title: 'Latest'),
      );
      repository.pending!.complete(repository.page(1));
      await refresh;
      expect(items(), hasLength(20));
      expect(ids().first, 'row-30');
      expect(items().first.title, 'Latest');
      expect(items().first.lastMessageAt, _time(100));
      expect(repository.requests, [1, 2, 1]);
    },
  );

  test('initial response merges interactions received while loading', () async {
    repository.pending = Completer<ConversationSessionPage>();
    await container
        .read(userProvider.notifier)
        .setUser(const User(id: 'a', name: 'a', email: ''));
    final loading = container.read(sessionsProvider.future);
    container
        .read(sessionsProvider.notifier)
        .upsert(
          _session('row-10', interaction: 100, revision: 4, title: 'Live'),
        );
    repository.pending!.complete(repository.page(1));
    await loading;
    expect(ids().first, 'row-10');
    expect(items().first.revision, 4);
    expect(items().first.lastMessageAt, _time(100));
  });

  test(
    'account switch clears cached revisions and interaction times',
    () async {
      await signIn();
      container
          .read(sessionsProvider.notifier)
          .upsert(
            _session(
              'row-0',
              interaction: 100,
              revision: 10,
              title: 'Other account',
            ),
          );
      await signIn('b');
      expect(items().first.title, 'row-0');
      expect(items().first.lastMessageAt, _time(60));
      expect(items().first.revision, 1);
    },
  );
  test(
    'interaction during account reload never merges retained old rows',
    () async {
      await signIn();
      repository.pending = Completer<ConversationSessionPage>();
      await container
          .read(userProvider.notifier)
          .setUser(const User(id: 'b', name: 'b', email: ''));
      final loading = container.read(sessionsProvider.future);
      container
          .read(sessionsProvider.notifier)
          .upsert(_session('new-account', interaction: 100, revision: 3));
      repository.pending!.complete(
        ConversationSessionPage(
          items: [_session('new-account', interaction: 50)],
          page: 1,
          pageCount: 1,
        ),
      );
      await loading;
      expect(ids(), ['new-account']);
      expect(items().single.lastMessageAt, _time(100));
      expect(items().single.revision, 3);
    },
  );
}

class _UserController extends UserController {}

class _OrderedRepository extends FixtureSessionRepository {
  List<ConversationSession> rows = List.generate(
    45,
    (i) => _session('row-$i', interaction: 60 - i),
  );
  final requests = <int>[];
  Completer<ConversationSessionPage>? pending;
  CancelToken? token;

  ConversationSessionPage page(int page) => ConversationSessionPage(
    items: rows.skip((page - 1) * 20).take(20).toList(),
    page: page,
    pageCount: (rows.length / 20).ceil(),
  );

  @override
  Future<ConversationSessionPage> list(
    String userId, {
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    requests.add(page);
    token = cancelToken;
    return pending?.future ?? this.page(page);
  }
}
