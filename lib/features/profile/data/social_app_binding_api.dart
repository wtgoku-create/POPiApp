import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../shared/type/social_app_type.dart';
import '../domain/social_app_binding.dart';

/// Profile binding endpoints use the authenticated Dio client.
class SocialAppBindingApi {
  const SocialAppBindingApi(this.dio);

  final Dio dio;

  Future<SocialAppBinding> fetchStatus(SocialAppType app) async {
    final response = switch (app) {
      SocialAppType.wechat => await dio.get<Map<String, dynamic>>(
        '/api_client/users/user/wxAppBindStatus',
      ),
      SocialAppType.douyin => await dio.get<Map<String, dynamic>>(
        '/api_client/users/user/douyinAppBindStatus',
      ),
    };
    return SocialAppBinding.fromJson(_data(response));
  }

  Future<SocialAppBinding> bind(SocialAppType app, String code) async {
    if (code.trim().isEmpty) {
      throw const FormatException('Missing social authorization code');
    }
    final response = await dio.post<Map<String, dynamic>>(
      switch (app) {
        SocialAppType.wechat => '/api_client/users/user/bindWxAppByCode',
        SocialAppType.douyin => '/api_client/users/user/bindDouyinAppByCode',
      },
      data: {'code': code},
    );
    final data = _data(response);
    final binding = SocialAppBinding.fromJson(data);
    if (data['status'] != 'success' || !binding.bound) {
      throw const SocialBindingException(SocialBindingFailure.failed);
    }
    return binding;
  }

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) {
    final body = response.data;
    if (body == null || body['status']?.toString() != '0000') {
      throw ApiException(
        message: body?['message']?.toString(),
        statusCode: response.statusCode,
      );
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) throw const ApiException();
    return data;
  }
}
