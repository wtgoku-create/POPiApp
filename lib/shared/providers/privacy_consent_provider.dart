import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'storage_provider.dart';

/// Gates application startup until explicit consent has been persisted.
final privacyConsentProvider = NotifierProvider<PrivacyConsentController, bool>(
  PrivacyConsentController.new,
);

class PrivacyConsentController extends Notifier<bool> {
  static const storageKey = 'privacy_consent_version';
  // Bump when policy changes require renewed consent.
  static const currentVersion = '1';

  @override
  bool build() =>
      ref.watch(preferencesStorageProvider).getString(storageKey) ==
      currentVersion;

  Future<void> accept() async {
    await ref
        .read(preferencesStorageProvider)
        .setString(storageKey, currentVersion);
    state = true;
  }

  Future<void> clear() async {
    await ref.read(preferencesStorageProvider).remove(storageKey);
    state = false;
  }
}
