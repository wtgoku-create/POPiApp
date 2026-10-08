import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/wechat_login_service.dart';
import '../../features/profile/data/social_app_binding_api.dart';
import '../../features/profile/data/social_app_binding_repository.dart';
import 'network_provider.dart';
import 'social_login_provider.dart';

final socialAppBindingRepositoryProvider = Provider<SocialAppBindingRepository>(
  (ref) => SocialAppBindingRepository(
    api: SocialAppBindingApi(ref.watch(dioProvider)),
    wechatService: WechatLoginService(),
    douyinService: ref.watch(douyinLoginServiceProvider),
  ),
);
