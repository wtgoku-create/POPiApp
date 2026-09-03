import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:popi_ai_app/core/network/network_api.dart';

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
      productId: 'com.popiai.app.points.600',
      businessProductId: '1',
      businessProductType: 'nonRenewingSubscription',
      purchaseId: 'transaction-1',
      verificationData: 'signed-transaction',
      transactionDate: '1788393600000',
    );

    expect(request.path, '/api_client/payments/apple/verify');
    expect(request.method, 'POST');
    expect(request.data, {
      'product_id': 'com.popiai.app.points.600',
      'business_product_id': '1',
      'business_product_type': 'nonRenewingSubscription',
      'purchase_id': 'transaction-1',
      'verification_data': 'signed-transaction',
      'transaction_date': '1788393600000',
    });
  });
}
