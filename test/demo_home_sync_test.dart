import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/core/network/agent_api_exception.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_home_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

DemoSession _session(String id, String title) => DemoSession(
  id: id,
  title: title,
  kind: DemoSessionKind.project,
  members: const ['popi'],
  roles: const [],
  messages: const [DemoMessage(id: 'message', text: '来自 Harness')],
);

class _HarnessSyncRepository extends DemoRepository {
  _HarnessSyncRepository(
    super.storage, {
    List<DemoSession> cachedSessions = const [],
  }) : _visibleSessions = List.of(cachedSessions);

  List<DemoSession> remoteSessions = [];
  List<DemoSession> _visibleSessions;
  Completer<void>? _nextRefresh;
  Object? refreshError;
  int refreshCalls = 0;

  @override
  bool get isHarness => true;

  @override
  List<DemoSession> get sessions => List.unmodifiable(_visibleSessions);

  @override
  List<DemoAsset> get assets => const [];

  @override
  DemoSession session(String id) =>
      _visibleSessions.firstWhere((session) => session.id == id);

  Completer<void> blockNextRefresh() => _nextRefresh = Completer<void>();

  @override
  Future<void> refreshSessions() async {
    refreshCalls += 1;
    final blocker = _nextRefresh;
    _nextRefresh = null;
    if (blocker != null) await blocker.future;
    final error = refreshError;
    if (error != null) throw error;
    _visibleSessions = List.of(remoteSessions);
    notifyListeners();
  }
}

class _OfflineCountingRepository extends DemoRepository {
  _OfflineCountingRepository(super.storage);

  int refreshCalls = 0;

  @override
  Future<void> refreshSessions() async {
    refreshCalls += 1;
  }
}

Future<PreferencesStorage> _storage() async {
  SharedPreferences.setMockInitialValues({});
  return PreferencesStorage(await SharedPreferences.getInstance());
}

