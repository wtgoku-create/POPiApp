import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Centralizes concrete HTTP contracts shared by feature data sources.
class NetworkApi {
  const NetworkApi(this.dio);

  final Dio dio;

  Future<Map<String, dynamic>> createCaptcha() async {
    final response = await dio.get<Map<String, dynamic>>(
      '/api_client/captcha/gen',
    );
    return _data(response);
  }

  Future<void> sendLoginCode({
    required String phone,
    required String captchaId,
    required String captchaValue,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      '/api_client/auth/code',
      queryParameters: {
        'phone': phone,
        'usage': 'LOGIN',
        'captchaId': captchaId,
        'captchaValue': captchaValue,
      },
    );
    _data(response);
  }

  Future<Map<String, dynamic>> loginByCode({
    required String phone,
    required String code,
    required String inviteCode,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/api_client/auth/loginByCode',
      data: {'phone': phone, 'code': code, 'inviteCode': inviteCode},
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> currentUser() async {
    final response = await dio.get<Map<String, dynamic>>(
      '/api_client/users/user/info',
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> userPoints() async {
    final response = await dio.get<Map<String, dynamic>>(
      '/api_client/users/userPoints/total',
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> userPointsLog({
    required int page,
    required int pageSize,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      '/api_client/users/userPointsLog/list',
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return _data(response);
  }

  Future<List<dynamic>> pointPackages() async {
    final response = await dio.get<dynamic>(
      '/api_client/users/pointPackage/list',
    );
    final body = response.data;
    if (body is List) return body;
    if (body is! Map) throw const ApiException();
    if (body['status']?.toString() != '0000') {
      throw ApiException(
        message: body['message']?.toString(),
        statusCode: response.statusCode,
      );
    }
    final data = body['data'];
    if (data is! List) throw const ApiException();
    return data;
  }

  Future<List<dynamic>> productPlans({int type = 1}) async {
    final response = await dio.get<Map<String, dynamic>>(
      '/api_client/products/plan/list',
      queryParameters: {'type': type},
    );
    final data = _data(response);
    final list = data['list'];
    if (list is! List) throw const ApiException();
    return list;
  }

  Future<Map<String, dynamic>> updateUser({
    required String avatar,
    required String name,
    required String signature,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/api_client/users/user/update',
      data: {'avatar': avatar, 'name': name, 'signature': signature},
    );
    return _data(response);
  }

  Future<void> logout() async {
    final response = await dio.post<Map<String, dynamic>>(
      '/api_client/auth/logout',
    );
    _data(response);
  }

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) {
    final body = response.data;
    if (body == null) {
      throw const ApiException();
    }
    if (body['status']?.toString() != '0000') {
      throw ApiException(
        message: body['message']?.toString(),
        statusCode: response.statusCode,
      );
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException();
    }
    return data;
  }
}
