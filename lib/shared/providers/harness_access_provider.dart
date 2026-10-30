import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/network_agent_api.dart';
import '../../core/storage/harness_access_storage.dart';
import '../../features/demo/data/harness_access_repository.dart';
import '../../features/demo/domain/harness_access_session.dart';
import 'storage_provider.dart';
import 'business_agent_provider.dart';

final harnessAccessRequiredProvider = Provider<bool>(
  (ref) => !kIsWeb && AppConfig.remoteHarnessEnabled,
);

final harnessAccessRepositoryProvider = Provider<HarnessAccessRepository>((
  ref,
) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.agentApiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
        'Origin': AppConfig.agentApiOrigin,
      },
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return HarnessAccessRepository(
    NetworkAgentApi(dio),
    origin: AppConfig.agentApiOrigin,
  );
});

final harnessAccessProvider =
    StateNotifierProvider<HarnessAccessController, HarnessAccessState>((ref) {
      final required = ref.watch(harnessAccessRequiredProvider);
      return HarnessAccessController(
        storage: ref.watch(harnessAccessStorageProvider),
        repository: required
            ? ref.watch(harnessAccessRepositoryProvider)
            : null,
        required: required,
        expectedOrigin: required ? AppConfig.agentApiOrigin : null,
      );
    });

final harnessAccessHeadersProvider =
    Provider.family<Map<String, String>, String>((ref, url) {
      if (AppConfig.businessAgentEnabled) {
        return ref
                .watch(businessAgentSessionProvider)
                .valueOrNull
                ?.mediaHeaders(url) ??
            const {};
      }
      if (!ref.watch(harnessAccessRequiredProvider)) return const {};
      final session = ref.watch(harnessAccessProvider).session;
      return harnessAccessHeadersFor(
        url,
        session: session,
        baseUrl: AppConfig.agentApiBaseUrl,
      );
    });

final harnessAccessCacheKeyProvider = Provider.family<String?, String>((
  ref,
  url,
) {
  if (AppConfig.businessAgentEnabled) {
    final session = ref.watch(businessAgentSessionProvider).valueOrNull;
    return session == null ? null : '$url::${session.cacheNamespace}';
  }
  if (!ref.watch(harnessAccessRequiredProvider)) return null;
  final session = ref.watch(harnessAccessProvider).session;
  return harnessAccessCacheKeyFor(
    url,
    session: session,
    baseUrl: AppConfig.agentApiBaseUrl,
  );
});

/// Invalidates the native remote-Harness session after an authenticated media
/// request receives HTTP 401.
///
/// The returned callback is bound to the session that created the request.
/// A late 401 from an older request therefore cannot clear a newer login.
final harnessAccessUnauthorizedProvider = Provider.family<VoidCallback, String>(
  (ref, url) {
    if (AppConfig.businessAgentEnabled) {
      final captured = ref.watch(businessAgentSessionProvider).valueOrNull;
      return () {
        if (captured != null &&
            identical(
              ref.read(businessAgentSessionProvider).valueOrNull,
              captured,
            )) {
          unawaited(captured.invalidate());
        }
      };
    }
    final capturedSession = ref.watch(harnessAccessProvider).session;
    return harnessAccessUnauthorizedCallbackFor(
      url,
      accessRequired: () => ref.read(harnessAccessRequiredProvider),
      capturedSession: capturedSession,
      currentSession: () => ref.read(harnessAccessProvider).session,
      baseUrl: AppConfig.agentApiBaseUrl,
      invalidate: ref.read(harnessAccessProvider.notifier).invalidate,
    );
  },
);

@immutable
class HarnessAccessState {
  const HarnessAccessState({
    required this.loading,
    required this.authenticating,
    this.session,
  });

  const HarnessAccessState.loading()
    : loading = true,
      authenticating = false,
      session = null;

  const HarnessAccessState.unauthenticated()
    : loading = false,
      authenticating = false,
      session = null;

  final bool loading;
  final bool authenticating;
  final HarnessAccessSession? session;

