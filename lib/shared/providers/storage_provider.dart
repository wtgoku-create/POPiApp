import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/storage/preferences_storage.dart';
import '../../core/storage/harness_access_storage.dart';
import '../../core/storage/secure_storage.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override sharedPreferencesProvider in main.dart');
});

final preferencesStorageProvider = Provider<PreferencesStorage>(
  (ref) => PreferencesStorage(ref.watch(sharedPreferencesProvider)),
);

@visibleForTesting
MacOsOptions macOsStorageOptions({
  bool remoteHarnessEnabled = AppConfig.remoteHarnessEnabled,
  bool releaseMode = kReleaseMode,
}) {
  // Developer ID distribution without a provisioning profile cannot claim
  // the restricted Data Protection Keychain entitlement. The private
  // file-based macOS keychain stays encrypted and needs no sharing group.
  if (remoteHarnessEnabled && releaseMode) {
    // Keep the distributed test app isolated from the debug app's legacy
    // keychain service so replacing either bundle never prompts for the other.
    return const MacOsOptions(
      accountName: 'com.popistudio.app.harness.remote',
      useDataProtectionKeyChain: false,
    );
  }
  return MacOsOptions(useDataProtectionKeyChain: releaseMode);
}

final flutterSecureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => FlutterSecureStorage(mOptions: macOsStorageOptions()),
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
