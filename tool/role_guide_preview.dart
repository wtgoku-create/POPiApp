import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:popi_ai_app/app/router.dart';
import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/features/assets/data/role_library_repository.dart';
import 'package:popi_ai_app/features/assets/domain/library_role.dart';
import 'package:popi_ai_app/features/auth/domain/user.dart';
import 'package:popi_ai_app/features/role_guide/data/role_guide_examples.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/safe_area_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final roles = roleGuideExamples(lookupAppLocalizations(const Locale('zh')));
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      rolePageLoaderProvider.overrideWithValue(
        ({required category, required page, required pageSize}) async =>
            LibraryRolePage(
              items: category == 'official' ? roles : roles.take(2).toList(),
              page: page,
              pageCount: 1,
            ),
      ),
      roleDetailLoaderProvider.overrideWithValue(
        (id) async => roles.firstWhere((role) => role.id == id),
      ),
    ],
  );
  await container
      .read(userProvider.notifier)
      .setUser(
        const User(id: 'preview', name: '逍遥的小柯子', email: '', allCoins: 200),
      );
  container
      .read(safeAreaInsetsProvider.notifier)
      .update(const EdgeInsets.only(top: 52, bottom: 34));
  final router = container.read(routerProvider(false));
  router.go('/role-guide');
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    ),
  );
}