  bool get authenticated => session != null;
}

class HarnessAccessController extends StateNotifier<HarnessAccessState> {
  HarnessAccessController({
    required HarnessAccessStorage storage,
    required HarnessAccessRepository? repository,
    required bool required,
    required String? expectedOrigin,
    DateTime Function()? now,
  }) : _storage = storage,
       _repository = repository,
       _required = required,
       _expectedOrigin = expectedOrigin,
       _now = now ?? DateTime.now,
       super(
         required
             ? const HarnessAccessState.loading()
             : const HarnessAccessState.unauthenticated(),
       );

  final HarnessAccessStorage _storage;
  final HarnessAccessRepository? _repository;
  final bool _required;
  final String? _expectedOrigin;
  final DateTime Function() _now;
  int _revision = 0;
  Future<void> _storageTail = Future<void>.value();
  Timer? _expiryTimer;

  Future<void> initialize() async {
    final revision = ++_revision;
    _cancelExpiryTimer();
    if (!_required) {
      state = const HarnessAccessState.unauthenticated();
      return;
    }
    state = const HarnessAccessState.loading();
    try {
      final session = await _scheduleStorage(_storage.readSession);
      if (revision != _revision) return;
      if (session == null ||
          session.origin != _expectedOrigin ||
          session.isExpiredAt(_now().toUtc())) {
        if (session != null) await _deleteBestEffort();
        if (revision == _revision) {
          state = const HarnessAccessState.unauthenticated();
        }
        return;
      }
      _publishAuthenticated(session);
    } on Object {
      await _deleteBestEffort();
      if (revision == _revision) {
        state = const HarnessAccessState.unauthenticated();
      }
    }
  }

  Future<void> signIn(String username, String password) async {
    final repository = _repository;
    if (!_required || repository == null) {
      throw const HarnessAccessException(
        HarnessAccessExceptionType.invalidResponse,
      );
    }
    final revision = ++_revision;
    final previousSession = state.session;
    final baselinePersistence = _persistBestEffort(previousSession);
    state = HarnessAccessState(
      loading: false,
      authenticating: true,
      session: previousSession,
    );
    try {
      final session = await repository.signIn(
        username: username,
        password: password,
      );
      if (revision != _revision) return;
      await baselinePersistence;
      if (revision != _revision) return;
      await _persistBestEffort(session);
      if (revision != _revision) return;
      _publishAuthenticated(session);
    } on HarnessAccessException {
      await baselinePersistence;
      if (revision == _revision) {
        state = HarnessAccessState(
          loading: false,
          authenticating: false,
          session: previousSession,
        );
      }
      rethrow;
    } on Object {
      await baselinePersistence;
      if (revision == _revision) {
        await _persistBestEffort(previousSession);
      }
      if (revision == _revision) {
        state = HarnessAccessState(
          loading: false,
          authenticating: false,
          session: previousSession,
        );
      }
      throw const HarnessAccessException(
        HarnessAccessExceptionType.unavailable,
      );
    }
  }

  Future<void> signOut() => _clear();

  Future<void> invalidate() => _clear();

  Future<void> _clear() async {
    ++_revision;
    _cancelExpiryTimer();
    state = const HarnessAccessState.unauthenticated();
    await _deleteBestEffort();
  }

  void _publishAuthenticated(HarnessAccessSession session) {
    _cancelExpiryTimer();
    final remaining = session.expiresAt.difference(_now().toUtc());
    if (remaining <= Duration.zero) {
      state = const HarnessAccessState.unauthenticated();
      unawaited(_deleteBestEffort());
      return;
    }
    state = HarnessAccessState(
      loading: false,
      authenticating: false,
      session: session,
    );
    final cookieValue = session.cookieValue;
    final cacheNamespace = session.cacheNamespace;
    _expiryTimer = Timer(remaining, () {
      final current = state.session;
      if (current?.cookieValue == cookieValue &&
          current?.cacheNamespace == cacheNamespace) {
        unawaited(invalidate());
      }
    });
  }

