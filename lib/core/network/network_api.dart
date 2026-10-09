import 'package:dio/dio.dart';
import 'dart:typed_data';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'payment_exception.dart';
import '../../features/auth/domain/captcha_challenge.dart';
import '../../shared/type/social_app_type.dart';
import '../../shared/type/payment_type.dart';

/// Centralizes concrete HTTP contracts shared by feature data sources.
class NetworkApi {
  const NetworkApi(this.dio);

  final Dio dio;

  String get mediaBaseUrl => dio.options.baseUrl;

  Future<Map<String, Object?>> createStudioUpload(
    Map<String, Object?> input, {
    CancelToken? cancelToken,
  }) => _studioRequest('/api_client/agent/v2/uploads', input, cancelToken);

  Future<Map<String, Object?>> completeStudioUpload(
    String id,
    String clientRequestId, {
    CancelToken? cancelToken,
  }) => _studioRequest(
    '/api_client/agent/v2/uploads/${Uri.encodeComponent(id)}/complete',
    {'clientRequestId': clientRequestId},
    cancelToken,
  );

  Future<Map<String, Object?>> studioMedia(
    String id, {
    CancelToken? cancelToken,
  }) => _studioRequest(
    '/api_client/agent/v2/media/${Uri.encodeComponent(id)}',
    null,
    cancelToken,
  );

  /// Signed storage requests must not inherit the application's Bearer token.
  Future<void> uploadStudioBytes(
    String url,
    Map<String, Object?> headers,
    Uint8List bytes, {
    CancelToken? cancelToken,
  }) async {
    final transport = Dio();
    try {
      await transport.put<Object?>(
        Uri.parse(mediaBaseUrl).resolve(url).toString(),
        data: bytes,
        options: Options(
          headers: headers,
          contentType: headers['Content-Type']?.toString(),
        ),
        cancelToken: cancelToken,
      );
    } finally {
      transport.close(force: true);
    }
  }

  /// Only server-defined generation confirmation routes may be executed.
  Future<Map<String, Object?>> confirmStudioGeneration(
    String path,
    Map<String, Object?> body, {
    CancelToken? cancelToken,
  }) {
    if (!RegExp(
      r'^/api_client/agent/v2/(generation/confirmations|roles/[1-9][0-9]*/activate)$',
    ).hasMatch(path)) {
      throw const ApiException(message: 'Invalid generation confirmation');
    }
    return _studioRequest(path, body, cancelToken);
  }

  Future<Map<String, Object?>> _studioRequest(
    String path,
    Map<String, Object?>? body,
    CancelToken? cancelToken,
  ) async {
    final response = await dio.request<Object?>(
      path,
      data: body,
      options: Options(method: body == null ? 'GET' : 'POST'),
      cancelToken: cancelToken,
    );
    final data = _workBody(response.data)['data'];
    if (data is! Map) throw const ApiException();
    return Map<String, Object?>.from(data);
  }

  Future<Map<String, Object?>> listLibraryWorks({
    required int type,
    required int page,
    required int pageSize,
    CancelToken? cancelToken,
  }) async {
    final response = await dio.get<Object?>(
      '/api_client/anime/task/list',
      queryParameters: {
        'origin': 'app',
        'status_min': 2,
        'page': page,
        'pageSize': pageSize,
        if (type != 0) 'type': type,
        if (type == 1) 'excludeSubType': '106',
      },
      cancelToken: cancelToken,
    );
    final data = _workBody(response.data)['data'];
    if (data is! Map) throw const ApiException();
    return Map<String, Object?>.from(data);
  }

  Future<void> deleteLibraryWork(String id, {CancelToken? cancelToken}) async {
    final response = await dio.get<Object?>(
      '/api_client/anime/asset/delete',
      queryParameters: {'id': id},
      cancelToken: cancelToken,
    );
    _workBody(response.data);
  }

  Map<String, Object?> _workBody(Object? body) {
    if (body is! Map ||
        (body['status'] != null && body['status'].toString() != '0000')) {
      throw ApiException(
        message: body is Map ? body['message']?.toString() : null,
      );
    }
    return Map<String, Object?>.from(body);
  }

