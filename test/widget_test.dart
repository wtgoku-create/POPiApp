import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:popi_ai_app/app/app.dart';
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

    expect(find.text('POPi'), findsOneWidget);
  });
}
