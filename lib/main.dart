import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'shared/providers/storage_provider.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  binding.deferFirstFrame();
  final preferences = await SharedPreferences.getInstance();
  var firstFrameAllowed = false;

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: StarterApp(
        onReady: () {
          if (firstFrameAllowed) return;
          firstFrameAllowed = true;
          binding.allowFirstFrame();
        },
      ),
    ),
  );
}
