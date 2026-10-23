import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/demo/presentation/demo_app.dart';
import 'features/demo/presentation/widgets/demo_frosted_backdrop.dart';
import 'shared/providers/storage_provider.dart';

/// Offline Figma demonstration. Production starts through main.dart as usual.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  await DemoFrostedBackdrop.precache();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const DemoApp(),
    ),
  );
}
