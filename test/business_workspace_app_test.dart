import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

import 'package:popi_ai_app/app/business_workspace_app.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/demo/data/demo_repository.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_chat_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_home_page.dart';
import 'package:popi_ai_app/features/demo/presentation/demo_settings_page.dart';
import 'package:popi_ai_app/features/v2_home/presentation/v2_guest_page.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:popi_ai_app/shared/providers/workspace_repository_provider.dart';

void main() {
  tearDown(() {
    toastification.dismissAll(delayForAnimation: false);
  });

  testWidgets(
    'authenticated Web entry mounts the complete original workspace',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = DemoRepository(PreferencesStorage(preferences))
        ..restore();
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            userBootstrapProvider.overrideWith((ref) async {}),
            userProvider.overrideWith(_SignedInUser.new),
            workspaceRepositoryProvider.overrideWith((ref) async => repository),
          ],
          child: const BusinessWorkspaceApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DemoHomePage), findsOneWidget);
      expect(find.byType(DemoChatPage).hitTestable(), findsOneWidget);
      expect(find.byType(DemoSettingsPage), findsOneWidget);
      expect(
        find.byKey(const Key('demo-desktop-sidebar-frame')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('demo-desktop-inspector-frame')),
        findsOneWidget,
      );
      final second = repository.sessions[1];
      await tester.tap(find.byKey(Key('demo-desktop-session-${second.id}')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DemoSettingsPage>(find.byType(DemoSettingsPage))
            .sessionId,
        second.id,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('signed-out Web entry retains the shared guest login flow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          userBootstrapProvider.overrideWith((ref) async {}),
        ],
        child: const BusinessWorkspaceApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(V2GuestPage), findsOneWidget);
    expect(find.byType(DemoHomePage), findsNothing);
    expect(find.byKey(const Key('v2-guest-login')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _SignedInUser extends UserController {
  @override
  User? build() => const User(id: 'owner', name: 'Owner', email: '');
}
