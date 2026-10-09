import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/network_api.dart';

void main() {
  test(
    'Apple endpoints use documented methods, names and list envelopes',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests.add(options);
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                data: {
                  'status': '0000',
                  'data':
                      options.path.endsWith('/products') ||
                          options.path.endsWith('/restore')
                      ? <Object?>[]
                      : <String, Object?>{},
                },
              ),
            );
          },
        ),
      );
      final api = NetworkApi(dio);
      await api.appleProducts('Sandbox');
      await api.previewApplePurchase(
        productVersionId: 101,
        environment: 'Sandbox',
      );
      await api.createApplePurchase('quote-1');
      await api.verifyApplePurchase(
        purchaseId: 'purchase-1',
        signedTransaction: 'header.payload.signature',
      );
      await api.applePurchase('purchase-1');
      await api.restoreApplePurchases(['header.payload.signature']);
      expect(requests.map((item) => item.path), [
        '/api_client/trade/payment/apple/products',
        '/api_client/trade/payment/apple/preview',
        '/api_client/trade/payment/apple/purchases',
        '/api_client/trade/payment/apple/transactions/verify',
        '/api_client/trade/payment/apple/purchases/purchase-1',
        '/api_client/trade/payment/apple/restore',
      ]);
      expect(requests.map((item) => item.method), [
        'GET',
        'POST',
        'POST',
        'POST',
        'GET',
        'POST',
      ]);
      expect(requests[0].queryParameters, {'environment': 'Sandbox'});
      expect(requests[1].data, {
        'productVersionId': 101,
        'environment': 'Sandbox',
      });
      expect(requests[2].data, {'quoteId': 'quote-1'});
      expect(requests[3].data, {
        'purchaseId': 'purchase-1',
        'signedTransaction': 'header.payload.signature',
      });
      expect(requests[4].data, isNull);
      expect(requests[5].data, {
        'signedTransactions': ['header.payload.signature'],
      });
      expect(
        requests.every(
          (request) => !request.headers.containsKey('Idempotency-Key'),
        ),
        isTrue,
      );
      expect(() => api.restoreApplePurchases([]), throwsArgumentError);
      expect(
        () => api.restoreApplePurchases(List.filled(11, 'jws')),
        throwsArgumentError,
      );
    },
  );
}
