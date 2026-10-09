import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/network_api.dart';
import '../../features/payments/data/apple_payment_repository.dart';
import '../../features/payments/data/apple_payment_store.dart';
import '../../features/payments/data/apple_purchase_service.dart';
import '../../features/payments/data/pending_apple_purchase_storage.dart';
import 'network_provider.dart';
import 'storage_provider.dart';
import 'user_provider.dart';

final applePurchaseServiceProvider = Provider<ApplePurchaseService>((ref) {
  final userId = ref.watch(userProvider.select((user) => user?.id ?? ''));
  var disposed = false;
  final service = ApplePurchaseService(
    repository: ApplePaymentRepository(NetworkApi(ref.watch(dioProvider))),
    storage: PendingApplePurchaseStorage(
      ref.watch(preferencesStorageProvider),
      userId,
    ),
    store: NativeApplePaymentStore(),
    environment: AppConfig.applePaymentEnvironment,
    supported: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
    onCompleted: () async {
      if (disposed || ref.read(userProvider)?.id != userId) return;
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
  service.start();
  ref.onDispose(() {
    disposed = true;
    service.dispose();
  });
  return service;
});
