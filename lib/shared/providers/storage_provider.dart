import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/preferences_storage.dart';
import '../../core/storage/harness_access_storage.dart';
import '../../core/storage/secure_storage.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override sharedPreferencesProvider in main.dart');
});

final preferencesStorageProvider = Provider<PreferencesStorage>(
  (ref) => PreferencesStorage(ref.watch(sharedPreferencesProvider)),
);

final flutterSecureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(
    // Ad-hoc macOS development builds cannot claim Data Protection Keychain
    // entitlements; release builds remain on the modern protected keychain.
    mOptions: MacOsOptions(useDataProtectionKeyChain: kReleaseMode),
  ),
);

final secureStorageProvider = Provider<TokenStorage>(
  (ref) => SecureStorage(ref.watch(flutterSecureStorageProvider)),
);

final harnessAccessStorageProvider = Provider<HarnessAccessStorage>(
  (ref) => SecureHarnessAccessStorage(ref.watch(flutterSecureStorageProvider)),
);

final accessTokenProvider = FutureProvider<String?>(
  (ref) => ref.watch(secureStorageProvider).readAccessToken(),
);
