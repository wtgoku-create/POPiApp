import 'package:dio/dio.dart';

import '../../../core/platform/app_platform.dart';
import '../../auth/data/douyin_login_service.dart';
import '../../auth/domain/web_social_login.dart';
import '../../auth/data/wechat_login_service.dart';
import '../../../shared/type/social_app_type.dart';
import '../domain/social_app_binding.dart';
import 'social_app_binding_api.dart';

/// Links the current account without creating or replacing a login session.
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

  Future<WebSocialLoginChallenge> createWebWechatChallenge({
    required CancelToken cancelToken,
  }) async {
    final data = await api.createWebWechatChallenge(cancelToken: cancelToken);
    _checkCancellation(cancelToken);
    return WebSocialLoginChallenge.fromJson(data, douyin: false);
  }

  Future<SocialAppBinding?> checkWebWechatBinding(
    String sceneCode, {
    required CancelToken cancelToken,
  }) async {
    final data = await api.checkWebWechatBinding(
      sceneCode,
      cancelToken: cancelToken,
    );
    _checkCancellation(cancelToken);
    if (data['bound'] != true && data['status'] != 'success') return null;
    // Linking is complete even if the subsequent nickname refresh fails.
    try {
      final binding = await fetchStatus(SocialAppType.wechat);
      _checkCancellation(cancelToken);
      if (binding.bound) return binding;
    } catch (_) {
      _checkCancellation(cancelToken);
    }
    return const SocialAppBinding(bound: true);
  }

  void _checkCancellation(CancelToken token) {
    if (token.isCancelled) throw token.cancelError!;
  }

  Future<SocialAppBinding> bind(
    SocialAppType app, {
    required bool Function() isCurrentUser,
  }) async {
    if (AppPlatform.current.isWeb) {
      throw const SocialBindingException(SocialBindingFailure.unavailable);
    }
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
