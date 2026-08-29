import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:popi_ai_app/app/app.dart';
import 'package:popi_ai_app/features/home/presentation/home_page.dart';
import 'package:popi_ai_app/features/settings/presentation/settings_page.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';

void main() {
  testWidgets('renders the starter app', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const StarterApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('你现在最想做什么？'), findsOneWidget);
  });

  testWidgets('drawer routes preserve a back stack', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const StarterApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('打开导航'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skill'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    final settingsContext = tester.element(find.byType(SettingsPage));
    expect(Navigator.of(settingsContext).canPop(), isTrue);

    Navigator.of(settingsContext).pop();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
  });
}
