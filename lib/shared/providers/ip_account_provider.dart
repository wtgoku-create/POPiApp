import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/network_api.dart';
import '../../features/ip_accounts/data/ip_account_repository.dart';
import 'network_provider.dart';

final ipAccountRepositoryProvider = Provider<IpAccountRepository>(
  (ref) => IpAccountRepository(NetworkApi(ref.watch(dioProvider))),
);
