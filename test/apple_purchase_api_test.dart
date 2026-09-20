import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/app_config.dart';

void main() {
  test('posts Apple purchase verification data to the backend', () async {
    late RequestOptions request;
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          request = options;
          handler.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: options,
              statusCode: 200,
              data: {
                'status': '0000',
                'message': 'ok',
                'data': <String, dynamic>{},
              },
            ),
          );
        },
      ),
    );

    await NetworkApi(dio).verifyApplePurchase(
      productId: '${AppConfig.current.productPrefix}.credits.600',
      businessProductId: '1',
      businessProductType: 'consumable',
      purchaseId: 'transaction-1',
      verificationData: 'signed-transaction',
      transactionDate: '1788393600000',
    );

    expect(request.path, '/api_client/payments/apple/verify');
    expect(request.method, 'POST');
    expect(request.data, {
      'bundle_id': AppConfig.current.bundleId,
      'product_id': '${AppConfig.current.productPrefix}.credits.600',
      'business_product_id': '1',
      'business_product_type': 'consumable',
      'purchase_id': 'transaction-1',
      'verification_data': 'signed-transaction',
      'transaction_date': '1788393600000',
    });
  });
}
