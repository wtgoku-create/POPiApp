import 'package:dio/dio.dart';

import '../../../core/network/network_api.dart';
import '../../../shared/type/social_app_type.dart';
import '../domain/social_app_binding.dart';

/// Profile binding endpoints use the authenticated Dio client.
class SocialAppBindingApi {
  const SocialAppBindingApi(this.dio);

  final Dio dio;

  Future<SocialAppBinding> fetchStatus(SocialAppType app) async {
    final data = await NetworkApi(dio).socialAppBindingStatus(app);
    return SocialAppBinding.fromJson(data);
  }

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
