import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_api.dart';
import '../../features/ip_guide/data/ip_guide_repository.dart';
import 'network_provider.dart';
import 'storage_provider.dart';
import 'user_provider.dart';

final ipGuideRepositoryProvider = Provider<IpGuideRepository>((ref) {
  final repository = IpGuideRepository(
    ref.watch(preferencesStorageProvider),
    NetworkApi(ref.watch(dioProvider)),
    userId: ref.watch(userProvider.select((user) => user?.id)),
  );
  ref.onDispose(repository.dispose);
  return repository;
});
