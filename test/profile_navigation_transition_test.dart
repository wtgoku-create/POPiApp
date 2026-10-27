import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:popi_ai_app/app/router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/profile/presentation/profile_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/local_profile_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

void main() {
  testWidgets('profile enters from the physical left and exits to the left', (
    tester,
  ) async {
    final router = await _pumpApp(tester);
    addTearDown(router.dispose);

    await tester.tap(find.byKey(const Key('profile-entry')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));

    final entering = _profileRect(tester);
    expect(entering.left, lessThan(0));
    expect(entering.right, greaterThan(0));

    await tester.pumpAndSettle();
    expect(_profileRect(tester).left, closeTo(0, .01));

    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));

    final exiting = _profileRect(tester);
    expect(exiting.left, lessThan(0));
    expect(exiting.right, greaterThan(0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('transition-home')), findsOneWidget);
    expect(find.byType(ProfilePage), findsNothing);
    expect(tester.takeException(), isNull);
  }, skip: !kIsWeb);

  testWidgets('reduced motion shows and dismisses profile without sliding', (
    tester,
  ) async {
    final router = await _pumpApp(tester, disableAnimations: true);
    addTearDown(router.dispose);

    await tester.tap(find.byKey(const Key('profile-entry')));
    await tester.pump();
    expect(_profileRect(tester).left, closeTo(0, .01));

    router.pop();
    await tester.pump();
    expect(find.byType(ProfilePage), findsNothing);
    expect(find.byKey(const Key('transition-home')), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, skip: !kIsWeb);

  testWidgets('native profile keeps the platform route and pop contract', (
    tester,
  ) async {
    final router = await _pumpApp(tester, platform: TargetPlatform.iOS);
    addTearDown(router.dispose);

    await tester.tap(find.byKey(const Key('profile-entry')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(_profileRect(tester).left, greaterThan(0));
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('transition-home')), findsOneWidget);
    expect(tester.takeException(), isNull);
  }, skip: kIsWeb);
}

Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  bool disableAnimations = false,
  TargetPlatform? platform,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      localProfileEnabledProvider.overrideWithValue(true),
      sharedPreferencesProvider.overrideWithValue(preferences),
    ],
  );
  addTearDown(container.dispose);
  final router = createAppRouter(
    homeBuilder: (context, _) => Scaffold(
      key: const Key('transition-home'),
      appBar: AppBar(
        leading: IconButton(
          key: const Key('profile-entry'),
          tooltip: '个人资料',
          onPressed: () => context.push('/profile'),
          icon: const CircleAvatar(child: Icon(Icons.person_outline)),
        ),
      ),
    ),
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ToastificationWrapper(
        child: MaterialApp.router(
          theme: AppTheme.light.copyWith(platform: platform),
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Rect _profileRect(WidgetTester tester) => tester.getRect(
  find.descendant(
    of: find.byType(ProfilePage),
    matching: find.byType(Scaffold),
  ),
);
