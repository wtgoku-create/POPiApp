import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/profile/presentation/profile_page.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

void main() {
  testWidgets('copies the UID when its label is tapped', (tester) async {
    String? clipboardText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);
    await container.read(userProvider.notifier).setUser(
          const User(
            id: '10561',
            code: 'u10561',
            name: '当前用户',
            email: 'user@popi.art',
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ToastificationWrapper(
          child: MaterialApp(
            theme: AppTheme.light,
            locale: const Locale('zh'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const ProfilePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final copyTarget = find.byKey(const Key('profile-uid-copy'));
    final uidLabel = find.text('UID:u10561');
    final targetRect = tester.getRect(copyTarget);
    final labelRect = tester.getRect(uidLabel);
    expect(targetRect.height, 40);
    expect(targetRect.contains(labelRect.center), isTrue);

    await tester.tap(uidLabel);
    await tester.pump();
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );

    expect(clipboardText, 'u10561');
    expect(find.text('UID 已复制'), findsOneWidget);

    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(milliseconds: 700));
  });
}
