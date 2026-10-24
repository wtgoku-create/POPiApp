import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/storage/harness_access_storage.dart';
import 'package:popi_ai_app/features/demo/domain/harness_access_session.dart';
import 'package:popi_ai_app/features/demo/presentation/harness_access_gate.dart';
import 'package:popi_ai_app/shared/providers/harness_access_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}

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
