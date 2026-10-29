import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/v2_app.dart';
import 'features/v2_shared/presentation/widgets/v2_frosted_backdrop.dart';
import 'shared/providers/storage_provider.dart';

/// The application entry point for this branch in every environment.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  await V2FrostedBackdrop.precache();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const V2App(),
    ),
  );
}
