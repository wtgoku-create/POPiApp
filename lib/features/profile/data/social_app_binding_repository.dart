import '../../auth/data/douyin_login_service.dart';
import '../../auth/data/wechat_login_service.dart';
import '../../../shared/type/social_app_type.dart';
import '../domain/social_app_binding.dart';
import 'social_app_binding_api.dart';

/// Reuses native login authorization to bind the current account.
class SocialAppBindingRepository {
  const SocialAppBindingRepository({
    required this.api,
    required this.wechatService,
    required this.douyinService,
  });

  final SocialAppBindingApi api;
  final WechatLoginService wechatService;
  final DouyinLoginService douyinService;

  Future<SocialAppBinding> fetchStatus(SocialAppType app) =>
      api.fetchStatus(app);

  Future<SocialAppBinding> bind(
    SocialAppType app, {
    required bool Function() isCurrentUser,
  }) async {
    final String code;
    switch (app) {
      case SocialAppType.wechat:
        final authorization = await wechatService.authorize();
        code = switch (authorization.status) {
          WechatAuthorizationStatus.authorized => authorization.code!,
          WechatAuthorizationStatus.canceled =>
            throw const SocialBindingException(SocialBindingFailure.canceled),
          WechatAuthorizationStatus.unavailable =>
            throw const SocialBindingException(
              SocialBindingFailure.unavailable,
            ),
          WechatAuthorizationStatus.failed =>
            throw const SocialBindingException(SocialBindingFailure.failed),
        };
      case SocialAppType.douyin:
        final authorization = await douyinService.authorize();
        code = switch (authorization.status) {
          DouyinAuthorizationStatus.authorized => authorization.code!,
          DouyinAuthorizationStatus.canceled =>
            throw const SocialBindingException(SocialBindingFailure.canceled),
          DouyinAuthorizationStatus.unavailable =>
            throw const SocialBindingException(
              SocialBindingFailure.unavailable,
            ),
          DouyinAuthorizationStatus.failed =>
            throw const SocialBindingException(SocialBindingFailure.failed),
        };
    }
    // Authorization can outlive the profile page or the signed-in account.
    if (!isCurrentUser()) {
      throw const SocialBindingException(SocialBindingFailure.canceled);
    }
    return api.bind(app, code);
  }
}
