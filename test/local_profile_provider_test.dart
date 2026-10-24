import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/profile/data/local_profile_repository.dart';
import 'package:popi_ai_app/shared/providers/local_profile_provider.dart';
import 'package:popi_ai_app/shared/providers/storage_provider.dart';
import 'package:popi_ai_app/shared/providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingStorage extends PreferencesStorage {
  _FailingStorage(super.preferences);

  @override
  Future<void> setString(String key, String value) async {
    throw StateError('Disk unavailable');
  }
}

class _ControlledStorage extends PreferencesStorage {
  _ControlledStorage(super.preferences);

  final gate = Completer<void>();

  @override
  Future<void> setString(String key, String value) async {
    await gate.future;
    await super.setString(key, value);
  }
}

class _DelayedFirstStorage extends PreferencesStorage {
  _DelayedFirstStorage(super.preferences);

  final firstStarted = Completer<void>();
  final releaseFirst = Completer<void>();
  int writes = 0;

  @override
  Future<void> setString(String key, String value) async {
    writes++;
    if (writes == 1) {
      firstStarted.complete();
      await releaseFirst.future;
    }
    await super.setString(key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> preferences([
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  ProviderContainer container(
    SharedPreferences sharedPreferences, {
    PreferencesStorage? storage,
  }) {
    return ProviderContainer(
      overrides: [
        localProfileEnabledProvider.overrideWithValue(true),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        if (storage != null)
          preferencesStorageProvider.overrideWithValue(storage),
      ],
    );
  }

  test('disabled local profile does not require storage', () async {
    final disabled = ProviderContainer(
      overrides: [localProfileEnabledProvider.overrideWithValue(false)],
    );
    addTearDown(disabled.dispose);

    expect(disabled.read(localProfileProvider), isNull);
    await expectLater(
      disabled
          .read(localProfileProvider.notifier)
          .updateProfile(name: 'Ignored'),
      throwsStateError,
    );
  });

  test('saves, restores, preserves avatar, and clears local profile', () async {
    final sharedPreferences = await preferences();
    final first = container(sharedPreferences);
    final avatar = Uint8List.fromList([1, 2, 3, 4]);

    expect(first.read(localProfileProvider), isNull);
    await first
        .read(localProfileProvider.notifier)
        .updateProfile(name: '  本地昵称  ', avatarBytes: avatar);
    expect(first.read(localProfileProvider)?.name, '本地昵称');
    expect(first.read(localProfileProvider)?.avatarBytes, avatar);
    expect(first.read(userStatusProvider).name, 'guest');
    first.dispose();

    final restored = container(sharedPreferences);
    expect(restored.read(localProfileProvider)?.name, '本地昵称');
    expect(restored.read(localProfileProvider)?.avatarBytes, avatar);
    await restored
        .read(localProfileProvider.notifier)
        .updateProfile(name: '第二个名字');
    expect(restored.read(localProfileProvider)?.avatarBytes, avatar);
    await restored.read(localProfileProvider.notifier).clearProfile();
    expect(restored.read(localProfileProvider), isNull);
    restored.dispose();

    final afterClear = container(sharedPreferences);
    addTearDown(afterClear.dispose);
    expect(afterClear.read(localProfileProvider), isNull);
  });

  test('publishes only after persistence succeeds', () async {
    final sharedPreferences = await preferences();
    final storage = _ControlledStorage(sharedPreferences);
    final scope = container(sharedPreferences, storage: storage);
    addTearDown(scope.dispose);

    final saving = scope
        .read(localProfileProvider.notifier)
        .updateProfile(name: '稍后保存');
    await Future<void>.delayed(Duration.zero);
    expect(scope.read(localProfileProvider), isNull);

    storage.gate.complete();
    await saving;
    expect(scope.read(localProfileProvider)?.name, '稍后保存');
  });

  test('failed persistence keeps the previously published profile', () async {
    final sharedPreferences = await preferences({
      LocalProfileRepository.storageKey: '{"name":"旧名字","avatar":"AQID"}',
    });
    final scope = container(
      sharedPreferences,
      storage: _FailingStorage(sharedPreferences),
    );
    addTearDown(scope.dispose);

    expect(scope.read(localProfileProvider)?.name, '旧名字');
    await expectLater(
      scope.read(localProfileProvider.notifier).updateProfile(name: '新名字'),
      throwsStateError,
    );
    expect(scope.read(localProfileProvider)?.name, '旧名字');
    expect(scope.read(localProfileProvider)?.avatarBytes, [1, 2, 3]);
  });

  test(
    'serializes writes so clear cannot be undone by a delayed save',
    () async {
      final sharedPreferences = await preferences();
      final storage = _DelayedFirstStorage(sharedPreferences);
      final scope = container(sharedPreferences, storage: storage);
      addTearDown(scope.dispose);

      final saving = scope
          .read(localProfileProvider.notifier)
          .updateProfile(name: '即将清除');
      await storage.firstStarted.future;
      final clearing = scope.read(localProfileProvider.notifier).clearProfile();
      storage.releaseFirst.complete();
      await Future.wait([saving, clearing]);

      expect(scope.read(localProfileProvider), isNull);
      expect(
        sharedPreferences.getString(LocalProfileRepository.storageKey),
        isNull,
      );
    },
  );

  test('rejects empty, overlength, and oversized profile data', () async {
    final sharedPreferences = await preferences();
    final repository = LocalProfileRepository(
      PreferencesStorage(sharedPreferences),
    );

    await expectLater(repository.save(name: '   '), throwsFormatException);
    await expectLater(
      repository.save(name: List.filled(16, '🙂').join()),
      throwsFormatException,
    );
    await expectLater(
      repository.save(
        name: '头像过大',
        avatarBytes: Uint8List(LocalProfileRepository.maxAvatarBytes + 1),
      ),
      throwsFormatException,
    );
  });
}
