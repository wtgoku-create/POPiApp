import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/payments/data/apple_payment_repository.dart';

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
      await api.appleProducts();
      await api.previewApplePurchase(productVersionId: 101);
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
      expect(requests[0].queryParameters, isEmpty);
      expect(requests[1].data, {'productVersionId': 101});
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
      expect(
        () => api.verifyApplePurchase(
          purchaseId: 'purchase-1',
          signedTransaction: 'x' * (256 * 1024 + 1),
        ),
        throwsArgumentError,
      );
      expect(
        () => api.restoreApplePurchases(List.filled(2, 'x' * (256 * 1024))),
        throwsArgumentError,
      );
    },
  );

  test(
    'restore splits by encoded body size and preserves per-item results',
    () async {
      final batches = <List<String>>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              final batch = List<String>.from(
                (request.data as Map)['signedTransactions'] as List,
              );
              batches.add(batch);
              handler.resolve(
                Response(
                  requestOptions: request,
                  data: {
                    'status': '0000',
                    'data': [
                      for (var index = 0; index < batch.length; index++)
                        {
                          'index': index,
                          'success': batch[index].startsWith('a'),
                          'data': batch[index].startsWith('a')
                              ? {'purchase_id': 'one'}
                              : null,
                        },
                    ],
                  },
                ),
              );
            },
          ),
        );
      final transactions = ['a' * (256 * 1024), 'b' * (256 * 1024), 'small'];
      final result = await ApplePaymentRepository(
        NetworkApi(dio),
      ).restore(transactions);
      expect(batches.map((batch) => batch.length), [1, 2]);
      expect(batches.expand((batch) => batch), transactions);
      expect(result.map((item) => item?.id), ['one', null, null]);
      expect(
        batches.every(
          (batch) =>
              NetworkApi.appleRestorePayloadBytes(batch) <=
              NetworkApi.appleRestoreMaxBytes,
        ),
        isTrue,
      );
    },
  );
}