  Future<void> saveLibraryRoleProfile(
    String id,
    Map<String, Object?> profile, {
    required String clientRequestId,
  }) async {
    await dio.post<Map<String, dynamic>>(
      '/api_client/agent/v2/roles/${Uri.encodeComponent(id)}/save',
      data: {'clientRequestId': clientRequestId, 'profile': profile},
    );
  }

  Future<Map<String, dynamic>> socialAppBindingStatus(SocialAppType app) async {
    final response = await dio.get<Map<String, dynamic>>(switch (app) {
      SocialAppType.wechat => '/api_client/users/user/wxAppBindStatus',
      SocialAppType.douyin => '/api_client/users/user/douyinAppBindStatus',
    });
    return _data(response);
  }

  Future<Map<String, dynamic>> bindSocialApp(
    SocialAppType app,
    String code,
  ) async {
    final response = await dio.post<Map<String, dynamic>>(
      switch (app) {
        SocialAppType.wechat => '/api_client/users/user/bindWxAppByCode',
        SocialAppType.douyin => '/api_client/users/user/bindDouyinAppByCode',
      },
      data: {'code': code},
    );
    return _data(response);
  }

  Future<(String, int)> createIpAccount({
    required String title,
    required String clientRequestId,
    CancelToken? cancelToken,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/api_client/agent/v2/accounts',
      cancelToken: cancelToken,
      data: {
        'clientRequestId': clientRequestId,
        'expectedRevision': 0,
        'title': title,
        'accountType': 'ip_character',
      },
    );
    final account = _projectData(response.data);
    final id = account['id'];
    if (id is! String || id.isEmpty) throw const ApiException();
    return (id, _revision(account));
  }

  Future<void> saveIpAccountProfile(
    String id, {
    required int revision,
    required String clientRequestId,
    required Map<String, Object?> profile,
    CancelToken? cancelToken,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/api_client/agent/v2/accounts/${Uri.encodeComponent(id)}/profile-versions',
      cancelToken: cancelToken,
      data: {
        'clientRequestId': clientRequestId,
        'expectedRevision': revision,
        'profile': profile,
        'activate': true,
      },
    );
    final version = _projectData(response.data);
    if (version['id'] is! String || (version['id'] as String).isEmpty) {
      throw const ApiException();
    }
  }

  Future<void> updateProject(
    String id, {
    required String clientRequestId,
    int? expectedRevision,
    String? title,
    bool archive = false,
    CancelToken? cancelToken,
  }) async {
    final path = '/api_client/agent/v2/accounts/${Uri.encodeComponent(id)}';
    final revision =
        expectedRevision ??
        _revision(await ipAccountDetail(id, cancelToken: cancelToken));
    final response = await dio.patch<Map<String, dynamic>>(
      path,
      data: {
        'clientRequestId': clientRequestId,
        'expectedRevision': revision,
        if (title != null) 'title': title,
        if (archive) 'action': 'archive',
      },
      cancelToken: cancelToken,
    );
    _projectData(response.data);
  }

  Future<Map<String, dynamic>> ipAccountDetail(
    String id, {
    CancelToken? cancelToken,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      '/api_client/agent/v2/accounts/${Uri.encodeComponent(id)}',
      cancelToken: cancelToken,
    );
    return _projectData(response.data);
  }

  Future<Map<String, dynamic>> ipAccountResourcesPage(
    String id, {
    required bool profiles,
    required int page,
    CancelToken? cancelToken,
  }) async {
    final resource = profiles ? 'profile-versions' : 'creations';
    final response = await dio.get<Map<String, dynamic>>(
      '/api_client/agent/v2/accounts/${Uri.encodeComponent(id)}/$resource',
      queryParameters: {'page': page, 'pageSize': 100},
      cancelToken: cancelToken,
    );
    return _projectData(response.data);
  }

  Future<void> saveIpAccountRoles(
    String id, {
    required int revision,
    required String clientRequestId,
    required List<Map<String, Object?>> items,
    CancelToken? cancelToken,
  }) async {
    final response = await dio.put<Map<String, dynamic>>(
      '/api_client/agent/v2/accounts/${Uri.encodeComponent(id)}/resident-roles',
      data: {
        'clientRequestId': clientRequestId,
        'expectedRevision': revision,
        'items': items,
      },
      cancelToken: cancelToken,
    );
    _projectData(response.data);
  }

