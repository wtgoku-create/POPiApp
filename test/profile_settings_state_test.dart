import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/profile/presentation/profile_page.dart';
import 'package:popi_ai_app/shared/providers/settings_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
  });

  tearDown(() => container.dispose());

  Future<void> mount(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder menuIn(Finder page, int index) => find
      .descendant(of: page, matching: find.byType(TreeSettingsMenu))
      .at(index);

  Future<void> toggle(WidgetTester tester, Finder menu) async {
    final row = find.descendant(of: menu, matching: find.byType(SettingsRow));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  for (var index = 0; index < 2; index++) {
    final name = index == 0 ? 'language' : 'theme';
    testWidgets('$name expansion is isolated between profile instances', (
      tester,
    ) async {
      const firstKey = Key('first-profile');
      const secondKey = Key('second-profile');
      await mount(
        tester,
        const Row(
          children: [
            Expanded(child: ProfilePage(key: firstKey)),
            Expanded(child: ProfilePage(key: secondKey)),
          ],
        ),
      );
      final firstMenu = menuIn(find.byKey(firstKey), index);
      final secondMenu = menuIn(find.byKey(secondKey), index);
      await toggle(tester, firstMenu);
      expect(tester.widget<TreeSettingsMenu>(firstMenu).expanded, isTrue);
      expect(tester.widget<TreeSettingsMenu>(secondMenu).expanded, isFalse);
      await toggle(tester, secondMenu);
      await toggle(tester, firstMenu);
      expect(tester.widget<TreeSettingsMenu>(firstMenu).expanded, isFalse);
      expect(tester.widget<TreeSettingsMenu>(secondMenu).expanded, isTrue);
    });

    testWidgets('$name menu starts collapsed when profile is reopened', (
      tester,
    ) async {
      await mount(tester, const ProfilePage());
      final menu = menuIn(find.byType(ProfilePage), index);
      await toggle(tester, menu);
      expect(tester.widget<TreeSettingsMenu>(menu).expanded, isTrue);
      await tester.pumpWidget(const SizedBox());
      await mount(tester, const ProfilePage());
      expect(tester.widget<TreeSettingsMenu>(menu).expanded, isFalse);
    });
  }

  testWidgets('selections update shared settings and collapse local menus', (
    tester,
  ) async {
    await mount(tester, const ProfilePage());
    final page = find.byType(ProfilePage);
    final language = menuIn(page, 0);
    await toggle(tester, language);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(container.read(localeProvider), const Locale('en'));
    expect(tester.widget<TreeSettingsMenu>(language).expanded, isFalse);

    final theme = menuIn(page, 1);
    await toggle(tester, theme);
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(tester.widget<TreeSettingsMenu>(theme).expanded, isFalse);
    expect(
      container.read(preferencesStorageProvider).getString('locale'),
      'en',
    );
    expect(
      container.read(preferencesStorageProvider).getString('theme_mode'),
      'dark',
    );
  });

  testWidgets('a pending selection can complete after the profile closes', (
    tester,
  ) async {
    final completion = Completer<void>();
    final preferences = container.read(sharedPreferencesProvider);
    container.dispose();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        localeProvider.overrideWith(() => _DelayedLocaleController(completion)),
      ],
    );
    await mount(tester, const ProfilePage());
    await toggle(tester, menuIn(find.byType(ProfilePage), 0));
    await tester.tap(find.text('English'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    completion.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _DelayedLocaleController extends LocaleController {
  _DelayedLocaleController(this.completion);

  final Completer<void> completion;

  @override
  Future<void> setLocale(Locale? locale) {
    state = locale;
    return completion.future;
  }
}
