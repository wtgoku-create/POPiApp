import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:popi_ai_app/app/theme.dart';
import 'package:popi_ai_app/app/router.dart';
import 'package:popi_ai_app/l10n/generated/app_localizations.dart';
import 'package:popi_ai_app/shared/providers/safe_area_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(preferences),
  ]);
  container.read(safeAreaInsetsProvider.notifier).update(
        const EdgeInsets.only(top: 52, bottom: 15),
      );
  runApp(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: container.read(routerProvider(false)),
    ),
  ));
}
