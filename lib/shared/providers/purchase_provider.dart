import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_api.dart';
import '../../features/payments/data/apple_purchase_service.dart';
import 'network_provider.dart';

final applePurchaseServiceProvider = Provider<ApplePurchaseService>((ref) {
  final service = ApplePurchaseService(
    networkApi: NetworkApi(ref.watch(dioProvider)),
  );
  ref.onDispose(service.dispose);
  return service;
});
