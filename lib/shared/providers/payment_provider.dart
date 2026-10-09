import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_api.dart';
import '../../features/payments/data/android_payment_sdk.dart';
import '../../features/payments/data/android_payment_service.dart';
import '../../features/payments/data/payment_repository.dart';
import '../../features/payments/data/pending_payment_storage.dart';
import 'network_provider.dart';
import 'storage_provider.dart';
import 'user_provider.dart';

/// SDK coordination spans pages; pending references are isolated per account.
final androidPaymentServiceProvider = Provider<AndroidPaymentService>((ref) {
  final userId = ref.watch(userProvider.select((user) => user?.id ?? ''));
  var disposed = false;
  final service = AndroidPaymentService(
    repository: PaymentRepository(NetworkApi(ref.watch(dioProvider))),
    storage: PendingPaymentStorage(
      ref.watch(preferencesStorageProvider),
      userId,
    ),
    sdk: NativeAndroidPaymentSdk(),
    supported: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
    onCompleted: () async {
      if (ref.read(userProvider)?.id != userId) return;
      try {
        final user = await ref.read(authRepositoryProvider).fetchCurrentUser();
        if (disposed ||
            ref.read(userProvider)?.id != userId ||
            user.id != userId) {
          return;
        }
        await ref.read(userProvider.notifier).setUser(user);
      } catch (_) {
        // A profile refresh failure should still allow the balance to refresh.
      }
      if (disposed || ref.read(userProvider)?.id != userId) return;
      await ref.read(userPointsProvider.notifier).refresh();
    },
  );
  ref.onDispose(() {
    disposed = true;
    service.dispose();
  });
  return service;
});