Future<void> _pumpHome(WidgetTester tester, DemoRepository repository) async {
  tester.view.physicalSize = const Size(375, 775);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => _restoreResumed(tester));
  await tester.pumpWidget(
    ProviderScope(
      child: ToastificationWrapper(
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: DemoHomePage(repository: repository),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _backgroundAndResume(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

void _restoreResumed(WidgetTester tester) {
  switch (tester.binding.lifecycleState) {
    case AppLifecycleState.paused:
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    case AppLifecycleState.hidden:
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    case AppLifecycleState.inactive:
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    case AppLifecycleState.detached:
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    case AppLifecycleState.resumed:
    case null:
      break;
  }
}

void main() {
  tearDown(() => toastification.dismissAll(delayForAnimation: false));

  for (final failure in {
    'connection failure': DioException(
      requestOptions: RequestOptions(path: '/api_agent/v2/sessions'),
      type: DioExceptionType.connectionError,
    ),
    'HTTP failure': const AgentApiException(
      code: 'SERVICE_UNAVAILABLE',
      statusCode: 503,
    ),
  }.entries) {
    testWidgets(
      'initial Harness ${failure.key} reports a network error and keeps cache',
      (tester) async {
        final cached = _session('cached', '缓存会话');
        final repository = _HarnessSyncRepository(
          await _storage(),
          cachedSessions: [cached],
        )..refreshError = failure.value;
        addTearDown(repository.dispose);
        await _pumpHome(tester, repository);

        final l = AppLocalizations.of(
          tester.element(find.byType(DemoHomePage)),
        )!;
        expect(repository.refreshCalls, 1);
        expect(find.text(l.networkRequestFailed), findsOneWidget);
        expect(find.text(l.demoStorageError), findsNothing);
        expect(find.text('缓存会话'), findsOneWidget);
        expect(repository.sessions, [cached]);
        toastification.dismissAll(delayForAnimation: false);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('initial Harness local write failure retains its storage error', (
    tester,
  ) async {
    final cached = _session('cached', '缓存会话');
    final repository = _HarnessSyncRepository(
      await _storage(),
      cachedSessions: [cached],
    )..refreshError = StateError('Disk unavailable');
    addTearDown(repository.dispose);
    await _pumpHome(tester, repository);

    final l = AppLocalizations.of(tester.element(find.byType(DemoHomePage)))!;
    expect(find.text(l.demoStorageError), findsOneWidget);
    expect(find.text(l.networkRequestFailed), findsNothing);
    expect(find.text('缓存会话'), findsOneWidget);
    expect(repository.sessions, [cached]);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'automatic Harness failures keep cache silently and can recover',
    (tester) async {
      final repository = _HarnessSyncRepository(await _storage())
        ..remoteSessions = [_session('first', '缓存会话')];
      addTearDown(repository.dispose);
      await _pumpHome(tester, repository);
      final cached = repository.sessions.single;
      final l = AppLocalizations.of(tester.element(find.byType(DemoHomePage)))!;

      repository
        ..remoteSessions = [_session('first', '恢复同步后的会话')]
        ..refreshError = DioException(
          requestOptions: RequestOptions(path: '/api_agent/v2/sessions'),
          type: DioExceptionType.connectionError,
        );
      _backgroundAndResume(tester);
      await tester.pumpAndSettle();
      expect(repository.refreshCalls, 2);
      expect(repository.sessions, [cached]);

      await tester.tap(find.byKey(const Key('demo-tab-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('demo-tab-0')));
      await tester.pumpAndSettle();

      expect(repository.refreshCalls, 4);
      expect(find.text('缓存会话'), findsOneWidget);
      expect(find.text(l.networkRequestFailed), findsNothing);
      expect(find.text(l.demoStorageError), findsNothing);
      expect(repository.sessions, [cached]);

      repository.refreshError = null;
      _backgroundAndResume(tester);
      await tester.pumpAndSettle();

      expect(repository.refreshCalls, 5);
      expect(find.text('恢复同步后的会话'), findsOneWidget);
      expect(find.text(l.networkRequestFailed), findsNothing);
      expect(find.text(l.demoStorageError), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expired Harness access cancels initial refresh without a toast',
    (tester) async {
      final cached = _session('cached', '缓存会话');
      final repository =
          _HarnessSyncRepository(await _storage(), cachedSessions: [cached])
            ..refreshError = DioException(
              requestOptions: RequestOptions(path: '/api_agent/v2/sessions'),
              type: DioExceptionType.cancel,
              message: 'Remote Harness access expired',
            );
      addTearDown(repository.dispose);
      await _pumpHome(tester, repository);

      final l = AppLocalizations.of(tester.element(find.byType(DemoHomePage)))!;
      expect(repository.refreshCalls, 1);
      expect(find.text(l.networkRequestFailed), findsNothing);
      expect(find.text(l.demoStorageError), findsNothing);
      expect(find.text('缓存会话'), findsOneWidget);
      expect(repository.sessions, [cached]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'initial Harness refresh failure is safe after home is disposed',
    (tester) async {
      final repository = _HarnessSyncRepository(await _storage());
      addTearDown(repository.dispose);
      final pendingRefresh = repository.blockNextRefresh();
      await _pumpHome(tester, repository);
      expect(repository.refreshCalls, 1);

      await tester.pumpWidget(const SizedBox());
      pendingRefresh.completeError(
        DioException(
          requestOptions: RequestOptions(path: '/api_agent/v2/sessions'),
          type: DioExceptionType.connectionError,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('网络请求失败，请稍后重试'), findsNothing);
      expect(find.text('本地保存失败，请再次操作'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Harness refreshes on resume and tab switches without racing requests',
    (tester) async {
      final repository = _HarnessSyncRepository(await _storage())
        ..remoteSessions = [_session('first', '服务端会话')];
      addTearDown(repository.dispose);
      await _pumpHome(tester, repository);

      expect(repository.refreshCalls, 1);
      expect(find.text('服务端会话'), findsOneWidget);

      repository.remoteSessions = [_session('first', '前台同步后的会话')];
      final foregroundRefresh = repository.blockNextRefresh();
      _backgroundAndResume(tester);
      await tester.pump();
      expect(repository.refreshCalls, 2);

      await tester.tap(find.byKey(const Key('demo-tab-1')));
      await tester.pump();
      expect(repository.refreshCalls, 2);

      foregroundRefresh.complete();
      await tester.pumpAndSettle();
      repository.remoteSessions = [
        _session('first', '前台同步后的会话'),
        _session('second', '另一端新建的会话'),
      ];
      await tester.tap(find.byKey(const Key('demo-tab-0')));
      await tester.pumpAndSettle();

      expect(repository.refreshCalls, 3);
      expect(find.text('前台同步后的会话'), findsOneWidget);
      expect(find.text('另一端新建的会话'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('offline demo never starts Harness synchronization', (
    tester,
  ) async {
    final repository = _OfflineCountingRepository(await _storage())..restore();
    addTearDown(repository.dispose);
    await _pumpHome(tester, repository);

    _backgroundAndResume(tester);
    await tester.tap(find.byKey(const Key('demo-tab-1')));
    await tester.pumpAndSettle();

    expect(repository.refreshCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('foreground sync waits while another route covers home', (
    tester,
  ) async {
    final repository = _HarnessSyncRepository(await _storage())
      ..remoteSessions = [_session('first', '服务端会话')];
    addTearDown(repository.dispose);
    await _pumpHome(tester, repository);
    expect(repository.refreshCalls, 1);

    final homeContext = tester.element(find.byType(DemoHomePage));
    unawaited(
      Navigator.of(homeContext).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('覆盖页面')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('覆盖页面'), findsOneWidget);

    repository.remoteSessions = [_session('first', '稍后再同步')];
    _backgroundAndResume(tester);
    await tester.pumpAndSettle();
    expect(repository.refreshCalls, 1);

    Navigator.of(tester.element(find.text('覆盖页面'))).pop();
    await tester.pumpAndSettle();
    _backgroundAndResume(tester);
    await tester.pumpAndSettle();

    expect(repository.refreshCalls, 2);
    expect(find.text('稍后再同步'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not open a cached session removed by an active refresh', (
    tester,
  ) async {
    final repository = _HarnessSyncRepository(await _storage())
      ..remoteSessions = [_session('first', '即将归档的会话')];
    addTearDown(repository.dispose);
    await _pumpHome(tester, repository);

    repository.remoteSessions = [];
    final pendingRefresh = repository.blockNextRefresh();
    _backgroundAndResume(tester);
    await tester.pump();
    expect(repository.refreshCalls, 2);

    await tester.tap(find.text('即将归档的会话'));
    await tester.pump();
    pendingRefresh.complete();
    await tester.pumpAndSettle();

    expect(find.byType(DemoChatPage), findsNothing);
    expect(find.byType(DemoHomePage), findsOneWidget);
    expect(repository.sessions, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pending automatic refresh is safe after home is disposed', (
    tester,
  ) async {
    final repository = _HarnessSyncRepository(await _storage())
      ..remoteSessions = [_session('first', '服务端会话')];
    addTearDown(repository.dispose);
    await _pumpHome(tester, repository);

    final pendingRefresh = repository.blockNextRefresh();
    _backgroundAndResume(tester);
    await tester.pump();
    expect(repository.refreshCalls, 2);

    await tester.pumpWidget(const SizedBox());
    pendingRefresh.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
