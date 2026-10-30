import 'package:dio/dio.dart';

import '../../../core/network/network_api.dart';
import '../../../core/platform/app_platform.dart';
import '../../../shared/type/social_app_type.dart';
import '../domain/social_app_binding.dart';

/// Uses authenticated binding endpoints for each runtime.
class SocialAppBindingApi {
  const SocialAppBindingApi(this.dio);

  final Dio dio;

  Future<SocialAppBinding> fetchStatus(SocialAppType app) async {
    final api = NetworkApi(dio);
    final data = AppPlatform.current.isWeb && app == SocialAppType.wechat
        ? await api.wechatOfficialBindingStatus()
        : await api.socialAppBindingStatus(app);
    return SocialAppBinding.fromJson(data);
  }

  Future<Map<String, dynamic>> createWebWechatChallenge({
    required CancelToken cancelToken,
  }) => NetworkApi(dio).wechatOfficialBindingQrCode(cancelToken: cancelToken);

  Future<Map<String, dynamic>> checkWebWechatBinding(
    String sceneCode, {
    required CancelToken cancelToken,
  }) => NetworkApi(
    dio,
  ).checkWechatOfficialBinding(sceneCode, cancelToken: cancelToken);

  Future<SocialAppBinding> bind(SocialAppType app, String code) async {
    if (code.trim().isEmpty) {
      throw const FormatException('Missing social authorization code');
    }
    final data = await NetworkApi(dio).bindSocialApp(app, code);
    final binding = SocialAppBinding.fromJson(data);
    if (data['status'] != 'success' || !binding.bound) {
      throw const SocialBindingException(SocialBindingFailure.failed);
    }
    return binding;
  }
}
