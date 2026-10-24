import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../features/profile/data/local_profile_repository.dart';
import '../../features/profile/domain/local_profile.dart';
import 'storage_provider.dart';

final localProfileEnabledProvider = Provider<bool>(
  (ref) => AppConfig.harnessEnabled,
);

final localProfileRepositoryProvider = Provider<LocalProfileRepository>((ref) {
  return LocalProfileRepository(ref.watch(preferencesStorageProvider));
});

final localProfileProvider =
    NotifierProvider<LocalProfileController, LocalProfile?>(
      LocalProfileController.new,
    );

/// Serializes local profile writes and publishes only successfully saved data.
class LocalProfileController extends Notifier<LocalProfile?> {
  Future<void> _pendingWrite = Future.value();

  @override
  LocalProfile? build() {
    if (!ref.watch(localProfileEnabledProvider)) return null;
    return ref.watch(localProfileRepositoryProvider).restore();
  }

  Future<void> updateProfile({required String name, Uint8List? avatarBytes}) =>
      _enqueueWrite(() async {
        if (!ref.read(localProfileEnabledProvider)) {
          throw StateError('Local profile is disabled');
        }
        final repository = ref.read(localProfileRepositoryProvider);
        final saved = await repository.save(
          name: name,
          avatarBytes: avatarBytes ?? state?.avatarBytes,
        );
        state = saved;
      });

  Future<void> clearProfile() => _enqueueWrite(() async {
    if (!ref.read(localProfileEnabledProvider)) {
      throw StateError('Local profile is disabled');
    }
    await ref.read(localProfileRepositoryProvider).clear();
    state = null;
  });

  Future<void> _enqueueWrite(Future<void> Function() operation) {
    final result = _pendingWrite.then((_) => operation());
    _pendingWrite = result.catchError((Object _) {});
    return result;
  }
}
