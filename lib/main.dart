import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/popi_app.dart';
import 'core/platform/app_platform.dart';
import 'features/demo/presentation/widgets/demo_frosted_backdrop.dart';
import 'features/v2_shared/presentation/widgets/v2_frosted_backdrop.dart';
import 'shared/providers/storage_provider.dart';

/// The application entry point for this branch in every environment.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  if (AppPlatform.current.isWeb) {
    await DemoFrostedBackdrop.precache();
  } else {
    await V2FrostedBackdrop.precache();
  }
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const PopiApp(),
    ),
  );
}