  void _cancelExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
  }

  Future<void> _deleteBestEffort() async {
    try {
      await _scheduleStorage(_storage.deleteSession);
    } on Object {
      // An unavailable keychain must not keep stale access active in memory.
    }
  }

  Future<void> _persistBestEffort(HarnessAccessSession? session) async {
    try {
      await _scheduleStorage(
        session == null
            ? _storage.deleteSession
            : () => _storage.writeSession(session),
      );
    } on Object {
      // A later successful operation still runs because the queue never fails.
    }
  }

  Future<T> _scheduleStorage<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _storageTail = _storageTail.then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  @override
  void dispose() {
    _cancelExpiryTimer();
    super.dispose();
  }
}

@visibleForTesting
Map<String, String> harnessAccessHeadersFor(
  String url, {
  required HarnessAccessSession? session,
  required String baseUrl,
  DateTime Function()? now,
}) {
  if (session == null || session.isExpiredAt((now ?? DateTime.now)().toUtc())) {
    return const {};
  }
  final uri = _sameOriginUri(url, baseUrl, session.origin);
  if (uri == null || !uri.path.startsWith('/api_agent/')) return const {};
  return {'Cookie': session.cookieHeader, 'Origin': session.origin};
}

@visibleForTesting
String? harnessAccessCacheKeyFor(
  String url, {
  required HarnessAccessSession? session,
  required String baseUrl,
  DateTime Function()? now,
}) {
  if (session == null || session.isExpiredAt((now ?? DateTime.now)().toUtc())) {
    return null;
  }
  final uri = _sameOriginUri(url, baseUrl, session.origin);
  if (uri == null || uri.hasQuery || uri.hasFragment) return null;
  final ownedAsset = RegExp(
    r'^/api_agent/v2/assets/[A-Za-z0-9_-]+/(?:content|poster|thumbnail)$',
  );
  final stylePoster = RegExp(
    r'^/api_agent/v2/style-films/styles/[a-z0-9]+(?:-[a-z0-9]+)*/poster$',
  );
  if (!ownedAsset.hasMatch(uri.path) && !stylePoster.hasMatch(uri.path)) {
    return null;
  }
  return '${uri.toString()}::${session.cacheNamespace}';
}

@visibleForTesting
VoidCallback harnessAccessUnauthorizedCallbackFor(
  String url, {
  required bool Function() accessRequired,
  required HarnessAccessSession? capturedSession,
  required HarnessAccessSession? Function() currentSession,
  required String baseUrl,
  required Future<void> Function() invalidate,
}) {
  if (!accessRequired() ||
      capturedSession == null ||
      harnessAccessHeadersFor(
        url,
        session: capturedSession,
        baseUrl: baseUrl,
      ).isEmpty) {
    return _ignoreHarnessUnauthorized;
  }
  return () {
    if (!accessRequired()) return;
    final current = currentSession();
    if (current == null ||
        current.origin != capturedSession.origin ||
        current.cookieValue != capturedSession.cookieValue ||
        current.cacheNamespace != capturedSession.cacheNamespace ||
        harnessAccessHeadersFor(
          url,
          session: current,
          baseUrl: baseUrl,
        ).isEmpty) {
      return;
    }
    unawaited(invalidate());
  };
}

void _ignoreHarnessUnauthorized() {}

Uri? _sameOriginUri(String value, String baseUrl, String expectedOrigin) {
  final candidate = Uri.tryParse(value);
  final base = Uri.tryParse(baseUrl);
  if (candidate == null || base == null || !base.hasAuthority) return null;
  final resolved = candidate.hasScheme ? candidate : base.resolveUri(candidate);
  if (resolved.scheme != 'https' ||
      resolved.userInfo.isNotEmpty ||
      resolved.pathSegments.contains('..') ||
      resolved.pathSegments.contains('.') ||
      resolved.origin != expectedOrigin) {
    return null;
  }
  return resolved;
}
