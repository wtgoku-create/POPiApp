import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/storage/harness_access_storage.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/domain/demo_models.dart';
import 'package:popi_ai_app/features/demo/domain/harness_access_session.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_app.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_home_page.dart';
import 'package:popi_ai_app/features/demo/presentation/harness_access_gate.dart';
import 'package:popi_ai_app/shared/providers/harness_access_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

void main() {
  testWidgets('does not gate local or Web Harness content', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          harnessAccessRequiredProvider.overrideWithValue(false),
        ],
        child: const HarnessAccessGate(
          authenticatedBuilder: _buildPreservedChild,
        ),
      ),
    );

    expect(find.text('open draft'), findsOneWidget);
    expect(find.byKey(const Key('harness-access-username')), findsNothing);
  });

  testWidgets(
    'keeps authenticated content mounted when access is invalidated',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = _MemoryHarnessAccessStorage(
        HarnessAccessSession(
          cookieValue: 'test-session',
          origin: 'https://test.popi.art',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          cacheNamespace: '3cc206dc-e68b-4a27-a8a5-25ce07ba8c02',
        ),
      );
      final controller = HarnessAccessController(
        storage: storage,
        repository: null,
        required: true,
        expectedOrigin: 'https://test.popi.art',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            harnessAccessRequiredProvider.overrideWithValue(true),
            harnessAccessProvider.overrideWith((_) => controller),
          ],
          child: const HarnessAccessGate(
            authenticatedBuilder: _buildPreservedChild,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('open draft'), findsOneWidget);

      await controller.invalidate();
      await tester.pump();

      expect(find.byKey(const Key('harness-access-username')), findsOneWidget);
      expect(find.text('open draft'), findsNothing);
      expect(
        find.text('open draft', skipOffstage: false),
        findsOneWidget,
        reason: 'the open application remains mounted behind the access gate',
      );
    },
  );

  testWidgets(
    'mounts the routed Harness app once and preserves it across reauthentication',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final session = _validSession('test-session');
      final storage = _DelayedHarnessAccessStorage(session);
      final controller = HarnessAccessController(
        storage: storage,
        repository: null,
        required: true,
        expectedOrigin: 'https://test.popi.art',
      );
      final repository = _HarnessGateRepository(
        PreferencesStorage(preferences),
      );
      addTearDown(repository.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            harnessAccessRequiredProvider.overrideWithValue(true),
            harnessAccessProvider.overrideWith((_) => controller),
          ],
          child: HarnessAccessGate(
            authenticatedBuilder: (_) =>
                DemoApp(repository: repository, bootstrapUser: false),
          ),
        ),
      );

      expect(find.byKey(const Key('harness-access-loading')), findsOneWidget);
      expect(find.byType(DemoHomePage), findsNothing);

      storage.completeInitialRead();
      await tester.pumpAndSettle();

      expect(find.byType(DemoHomePage), findsOneWidget);
      expect(repository.refreshCalls, 1);
      final originalHome = tester.state(find.byType(DemoHomePage));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(repository.refreshCalls, 1);

      await controller.invalidate();
      await tester.pump();

      expect(find.byKey(const Key('harness-access-username')), findsOneWidget);
      expect(find.byType(DemoHomePage), findsNothing);
      expect(find.byType(DemoHomePage, skipOffstage: false), findsOneWidget);

      storage.session = _validSession('replacement-session');
      await controller.initialize();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('harness-access-username')), findsNothing);
      expect(find.byType(DemoHomePage), findsOneWidget);
      expect(tester.state(find.byType(DemoHomePage)), same(originalHome));
      expect(repository.refreshCalls, 1);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('standalone DemoApp retains one global toast overlay', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = _HarnessGateRepository(PreferencesStorage(preferences));
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: DemoApp(repository: repository, bootstrapUser: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ToastificationWrapper), findsOneWidget);
    expect(find.byType(DemoHomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

HarnessAccessSession _validSession(String cookieValue) => HarnessAccessSession(
  cookieValue: cookieValue,
  origin: 'https://test.popi.art',
  expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
  cacheNamespace: '3cc206dc-e68b-4a27-a8a5-25ce07ba8c02',
);

Widget _buildPreservedChild(BuildContext context) => const _PreservedChild();

class _PreservedChild extends StatefulWidget {
  const _PreservedChild();

  @override
  State<_PreservedChild> createState() => _PreservedChildState();
}

class _PreservedChildState extends State<_PreservedChild> {
  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(body: Center(child: Text('open draft'))),
  );
}

class _MemoryHarnessAccessStorage implements HarnessAccessStorage {
  _MemoryHarnessAccessStorage(this.session);

  HarnessAccessSession? session;

  @override
  Future<void> deleteSession() async => session = null;

  @override
  Future<HarnessAccessSession?> readSession() async => session;

  @override
  Future<void> writeSession(HarnessAccessSession value) async =>
      session = value;
}

class _DelayedHarnessAccessStorage extends _MemoryHarnessAccessStorage {
  _DelayedHarnessAccessStorage(super.session);

  final _initialRead = Completer<void>();
  bool _initialReadCompleted = false;

  void completeInitialRead() {
    _initialReadCompleted = true;
    _initialRead.complete();
  }

  @override
  Future<HarnessAccessSession?> readSession() async {
    if (!_initialReadCompleted) await _initialRead.future;
    return session;
  }
}

class _HarnessGateRepository extends DemoRepository {
  _HarnessGateRepository(super.storage);

  int refreshCalls = 0;

  @override
  bool get isHarness => true;

  @override
  List<DemoSession> get sessions => const [];

  @override
  List<DemoAsset> get assets => const [];

  @override
  Future<void> refreshSessions() async {
    refreshCalls += 1;
    notifyListeners();
  }
}
