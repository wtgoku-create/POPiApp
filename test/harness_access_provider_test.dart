import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popi_ai_app/core/network/network_agent_api.dart';
import 'package:popi_ai_app/core/storage/harness_access_storage.dart';
import 'package:popi_ai_app/features/demo/data/harness_access_repository.dart';
import 'package:popi_ai_app/features/demo/domain/harness_access_session.dart';
import 'package:popi_ai_app/shared/providers/harness_access_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';

void main() {
  final now = DateTime.utc(2026, 10, 24, 6);
  final session = HarnessAccessSession(
    cookieValue: 'secret-cookie',
    origin: 'https://harness.example',
    expiresAt: DateTime.utc(2099),
    cacheNamespace: '123e4567-e89b-42d3-a456-426614174000',
  );

  test('macOS storage uses the profile-free private keychain', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final storage = container.read(flutterSecureStorageProvider);

    expect(storage.mOptions.toMap()['useDataProtectionKeyChain'], 'false');
  });

  test('remote release app uses an isolated private keychain service', () {
    final distributed = macOsStorageOptions(
      remoteHarnessEnabled: true,
      releaseMode: true,
    ).toMap();
    expect(distributed['useDataProtectionKeyChain'], 'false');
    expect(distributed['accountName'], 'com.popistudio.app.harness.remote');
    expect(distributed['synchronizable'], 'false');
    expect(distributed, isNot(contains('groupId')));

    final debug = macOsStorageOptions(
      remoteHarnessEnabled: true,
      releaseMode: false,
    ).toMap();
    expect(debug['useDataProtectionKeyChain'], 'false');
    expect(debug['accountName'], isNot('com.popistudio.app.harness.remote'));

    final normalRelease = macOsStorageOptions(
      remoteHarnessEnabled: false,
      releaseMode: true,
    ).toMap();
    expect(normalRelease['useDataProtectionKeyChain'], 'true');
    expect(
      normalRelease['accountName'],
      isNot('com.popistudio.app.harness.remote'),
    );
  });

  test('initializes, restores, and clears the persisted session', () async {
    final storage = _MemoryStorage()..session = session;
    final controller = HarnessAccessController(
      storage: storage,
      repository: null,
      required: true,
      expectedOrigin: 'https://harness.example',
      now: () => now,
    );
    addTearDown(controller.dispose);

    expect(controller.state.loading, isTrue);
    expect(controller.state.authenticated, isFalse);

    await controller.initialize();
    expect(controller.state.loading, isFalse);
    expect(controller.state.authenticated, isTrue);
    expect(controller.state.session, same(session));

    await controller.signOut();
    expect(controller.state.authenticated, isFalse);
    expect(storage.session, isNull);
    expect(storage.deletes, 1);
  });

  test('clears expired, corrupt, and wrong-origin sessions', () async {
    for (final stored in <Object?>[
      HarnessAccessSession(
        cookieValue: 'expired',
        origin: 'https://harness.example',
        expiresAt: now,
        cacheNamespace: '123e4567-e89b-42d3-a456-426614174000',
      ),
      HarnessAccessSession(
        cookieValue: 'other-origin',
        origin: 'https://other.example',
        expiresAt: now.add(const Duration(hours: 1)),
        cacheNamespace: '123e4567-e89b-42d3-a456-426614174000',
      ),
      const FormatException('corrupt'),
    ]) {
      final storage = _MemoryStorage();
      if (stored is HarnessAccessSession) {
        storage.session = stored;
      } else {
        storage.readError = stored;
      }
      final controller = HarnessAccessController(
        storage: storage,
        repository: null,
        required: true,
        expectedOrigin: 'https://harness.example',
        now: () => now,
      );

      await controller.initialize();
      expect(controller.state.authenticated, isFalse, reason: '$stored');
      expect(storage.deletes, 1, reason: '$stored');
      controller.dispose();
    }
  });

  test(
    'sign in updates and persists state without retaining password',
    () async {
      final storage = _MemoryStorage();
      final repository = _StubRepository(session: session);
      final controller = HarnessAccessController(
        storage: storage,
        repository: repository,
        required: true,
        expectedOrigin: 'https://harness.example',
        now: () => now,
      );
      addTearDown(controller.dispose);

      await controller.signIn('tester', 'one-time-password');

      expect(controller.state.authenticated, isTrue);
      expect(storage.session, same(session));
      expect(repository.username, 'tester');
      expect(repository.password, 'one-time-password');
      expect(session.toJson().values, isNot(contains('one-time-password')));
    },
  );

  test(
    'typed sign-in failure restores a stable unauthenticated state',
    () async {
      final controller = HarnessAccessController(
        storage: _MemoryStorage(),
        repository: _StubRepository(
          error: const HarnessAccessException(
            HarnessAccessExceptionType.rateLimited,
            retryAfterSeconds: 30,
          ),
        ),
        required: true,
        expectedOrigin: 'https://harness.example',
        now: () => now,
      );
      addTearDown(controller.dispose);

      await expectLater(
        controller.signIn('tester', 'password'),
        throwsA(
          isA<HarnessAccessException>().having(
            (error) => error.retryAfterSeconds,
            'retryAfterSeconds',
            30,
          ),
        ),
      );
      expect(controller.state.loading, isFalse);
      expect(controller.state.authenticating, isFalse);
      expect(controller.state.authenticated, isFalse);
    },
  );

  test(
    'secure storage failure does not discard a successful live login',
    () async {
      final storage = _MemoryStorage()..writeError = StateError('keychain');
      final controller = HarnessAccessController(
        storage: storage,
        repository: _StubRepository(session: session),
        required: true,
        expectedOrigin: 'https://harness.example',
        now: () => now,
      );
      addTearDown(controller.dispose);

      await controller.signIn('tester', 'password');

      expect(controller.state.authenticated, isTrue);
      expect(controller.state.session, same(session));
      expect(storage.session, isNull);
    },
  );

  test('a delayed clear cannot erase a newer successful login', () async {
    final newer = HarnessAccessSession(
      cookieValue: 'new-cookie',
      origin: session.origin,
      expiresAt: session.expiresAt,
      cacheNamespace: '123e4567-e89b-42d3-a456-426614174001',
    );
    final storage = _ControlledStorage()..session = session;
    final controller = HarnessAccessController(
      storage: storage,
      repository: _StubRepository(session: newer),
      required: true,
      expectedOrigin: session.origin,
      now: () => now,
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    storage.blockNextDelete();
    final clearing = controller.signOut();
    await storage.deleteStarted.future;
    expect(controller.state.authenticated, isFalse);

    final signingIn = controller.signIn('tester', 'password');
    storage.releaseDelete();
    await Future.wait([clearing, signingIn]);

    expect(controller.state.session, same(newer));
    expect(storage.session, same(newer));
  });

  test('a delayed write is followed by a newer clear', () async {
    final storage = _ControlledStorage()..blockNextWrite();
    final controller = HarnessAccessController(
      storage: storage,
      repository: _StubRepository(session: session),
      required: true,
      expectedOrigin: session.origin,
      now: () => now,
    );
    addTearDown(controller.dispose);

    final signingIn = controller.signIn('tester', 'password');
    await storage.writeStarted.future;
    final clearing = controller.signOut();
    expect(controller.state.authenticated, isFalse);

    storage.releaseWrite();
    await Future.wait([signingIn, clearing]);

    expect(controller.state.authenticated, isFalse);
    expect(storage.session, isNull);
  });

  test('the latest of two overlapping logins owns persisted state', () async {
    final first = HarnessAccessSession(
      cookieValue: 'first-cookie',
      origin: session.origin,
      expiresAt: session.expiresAt,
      cacheNamespace: '123e4567-e89b-42d3-a456-426614174001',
    );
    final second = HarnessAccessSession(
      cookieValue: 'second-cookie',
      origin: session.origin,
      expiresAt: session.expiresAt,
      cacheNamespace: '123e4567-e89b-42d3-a456-426614174002',
    );
    final storage = _ControlledStorage()..blockNextWrite();
    final controller = HarnessAccessController(
      storage: storage,
      repository: _MappedRepository({'first': first, 'second': second}),
      required: true,
      expectedOrigin: session.origin,
      now: () => now,
    );
    addTearDown(controller.dispose);

    final firstLogin = controller.signIn('first', 'password');
    await storage.writeStarted.future;
    final secondLogin = controller.signIn('second', 'password');
    storage.releaseWrite();
    await Future.wait([firstLogin, secondLogin]);

    expect(controller.state.session, same(second));
    expect(storage.session, same(second));
  });

  testWidgets('a restored session expires into the login gate', (tester) async {
    final expiring = HarnessAccessSession(
      cookieValue: 'expiring-cookie',
      origin: session.origin,
      expiresAt: now.add(const Duration(minutes: 1)),
      cacheNamespace: '123e4567-e89b-42d3-a456-426614174010',
    );
    final storage = _MemoryStorage()..session = expiring;
    final controller = HarnessAccessController(
      storage: storage,
      repository: null,
      required: true,
      expectedOrigin: session.origin,
      now: () => now,
    );

    await controller.initialize();
    expect(controller.state.authenticated, isTrue);

    await tester.pump(const Duration(seconds: 59));
    expect(controller.state.authenticated, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(controller.state.authenticated, isFalse);
    expect(storage.session, isNull);
    controller.dispose();
  });

  testWidgets('a newer session replaces the old expiry timer', (tester) async {
    final first = HarnessAccessSession(
      cookieValue: 'first-expiring-cookie',
      origin: session.origin,
      expiresAt: now.add(const Duration(minutes: 1)),
      cacheNamespace: '123e4567-e89b-42d3-a456-426614174011',
    );
    final replacement = HarnessAccessSession(
      cookieValue: 'replacement-cookie',
      origin: session.origin,
      expiresAt: now.add(const Duration(hours: 2)),
      cacheNamespace: '123e4567-e89b-42d3-a456-426614174012',
    );
    final storage = _MemoryStorage();
    final controller = HarnessAccessController(
      storage: storage,
      repository: _MappedRepository({
        'first': first,
        'replacement': replacement,
      }),
      required: true,
      expectedOrigin: session.origin,
      now: () => now,
    );

    await controller.signIn('first', 'password');
    await controller.signIn('replacement', 'password');
    await tester.pump(const Duration(minutes: 1));

    expect(controller.state.session, same(replacement));
    expect(storage.session, same(replacement));
    controller.dispose();
  });

  testWidgets('sign out cancels the session expiry timer', (tester) async {
    final expiring = HarnessAccessSession(
      cookieValue: 'logout-cookie',
      origin: session.origin,
      expiresAt: now.add(const Duration(minutes: 1)),
      cacheNamespace: '123e4567-e89b-42d3-a456-426614174013',
    );
    final storage = _MemoryStorage();
    final controller = HarnessAccessController(
      storage: storage,
      repository: _StubRepository(session: expiring),
      required: true,
      expectedOrigin: session.origin,
      now: () => now,
    );

    await controller.signIn('tester', 'password');
    await controller.signOut();
    final deletesAfterSignOut = storage.deletes;
    await tester.pump(const Duration(minutes: 2));
    await tester.pump();

    expect(controller.state.authenticated, isFalse);
    expect(storage.deletes, deletesAfterSignOut);
    controller.dispose();
  });

  test('headers and cache partition stay on the owned Harness origin', () {
    expect(
      harnessAccessHeadersFor(
        '/api_agent/v2/sessions',
        session: session,
        baseUrl: 'https://harness.example',
        now: () => now,
      ),
      {
        'Cookie': '__Host-popi-test=secret-cookie',
        'Origin': 'https://harness.example',
      },
    );
    for (final url in [
      'https://attacker.example/api_agent/v2/sessions',
      'https://harness.example/login',
      'http://harness.example/api_agent/v2/sessions',
    ]) {
      expect(
        harnessAccessHeadersFor(
          url,
          session: session,
          baseUrl: 'https://harness.example',
          now: () => now,
        ),
        isEmpty,
        reason: url,
      );
    }

    final cacheKey = harnessAccessCacheKeyFor(
      '/api_agent/v2/assets/asset-1/content',
      session: session,
      baseUrl: 'https://harness.example',
      now: () => now,
    );
    expect(cacheKey, contains(session.cacheNamespace));
    expect(cacheKey, contains('/api_agent/v2/assets/asset-1/content'));
    expect(cacheKey, isNot(contains(session.cookieValue)));
    expect(
      harnessAccessCacheKeyFor(
        '/api_agent/v2/sessions',
        session: session,
        baseUrl: 'https://harness.example',
        now: () => now,
      ),
      isNull,
    );
  });

  test('media 401 only invalidates the captured current session', () async {
    var required = true;
    HarnessAccessSession? current = session;
    var invalidations = 0;
    final callback = harnessAccessUnauthorizedCallbackFor(
      'https://harness.example/api_agent/v2/assets/asset-1/content',
      accessRequired: () => required,
      capturedSession: session,
      currentSession: () => current,
      baseUrl: 'https://harness.example',
      invalidate: () async {
        invalidations++;
      },
    );

    callback();
    await Future<void>.delayed(Duration.zero);
    expect(invalidations, 1);

    current = HarnessAccessSession(
      cookieValue: 'new-cookie',
      origin: session.origin,
      expiresAt: session.expiresAt,
      cacheNamespace: '123e4567-e89b-42d3-a456-426614174001',
    );
    callback();
    await Future<void>.delayed(Duration.zero);
    expect(invalidations, 1);

    current = session;
    required = false;
    callback();
    await Future<void>.delayed(Duration.zero);
    expect(invalidations, 1);
  });

  test('media 401 callback is inert outside owned Harness APIs', () async {
    var invalidations = 0;
    for (final url in [
      'https://attacker.example/api_agent/v2/assets/asset-1/content',
      'https://harness.example/business/image.png',
      'http://harness.example/api_agent/v2/assets/asset-1/content',
    ]) {
      final callback = harnessAccessUnauthorizedCallbackFor(
        url,
        accessRequired: () => true,
        capturedSession: session,
        currentSession: () => session,
        baseUrl: 'https://harness.example',
        invalidate: () async {
          invalidations++;
        },
      );
      callback();
    }
    await Future<void>.delayed(Duration.zero);
    expect(invalidations, 0);
  });
}

class _MemoryStorage implements HarnessAccessStorage {
  HarnessAccessSession? session;
  Object? readError;
  Object? writeError;
  int deletes = 0;

  @override
  Future<void> deleteSession() async {
    deletes++;
    session = null;
  }

  @override
  Future<HarnessAccessSession?> readSession() async {
    if (readError case final Object error) throw error;
    return session;
  }

  @override
  Future<void> writeSession(HarnessAccessSession value) async {
    if (writeError case final Object error) throw error;
    session = value;
  }
}

class _ControlledStorage implements HarnessAccessStorage {
  HarnessAccessSession? session;
  Completer<void>? _deleteGate;
  Completer<void>? _writeGate;
  Completer<void> deleteStarted = Completer<void>();
  Completer<void> writeStarted = Completer<void>();

  void blockNextDelete() {
    _deleteGate = Completer<void>();
    deleteStarted = Completer<void>();
  }

  void releaseDelete() => _deleteGate?.complete();

  void blockNextWrite() {
    _writeGate = Completer<void>();
    writeStarted = Completer<void>();
  }

  void releaseWrite() => _writeGate?.complete();

  @override
  Future<void> deleteSession() async {
    final gate = _deleteGate;
    if (gate != null) {
      if (!deleteStarted.isCompleted) deleteStarted.complete();
      await gate.future;
      _deleteGate = null;
    }
    session = null;
  }

  @override
  Future<HarnessAccessSession?> readSession() async => session;

  @override
  Future<void> writeSession(HarnessAccessSession value) async {
    final gate = _writeGate;
    if (gate != null) {
      if (!writeStarted.isCompleted) writeStarted.complete();
      await gate.future;
      _writeGate = null;
    }
    session = value;
  }
}

class _StubRepository extends HarnessAccessRepository {
  _StubRepository({this.session, this.error})
    : super(
        NetworkAgentApi(Dio(BaseOptions(baseUrl: 'https://harness.example'))),
        origin: 'https://harness.example',
      );

  final HarnessAccessSession? session;
  final HarnessAccessException? error;
  String? username;
  String? password;

  @override
  Future<HarnessAccessSession> signIn({
    required String username,
    required String password,
  }) async {
    this.username = username;
    this.password = password;
    if (error case final HarnessAccessException value) throw value;
    return session!;
  }
}

class _MappedRepository extends HarnessAccessRepository {
  _MappedRepository(this.sessions)
    : super(
        NetworkAgentApi(Dio(BaseOptions(baseUrl: 'https://harness.example'))),
        origin: 'https://harness.example',
      );

  final Map<String, HarnessAccessSession> sessions;

  @override
  Future<HarnessAccessSession> signIn({
    required String username,
    required String password,
  }) async => sessions[username]!;
}
