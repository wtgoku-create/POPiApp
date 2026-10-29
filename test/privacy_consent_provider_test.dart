import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/shared/providers/privacy_consent_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences preferences;
  late ProviderContainer container;

  ProviderContainer createContainer({PreferencesStorage? storage}) {
    final result = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        if (storage != null)
          preferencesStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(result.dispose);
    return result;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    container = createContainer();
  });

  test('requires explicit consent on first launch', () {
    expect(container.read(privacyConsentProvider), isFalse);
  });

  test('persists acceptance and restores it in a new container', () async {
    await container.read(privacyConsentProvider.notifier).accept();

    expect(container.read(privacyConsentProvider), isTrue);
    expect(
      preferences.getString(PrivacyConsentController.storageKey),
      PrivacyConsentController.currentVersion,
    );
    expect(createContainer().read(privacyConsentProvider), isTrue);
  });

  test('requires renewed consent for an older policy version', () async {
    await preferences.setString(PrivacyConsentController.storageKey, 'old');
    expect(createContainer().read(privacyConsentProvider), isFalse);
  });

  test('clears both the state and persisted acceptance', () async {
    await container.read(privacyConsentProvider.notifier).accept();
    await container.read(privacyConsentProvider.notifier).clear();

    expect(container.read(privacyConsentProvider), isFalse);
    expect(
      preferences.containsKey(PrivacyConsentController.storageKey),
      isFalse,
    );
    expect(createContainer().read(privacyConsentProvider), isFalse);
  });

  test('does not allow startup until persistence finishes', () async {
    final storage = _ControlledStorage(preferences)
      ..completion = Completer<void>();
    final delayed = createContainer(storage: storage);
    final acceptance = delayed.read(privacyConsentProvider.notifier).accept();
    expect(delayed.read(privacyConsentProvider), isFalse);
    storage.completion!.complete();
    await acceptance;
    expect(delayed.read(privacyConsentProvider), isTrue);
  });

  test(
    'failed persistence keeps consent unset and allows another attempt',
    () async {
      final storage = _ControlledStorage(preferences)..failWrites = true;
      final failing = createContainer(storage: storage);
      await expectLater(
        failing.read(privacyConsentProvider.notifier).accept(),
        throwsStateError,
      );
      expect(failing.read(privacyConsentProvider), isFalse);
      expect(createContainer().read(privacyConsentProvider), isFalse);

      storage.failWrites = false;
      await failing.read(privacyConsentProvider.notifier).accept();
      expect(failing.read(privacyConsentProvider), isTrue);
    },
  );

  test('failed clearing preserves the last persisted state', () async {
    final storage = _ControlledStorage(preferences);
    final failing = createContainer(storage: storage);
    await failing.read(privacyConsentProvider.notifier).accept();
    storage.failRemoves = true;
    await expectLater(
      failing.read(privacyConsentProvider.notifier).clear(),
      throwsStateError,
    );
    expect(failing.read(privacyConsentProvider), isTrue);
    expect(createContainer().read(privacyConsentProvider), isTrue);
  });
}

class _ControlledStorage extends PreferencesStorage {
  _ControlledStorage(super.preferences);

  Completer<void>? completion;
  bool failWrites = false;
  bool failRemoves = false;

  @override
  Future<void> setString(String key, String value) async {
    await completion?.future;
    if (failWrites) throw StateError('Storage unavailable');
    await super.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    if (failRemoves) throw StateError('Storage unavailable');
    await super.remove(key);
  }
}
