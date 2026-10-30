import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/douyin_login_service.dart';
import '../../features/auth/data/web_social_auth_repository.dart';
import '../../features/auth/data/web_login_progress.dart';
import '../../core/network/network_api.dart';
import 'network_provider.dart';
import 'storage_provider.dart';

final webSocialAuthRepositoryProvider = Provider<WebSocialAuthRepository>(
  (ref) => WebSocialAuthRepository(
    NetworkApi(ref.watch(dioProvider)),
    ref.watch(secureStorageProvider),
  ),
);

final webLoginProgressProvider = Provider<WebLoginProgress>(
  (ref) => WebLoginProgress(ref.watch(preferencesStorageProvider)),
);

final douyinLoginServiceProvider = Provider<DouyinLoginService>(
  (ref) => const DouyinLoginService(),
);
