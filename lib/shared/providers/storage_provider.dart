import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/preferences_storage.dart';
import '../../core/storage/secure_storage.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override sharedPreferencesProvider in main.dart');
});

final preferencesStorageProvider = Provider<PreferencesStorage>(
  (ref) => PreferencesStorage(ref.watch(sharedPreferencesProvider)),
);

final secureStorageProvider = Provider<TokenStorage>(
  (ref) => const SecureStorage(FlutterSecureStorage()),
);

final accessTokenProvider = FutureProvider<String?>(
  (ref) => ref.watch(secureStorageProvider).readAccessToken(),
);