  int _revision(Map<String, dynamic> value) {
    final revision = value['revision'];
    if (revision is! int || revision < 1) throw const ApiException();
    return revision;
  }

  Map<String, dynamic> _projectData(Map<String, dynamic>? body) {
    if (body == null ||
        (body['status'] != null && body['status'].toString() != '0000')) {
      throw ApiException(message: body?['message'] as String?);
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) throw const ApiException();
    return data;
  }

  Future<Map<String, dynamic>> projectsPage(
    int page, {
    CancelToken? cancelToken,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      '/api_client/agent/v2/accounts',
      queryParameters: {'status': 'active', 'page': page, 'pageSize': 100},
      cancelToken: cancelToken,
    );
    return _projectData(response.data);
  }

  Future<Map<String, dynamic>> libraryRoleDetail(
    String id, {
    CancelToken? cancelToken,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      '/api_client/agent/v2/roles/${Uri.encodeComponent(id)}',
      cancelToken: cancelToken,
    );
    final data = response.data?['data'];
    if (data is! Map<String, dynamic>) throw const ApiException();
    return data;
  }

  Future<void> deleteLibraryRole(String id, String clientRequestId) async {
    await dio.delete<Map<String, dynamic>>(
      '/api_client/agent/v2/roles/${Uri.encodeComponent(id)}',
      data: {'clientRequestId': clientRequestId},
    );
  }

  Future<Map<String, dynamic>> listLibraryRoles({
    required String category,
    required int page,
    required int pageSize,
    CancelToken? cancelToken,
  }) async {
    final response = await dio.get<Map<String, dynamic>>(
      '/api_client/agent/v2/roles',
      cancelToken: cancelToken,
      queryParameters: {
        'category': category,
        'page': page,
        'pageSize': pageSize,
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

  Future<Map<String, Object?>> previewAppSubscription(int subscriptionId) =>
      _paymentRequest(
        '/api_client/trade/subscription/previewApp',
        data: {'subscriptionId': subscriptionId},
      );

  Future<Map<String, Object?>> createAppPayment({
    required PaymentProductKind kind,
    required PaymentChannel channel,
    required int productId,
  }) {
    final base = switch (kind) {
      PaymentProductKind.subscription => '/api_client/trade/subscription',
      PaymentProductKind.points => '/api_client/users/pointPackage',
    };
    final method = switch (channel) {
      PaymentChannel.wechat => 'payByGatewayAppWxPay',
      PaymentChannel.alipay => 'payByGatewayAppAliPay',
    };
    return _paymentRequest(
      '$base/$method',
      data: {
        if (kind == PaymentProductKind.subscription)
          'subscriptionId': productId,
        if (kind == PaymentProductKind.points) 'packageId': productId,
      },
    );
  }

  Future<Map<String, Object?>> appPaymentOrder(String tradeNo) =>
      _paymentRequest(
        '/api_client/trade/payment/app/orders/${Uri.encodeComponent(tradeNo)}',
      );

  /// Payment failures may contain a created order, including HTTP errors.
  Future<Map<String, Object?>> _paymentRequest(
    String path, {
    Map<String, Object?>? data,
  }) async {
    try {
      final response = await dio.request<Object?>(
        path,
        data: data,
        options: Options(
          method: data == null ? 'GET' : 'POST',
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return _paymentData(response.data, response.statusCode);
    } on DioException catch (error) {
      if (error.response?.data is Map) {
        _paymentData(
          error.response!.data,
          error.response!.statusCode,
          httpFailed: true,
        );
      }
      rethrow;
    }
  }

  Map<String, Object?> _paymentData(
    Object? body,
    int? statusCode, {
    bool httpFailed = false,
  }) {
    final envelope = body is Map ? Map<String, Object?>.from(body) : null;
    final value = envelope?['data'];
    final data = value is Map
        ? Map<String, Object?>.from(value)
        : <String, Object?>{};
    final code = envelope?['status']?.toString();
    if (httpFailed || code != '0000' || value is! Map) {
      throw PaymentException(
        code: code,
        message: envelope?['message']?.toString(),
        statusCode: statusCode,
        data: data,
      );
    }
    return data;
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

  Future<String> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async {
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
  Map<String, dynamic> _appAuthData(Response<Map<String, dynamic>> response) {
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
