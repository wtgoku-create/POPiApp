import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/network/payment_exception.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/payments/data/android_payment_sdk.dart';
import 'package:popi_ai_app/features/payments/data/android_payment_service.dart';
import 'package:popi_ai_app/features/payments/data/payment_repository.dart';
import 'package:popi_ai_app/features/payments/data/pending_payment_storage.dart';
import 'package:popi_ai_app/features/payments/domain/mobile_payment.dart';
import 'package:popi_ai_app/shared/type/payment_type.dart';

const _product = PaymentProduct(
  id: 7,
  kind: PaymentProductKind.points,
  title: '600 points',
  priceLabel: '¥6.00',
);

class FakePaymentSdk implements AndroidPaymentSdk {
  bool installed = true;
  int calls = 0;
  PaymentSdkOutcome outcome = PaymentSdkOutcome.returned;
  Future<PaymentSdkOutcome> Function(MobilePaymentOrder)? onPay;

  @override
  Future<bool> available(PaymentChannel channel) async => installed;

  @override
  Future<PaymentSdkOutcome> pay(MobilePaymentOrder order) async {
    calls++;
    return onPay == null ? outcome : await onPay!(order);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PendingPaymentStorage storage;
  late FakePaymentSdk sdk;
  late AndroidPaymentService service;
  late NetworkApi api;
  final requests = <RequestOptions>[];
  Map<String, Object?> state = {};
  Map<String, Object?>? failure;
  bool loseCreationResponse = false;
  bool queryUnavailable = false;
  int refreshed = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = PendingPaymentStorage(
      PreferencesStorage(await SharedPreferences.getInstance()),
      'user-1',
    );
    sdk = FakePaymentSdk();
    requests.clear();
    failure = null;
    refreshed = 0;
    loseCreationResponse = false;
    queryUnavailable = false;
    state = {
      'trade_no': 'PTSUSR7',
      'payment_status': 'paid',
      'fulfillment_status': 'completed',
      'refund_status': 'none',
    };
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          if (options.path.contains('/orders/')) {
            if (queryUnavailable) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.receiveTimeout,
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'status': '0000', 'data': state},
                ),
              );
            }
          } else if (options.path.endsWith('/previewApp')) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'status': '0000',
                  'data': {'amount_fen': 600},
                },
              ),
            );
          } else if (loseCreationResponse) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.receiveTimeout,
              ),
            );
          } else {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data:
                    failure ??
                    {
                      'status': '0000',
                      'data': {
                        'trade_no': 'PTSUSR7',
                        'amount_fen': 600,
                        'order_string': 'a=1+b%2B&sign=xyz',
                      },
                    },
              ),
            );
          }
        },
      ),
    );
    api = NetworkApi(dio);
    service = AndroidPaymentService(
      repository: PaymentRepository(api),
      storage: storage,
      sdk: sdk,
      supported: true,
      pollAttempts: 2,
      pollInterval: Duration.zero,
      onCompleted: () async {
        refreshed++;
      },
    );
  });

  test('four creation routes send only camelCase product identifiers', () async {
    for (final kind in PaymentProductKind.values) {
      for (final channel in PaymentChannel.values) {
        await api.createAppPayment(kind: kind, channel: channel, productId: 7);
        final request = requests.last;
        expect(request.method, 'POST');
        expect(
          request.path,
          '${kind == PaymentProductKind.subscription ? '/api_client/trade/subscription' : '/api_client/users/pointPackage'}/'
          '${channel == PaymentChannel.wechat ? 'payByGatewayAppWxPay' : 'payByGatewayAppAliPay'}',
        );
        expect(request.data, {
          kind == PaymentProductKind.subscription
                  ? 'subscriptionId'
                  : 'packageId':
              7,
        });
        expect(request.headers.containsKey('Idempotency-Key'), isFalse);
      }
    }
  });

  test(
    'saves the order before native payment and preserves the signed string',
    () async {
      expect(storage.readAll(), isEmpty);
      sdk.onPay = (order) async {
        expect(storage.read(_product)?.tradeNo, 'PTSUSR7');
        expect(order.orderString, 'a=1+b%2B&sign=xyz');
        return PaymentSdkOutcome.returned;
      };
      final result = await service.purchase(_product, PaymentChannel.alipay);
      expect(result.outcome, PaymentOutcome.completed);
      expect(storage.readAll(), isEmpty);
      expect(refreshed, 1);
    },
  );

  test('SDK success cannot confirm benefits that are still pending', () async {
    state['fulfillment_status'] = 'pending';
    final result = await service.purchase(_product, PaymentChannel.alipay);
    expect(result.outcome, PaymentOutcome.processing);
    expect(refreshed, 0);
    expect(storage.read(_product)?.tradeNo, 'PTSUSR7');
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
    expect(requests.where((r) => r.method == 'GET'), hasLength(2));
  });

  test('SDK cancellation still reconciles a paid order', () async {
    sdk.outcome = PaymentSdkOutcome.canceled;
    expect(
      (await service.purchase(_product, PaymentChannel.wechat)).outcome,
      PaymentOutcome.completed,
    );
  });

  test('unpaid cancellation keeps its reference for another query', () async {
    sdk.outcome = PaymentSdkOutcome.canceled;
    state['payment_status'] = 'pending_payment';
    state['fulfillment_status'] = 'pending';
    expect(
      (await service.purchase(_product, PaymentChannel.wechat)).outcome,
      PaymentOutcome.canceled,
    );
    expect(storage.read(_product)?.tradeNo, 'PTSUSR7');
  });

  test('transport timeout is not replayed, including after restart', () async {
    loseCreationResponse = true;
    expect(
      (await service.purchase(_product, PaymentChannel.alipay)).outcome,
      PaymentOutcome.unknown,
    );
    final restored = PendingPaymentStorage(storage.preferences, 'user-1');
    expect(restored.read(_product), isNotNull);
    final restarted = AndroidPaymentService(
      repository: PaymentRepository(api),
      storage: restored,
      sdk: sdk,
      supported: true,
    );
    expect(
      (await restarted.purchase(_product, PaymentChannel.alipay)).outcome,
      PaymentOutcome.unknown,
    );
    expect(requests, hasLength(1));
    expect(sdk.calls, 0);
  });

  test(
    'failure responses preserve the created order and trigger queries only',
    () async {
      failure = {
        'status': '5301',
        'message': 'processing',
        'data': {'trade_no': 'PTSUSR7', 'retryable': false},
      };
      expect(
        (await service.purchase(_product, PaymentChannel.alipay)).outcome,
        PaymentOutcome.completed,
      );
      expect(sdk.calls, 0);
      expect(requests.where((r) => r.method == 'POST'), hasLength(1));
    },
  );

  test('explicit validation rejection permits a later attempt', () async {
    failure = {'status': '4000', 'message': 'not allowed', 'data': {}};
    final result = await service.purchase(_product, PaymentChannel.alipay);
    expect(result.outcome, PaymentOutcome.failed);
    expect(result.message, 'not allowed');
    expect(storage.read(_product), isNull);
  });

  test('simultaneous clicks cannot create multiple orders', () async {
    final gate = Completer<PaymentSdkOutcome>();
    sdk.onPay = (_) => gate.future;
    final first = service.purchase(_product, PaymentChannel.alipay);
    final second = await service.purchase(_product, PaymentChannel.alipay);
    expect(second.outcome, PaymentOutcome.failed);
    gate.complete(PaymentSdkOutcome.returned);
    await first;
    expect(requests.where((r) => r.method == 'POST'), hasLength(1));
  });

  test(
    'subscription creation checks the preview using the gateway plan ID',
    () async {
      const subscription = PaymentProduct(
        id: 4,
        kind: PaymentProductKind.subscription,
        title: 'Membership',
        priceLabel: '¥60',
      );
      await service.purchase(subscription, PaymentChannel.alipay);
      expect(requests.first.path, '/api_client/trade/subscription/previewApp');
      expect(requests.first.data, {'subscriptionId': 4});
    },
  );

  test(
    'a query failure retains the reference without retrying creation',
    () async {
      queryUnavailable = true;
      await service.purchase(_product, PaymentChannel.alipay);
      await service.purchase(_product, PaymentChannel.alipay);
      expect(requests.where((r) => r.method == 'POST'), hasLength(1));
      expect(storage.read(_product)?.tradeNo, 'PTSUSR7');
    },
  );

  test(
    'references are isolated by account and explicit new purchases retain history',
    () async {
      const pending = PendingPayment(
        product: _product,
        channel: PaymentChannel.alipay,
        tradeNo: 'PTSUSR-old',
      );
      await storage.save(pending);
      expect(
        PendingPaymentStorage(storage.preferences, 'user-2').readAll(),
        isEmpty,
      );
      await service.abandon(_product);
      expect(storage.read(_product), isNull);
      expect(storage.readAll().single.tradeNo, 'PTSUSR-old');
      expect(storage.readAll().single.active, isFalse);
      await storage.save(
        const PendingPayment(
          product: _product,
          channel: PaymentChannel.wechat,
          tradeNo: 'PTSUSR-new',
        ),
      );
      await storage.remove(pending);
      expect(storage.readAll().single.tradeNo, 'PTSUSR-new');
    },
  );

  test(
    'missing fields, wrong order IDs and refunds never confirm delivery',
    () async {
      for (final patch in [
        {'refund_status': 'refunded'},
        {'fulfillment_status': 'needs_attention'},
        {'payment_status': 'expired'},
        {'trade_no': 'OTHER'},
        {'refund_status': ''},
      ]) {
        state = {
          'trade_no': 'PTSUSR7',
          'payment_status': 'paid',
          'fulfillment_status': 'completed',
          'refund_status': 'none',
          ...patch,
        };
        final result = await service.check(
          const PendingPayment(
            product: _product,
            channel: PaymentChannel.alipay,
            tradeNo: 'PTSUSR7',
          ),
        );
        expect(result.outcome, isNot(PaymentOutcome.completed));
      }
      expect(refreshed, 0);
    },
  );

  test('HTTP failure data retains the order reference', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) => handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(
                requestOptions: options,
                statusCode: 503,
                data: {
                  'status': '5301',
                  'data': {'trade_no': 'PTSUSR7'},
                },
              ),
            ),
          ),
        ),
      );
    await expectLater(
      NetworkApi(dio).createAppPayment(
        kind: _product.kind,
        channel: PaymentChannel.alipay,
        productId: _product.id,
      ),
      throwsA(
        isA<PaymentException>().having(
          (e) => e.data['trade_no'],
          'trade number',
          'PTSUSR7',
        ),
      ),
    );
  });

  test(
    'concurrent storage updates retain both products and exact removals',
    () async {
      const first = PendingPayment(
        product: _product,
        channel: PaymentChannel.alipay,
        tradeNo: 'PTS1',
      );
      const second = PendingPayment(
        product: PaymentProduct(
          id: 8,
          kind: PaymentProductKind.points,
          title: 'Another package',
          priceLabel: '¥12',
        ),
        channel: PaymentChannel.wechat,
        tradeNo: 'PTS2',
      );
      await Future.wait([storage.save(first), storage.save(second)]);
      expect(storage.readAll().map((order) => order.tradeNo), ['PTS1', 'PTS2']);
      await Future.wait([storage.remove(first), storage.save(second)]);
      expect(storage.readAll().single.tradeNo, 'PTS2');
    },
  );

  test(
    'disabled account scope and unavailable SDK do not create orders',
    () async {
      sdk.installed = false;
      await service.purchase(_product, PaymentChannel.alipay);
      expect(requests, isEmpty);
      service.dispose();
      sdk.installed = true;
      await service.purchase(_product, PaymentChannel.alipay);
      expect(requests, isEmpty);
    },
  );
}
