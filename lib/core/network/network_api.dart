import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import '../../features/auth/domain/captcha_challenge.dart';

/// Centralizes concrete HTTP contracts shared by feature data sources.
class NetworkApi {
  const NetworkApi(this.dio);

  final Dio dio;

  Future<Map<String, dynamic>> libraryRoleDetail(String id) async {
    final response = await dio.get<Map<String, dynamic>>(
        '/api_client/agent/v2/roles/${Uri.encodeComponent(id)}');
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) throw const ApiException();
    return data;
  }

  Future<void> deleteLibraryRole(String id, String clientRequestId) async {
    await dio.delete<Map<String, dynamic>>(
        '/api_client/agent/v2/roles/${Uri.encodeComponent(id)}',
        data: {'clientRequestId': clientRequestId});
  }

  Future<Map<String, dynamic>> listLibraryRoles(
      {required String category,
      required int page,
      required int pageSize}) async {
    final response = await dio.get<Map<String, dynamic>>(
      '/api_client/agent/v2/roles',
      queryParameters: {
        'category': category,
        'page': page,
        'pageSize': pageSize
      },
    );
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) throw const ApiException();
    return data;
  }

  Future<Map<String, dynamic>> createCaptcha({required String phone}) async {
    final response = await dio.get<Map<String, dynamic>>(
      '/api_client/captcha/gen',
      queryParameters: {'phone': phone, 'usage': 'LOGIN', 'type': 'SLIDER'},
    );
    return _data(response);
  }

  Future<String> verifyCaptcha(SliderCaptchaVerification verification) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/api_client/captcha/verify',
      data: verification.toJson(),
    );
    final data = _data(response);
    final token = data['token'] as String?;
    if (data['err'] != 0 || token == null || token.isEmpty) {
      throw const ApiException(message: 'Slider verification failed');
    }
    return token;
  }

  Future<void> sendLoginCode({
    required String phone,
    required String captchaToken,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      '/api_client/auth/code',
      queryParameters: {
        'phone': phone,
        'usage': 'LOGIN',
        'captchaToken': captchaToken,
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

  Future<Map<String, dynamic>> loginByPassword({
    required String username,
    required String password,
  }) async {
    if (!AppConfig.passwordLoginEnabled) {
      throw UnsupportedError('Password login is only available in development');
    }
    final response = await dio.post<Map<String, dynamic>>(
      '/api_client/auth/login',
      data: {'username': username, 'password': password},
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> loginByWechatApp({required String code}) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/api_client/auth/loginByWxApp',
      data: {'code': code},
    );
    return _appAuthData(response);
  }

  Future<Map<String, dynamic>> registerWechatAppByPhone({
    required String registerToken,
    required String phone,
    required String code,
    String inviteCode = '',
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/api_client/auth/wxAppRegisterByPhone',
      data: {
        'registerToken': registerToken,
        'phone': phone,
        'code': code,
        'inviteCode': inviteCode,
      },
    );
    return _appAuthData(response);
  }

  Future<Map<String, dynamic>> loginByDouyinApp({required String code}) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/api_client/auth/loginByDouyinCode',
      data: {'code': code},
    );
    return _appAuthData(response);
  }

  Future<Map<String, dynamic>> registerDouyinAppByPhone({
    required String registerToken,
    required String phone,
    required String code,
    String inviteCode = '',
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/api_client/auth/douyinRegisterByPhone',
      data: {
        'registerToken': registerToken,
        'phone': phone,
        'code': code,
        'inviteCode': inviteCode,
      },
    );
    return _appAuthData(response);
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

  Future<void> verifyApplePurchase({
    required String productId,
    required String businessProductId,
    required String businessProductType,
    required String? purchaseId,
    required String verificationData,
    required String transactionDate,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/api_client/payments/apple/verify',
      data: {
        'product_id': productId,
        'business_product_id': businessProductId,
        'business_product_type': businessProductType,
        'purchase_id': purchaseId,
        'verification_data': verificationData,
        'transaction_date': transactionDate,
      },
    );
    _data(response);
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

  Future<String> uploadAvatar(
      {required List<int> bytes, required String filename}) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/api_client/media/upload',
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
        'directory': 'avatar',
      }),
    );
    final body = response.data;
    if (body == null ||
        (body['status'] != null && body['status'].toString() != '0000')) {
      throw ApiException(message: body?['message']?.toString());
    }
    final data = body['data'];
    final url = body['url'] ?? (data is Map ? data['url'] : null);
    if (url is! String || url.isEmpty) throw const ApiException();
    return url;
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

  // The WeChat endpoints have historically returned their result directly,
  // while other API endpoints use the standard status/data envelope.
  Map<String, dynamic> _appAuthData(
    Response<Map<String, dynamic>> response,
  ) {
    final body = response.data;
    if (body == null) throw const ApiException();

    final status = body['status']?.toString();
    if (status != null && status != '0000') {
      throw ApiException(
        message: body['message']?.toString(),
        statusCode: response.statusCode,
      );
    }

    final data = body['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);

    if (body.containsKey('token') || body.containsKey('registerToken')) {
      return body;
    }
    throw const ApiException();
  }
}
