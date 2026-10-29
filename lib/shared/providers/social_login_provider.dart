import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/douyin_login_service.dart';
import '../../features/auth/data/wechat_login_service.dart';
import '../../features/profile/data/social_app_binding_api.dart';
import '../../features/profile/data/social_app_binding_repository.dart';
import 'network_provider.dart';

final douyinLoginServiceProvider = Provider<DouyinLoginService>(
  (ref) => const DouyinLoginService(),
);

/// Shared native authorization and binding contracts for profile and invitations.
final socialAppBindingRepositoryProvider = Provider<SocialAppBindingRepository>(
  (ref) => SocialAppBindingRepository(
    api: SocialAppBindingApi(ref.watch(dioProvider)),
    wechatService: WechatLoginService(),
    douyinService: ref.watch(douyinLoginServiceProvider),
  ),
);
