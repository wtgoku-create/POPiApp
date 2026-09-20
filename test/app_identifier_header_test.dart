import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/app_config.dart';
import 'package:popi_ai_app/core/network/dio_client.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/storage/secure_storage.dart';

class EmptyTokenStorage implements TokenStorage {
  @override
  Future<String?> readAccessToken() async => null;
  @override
  Future<void> writeAccessToken(String token) async {}
  @override
  Future<void> deleteAccessToken() async {}
}

void main() {
  test('both product endpoints carry the active app identifier', () async {
    final dio = DioClient(secureStorage: EmptyTokenStorage()).dio;
    final requests = <RequestOptions>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      final isPlan = options.path.endsWith('/plan/list');
      handler.resolve(Response(requestOptions: options, statusCode: 200, data: {
        'status': '0000',
        'data': isPlan ? {'list': []} : []
      }));
    }));
    final api = NetworkApi(dio);
    await api.pointPackages();
    await api.productPlans();
    expect(requests, hasLength(2));
    for (final request in requests) {
      expect(request.headers['X-App-Identifier'], AppConfig.current.bundleId);
    }
    dio.close();
  });
}
