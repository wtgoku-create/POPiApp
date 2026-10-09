import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/core/storage/preferences_storage.dart';
import 'package:popi_ai_app/features/payments/data/apple_payment_repository.dart';
import 'package:popi_ai_app/features/payments/data/apple_payment_store.dart';
import 'package:popi_ai_app/features/payments/data/apple_purchase_service.dart';
import 'package:popi_ai_app/features/payments/data/pending_apple_purchase_storage.dart';
import 'package:popi_ai_app/features/payments/domain/apple_payment.dart';
import 'package:popi_ai_app/shared/type/payment_type.dart';

const _token = '22222222-2222-4222-8222-222222222222';
const _product = 'com.popi.vip.monthly';

Map<String, Object?> _purchase({
  String payment = 'paid',
  String fulfillment = 'completed',
  String refund = 'none',
  String userId = '1',
  String token = _token,
}) => {
  'purchase_id': 'purchase-1',
  'user_id': userId,
  'product_id': _product,
  'app_account_token': token,
  'payment_status': payment,
  'fulfillment_status': fulfillment,
  'refund_status': refund,
  'kind': 'subscription',
};

AppleStoreTransaction _transaction({
  String id = '10',
  String token = _token,
  PurchaseStatus status = PurchaseStatus.purchased,
}) => AppleStoreTransaction(
  id: id,
  productId: _product,
  status: status,
  accountToken: token,
  jws: 'header.$id.signature',
);

class _Store extends ApplePaymentStore {
  final controller = StreamController<List<AppleStoreTransaction>>.broadcast();
  List<AppleStoreTransaction> transactions = [];
  final finished = <String>[];
  final purchases = <String>[];
  bool? consumable;
  AppleStoreTransaction? next = _transaction();
  bool isAvailable = true;
  bool missingProduct = false;
  String? finishFailure;

  @override
  Stream<List<AppleStoreTransaction>> get updates => controller.stream;
  @override
  Future<bool> available() async => isAvailable;
  @override
  Future<AppleStoreProduct?> product(String id) async => missingProduct
      ? null
      : AppleStoreProduct(id, 'POPi Monthly', 'HK\$38.00');
  @override
  Future<bool> buy(
    AppleStoreProduct product,
    String accountToken, {
    required bool consumable,
  }) async {
    purchases.add(accountToken);
    this.consumable = consumable;
    if (next != null) {
      transactions = next!.status == PurchaseStatus.purchased ? [next!] : [];
      controller.add([next!]);
    }
    return true;
  }

  @override
  Future<List<AppleStoreTransaction>> unfinished() async => [...transactions];
  @override
  Future<List<AppleStoreTransaction>> restore() async => [...transactions];
  @override
  Future<void> finish(AppleStoreTransaction transaction) async {
    if (transaction.id == finishFailure) throw StateError('Finish failed');
    finished.add(transaction.id);
    transactions.removeWhere((item) => item.id == transaction.id);
  }
}

class _Harness {
  _Harness(this.preferences) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          try {
            final data = response?.call(options) ?? _response(options);
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                data: {'status': '0000', 'data': data},
              ),
            );
          } on DioException catch (error) {
            handler.reject(error);
          }
        },
      ),
    );
  }
  final SharedPreferences preferences;
  final dio = Dio();
  final store = _Store();
  final requests = <RequestOptions>[];
  Object? Function(RequestOptions)? response;
  int refreshes = 0;
  PendingApplePurchaseStorage get storage =>
      PendingApplePurchaseStorage(PreferencesStorage(preferences), '1');
  ApplePurchaseService service({PendingApplePurchaseStorage? pendingStorage}) =>
      ApplePurchaseService(
        repository: ApplePaymentRepository(NetworkApi(dio)),
        storage: pendingStorage ?? storage,
        store: store,
        environment: 'Sandbox',
        supported: true,
        retryInterval: const Duration(days: 1),
        verifyInterval: Duration.zero,
        onCompleted: () async {
          refreshes++;
        },
      );
  Object? _response(RequestOptions request) {
    if (request.path.endsWith('/products')) {
      return [
        {
          'id': 101,
          'product_id': _product,
          'kind': 'subscription',
          'plan_id': 1,
          'enabled': true,
        },
      ];
    }
    if (request.path.endsWith('/preview')) {
      return {'quote_id': 'quote-1', 'product_id': _product};
    }
    if (request.path.endsWith('/purchases')) {
      return _purchase(payment: 'pending_payment', fulfillment: 'pending');
    }
    if (request.path.endsWith('/restore')) {
      final signed = (request.data as Map)['signedTransactions'] as List;
      return [
        for (var index = 0; index < signed.length; index++)
          {'index': index, 'success': true, 'data': _purchase()},
      ];
    }
    return _purchase();
  }

  Future<void> persist({bool requested = true}) => storage.save(
    PendingApplePurchase(
      businessId: 1,
      kind: PaymentProductKind.subscription,
      quoteId: 'quote-1',
      purchase: ApplePurchase.fromJson(
        _purchase(payment: 'pending_payment', fulfillment: 'pending'),
      ),
      storeRequested: requested,
    ),
  );
}

class _FailingStorage extends PendingApplePurchaseStorage {
  _FailingStorage(
    super.preferences,
    super.userId, {
    this.failSave = false,
    this.failRemove = false,
  });
  final bool failSave;
  final bool failRemove;

  @override
  Future<void> save(PendingApplePurchase purchase) async {
    if (failSave) throw StateError('Save failed');
    await super.save(purchase);
  }

  @override
  Future<void> remove(String quoteId) async {
    if (failRemove) throw StateError('Remove failed');
    await super.remove(quoteId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Harness h;
  late ApplePurchaseService service;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    h = _Harness(await SharedPreferences.getInstance());
    service = h.service()..start();
    await service.recover();
  });
  tearDown(() async {
    await service.dispose();
    await h.store.controller.close();
  });
  Future<StorePurchaseOutcome> buy({
    Future<bool> Function(AppleStoreProduct)? confirm,
  }) => service.purchase(
    businessProductId: 1,
    kind: PaymentProductKind.subscription,
    confirm: confirm ?? (_) async => true,
  );

  test(
    'mapping, localized price, intent, account token, JWS, then finish',
    () async {
      expect(h.storage.readAll(), isEmpty);
      var confirmations = 0;
      expect(
        await buy(
          confirm: (product) async {
            confirmations++;
            expect(product.price, 'HK\$38.00');
            expect(
              h.requests.any((item) => item.path.endsWith('/purchases')),
              isFalse,
            );
            return true;
          },
        ),
        StorePurchaseOutcome.purchased,
      );
      expect(confirmations, 1);
      expect(h.store.purchases, [_token]);
      expect(h.store.consumable, isFalse);
      expect(h.store.finished, ['10']);
      expect(h.storage.readAll(), isEmpty);
      expect(h.refreshes, 1);
      final verify = h.requests.singleWhere(
        (item) => item.path.endsWith('/verify'),
      );
      expect(verify.data, {
        'purchaseId': 'purchase-1',
        'signedTransaction': 'header.10.signature',
      });
    },
  );

  test('canceling confirmation does not create or pay', () async {
    expect(
      await buy(confirm: (_) async => false),
      StorePurchaseOutcome.canceled,
    );
    expect(h.store.purchases, isEmpty);
    expect(h.storage.readAll(), isEmpty);
    expect(h.requests.any((item) => item.path.endsWith('/purchases')), isFalse);
  });

  test(
    'unavailable or missing StoreKit products never create intents',
    () async {
      h.store.isAvailable = false;
      expect(await buy(), StorePurchaseOutcome.unavailable);
      h.store.isAvailable = true;
      h.store.missingProduct = true;
      expect(await buy(), StorePurchaseOutcome.productNotFound);
      expect(h.store.purchases, isEmpty);
      expect(
        h.requests.any((request) => request.path.endsWith('/purchases')),
        isFalse,
      );
    },
  );

  test(
    'ambiguous versions are not silently charged as the wrong product',
    () async {
      h.response = (request) => request.path.endsWith('/products')
          ? [
              {
                'id': 101,
                'product_id': _product,
                'kind': 'subscription',
                'plan_id': 1,
                'enabled': true,
              },
              {
                'id': 102,
                'product_id': 'other',
                'kind': 'subscription',
                'plan_id': 1,
                'enabled': true,
              },
            ]
          : h._response(request);
      expect(await buy(), StorePurchaseOutcome.productNotFound);
      expect(h.store.purchases, isEmpty);
    },
  );

  test(
    'points map by package ID and use consumable StoreKit purchases',
    () async {
      h.response = (request) {
        if (request.path.endsWith('/products')) {
          return [
            {
              'id': 201,
              'product_id': _product,
              'kind': 'points',
              'package_id': 9,
              'enabled': true,
            },
          ];
        }
        return h._response(request);
      };
      expect(
        await service.purchase(
          businessProductId: 9,
          kind: PaymentProductKind.points,
          confirm: (_) async => true,
        ),
        StorePurchaseOutcome.purchased,
      );
      expect(h.store.consumable, isTrue);
      expect(
        (h.requests
                .singleWhere((request) => request.path.endsWith('/preview'))
                .data
            as Map)['productVersionId'],
        201,
      );
    },
  );

  test(
    'account switching during confirmation never creates or charges',
    () async {
      expect(
        await buy(
          confirm: (_) async {
            await service.dispose();
            return true;
          },
        ),
        StorePurchaseOutcome.processing,
      );
      expect(h.store.purchases, isEmpty);
      expect(
        h.requests.any((request) => request.path.endsWith('/purchases')),
        isFalse,
      );
    },
  );

  test('StoreKit cancellation clears the local intent', () async {
    h.store.next = _transaction(status: PurchaseStatus.canceled);
    expect(await buy(), StorePurchaseOutcome.canceled);
    expect(h.storage.readAll(), isEmpty);
    expect(h.store.finished, isEmpty);
  });

  test(
    'verification timeout retries the exact purchase and JWS without charging twice',
    () async {
      var calls = 0;
      h.response = (request) {
        if (request.path.endsWith('/verify') && ++calls < 3) {
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return h._response(request);
      };
      expect(await buy(), StorePurchaseOutcome.purchased);
      expect(calls, 3);
      expect(h.store.purchases.length, 1);
      final bodies = h.requests
          .where((item) => item.path.endsWith('/verify'))
          .map((item) => item.data);
      expect(
        bodies.every(
          (item) => (item as Map)['signedTransaction'] == 'header.10.signature',
        ),
        isTrue,
      );
    },
  );

  test('pending fulfillment, refunds and wrong owner never finish', () async {
    for (final state in [
      _purchase(fulfillment: 'pending'),
      _purchase(refund: 'refunded'),
      _purchase(userId: '2'),
      _purchase(token: '33333333-3333-4333-8333-333333333333'),
    ]) {
      await h.persist();
      h.store.transactions = [_transaction()];
      h.response = (request) =>
          request.path.endsWith('/verify') ? state : h._response(request);
      await service.recover();
      expect(h.store.finished, isEmpty);
      expect(h.storage.readAll(), hasLength(1));
    }
  });

  test(
    'restarting recovers unfinished transactions with the saved backend purchase ID',
    () async {
      await h.persist();
      h.store.transactions = [_transaction()];
      await service.dispose();
      service = h.service()..start();
      await service.recover();
      expect(h.store.finished, ['10']);
      expect(h.store.purchases, isEmpty);
      expect(h.storage.readAll(), isEmpty);
      expect(h.requests.last.path.endsWith('/verify'), isTrue);
      expect((h.requests.last.data as Map)['purchaseId'], 'purchase-1');
    },
  );

  test('lost creation response reuses quoteId on the next click', () async {
    var created = 0;
    h.response = (request) {
      if (request.path.endsWith('/purchases') && ++created == 1) {
        throw DioException(
          requestOptions: request,
          type: DioExceptionType.receiveTimeout,
        );
      }
      return h._response(request);
    };
    expect(await buy(), StorePurchaseOutcome.processing);
    expect(h.store.purchases, isEmpty);
    expect(h.storage.readAll().single.quoteId, 'quote-1');
    expect(await buy(), StorePurchaseOutcome.purchased);
    expect(
      h.requests.where((item) => item.path.endsWith('/preview')),
      hasLength(1),
    );
    expect(
      h.requests
          .where((item) => item.path.endsWith('/purchases'))
          .map((item) => item.data),
      [
        {'quoteId': 'quote-1'},
        {'quoteId': 'quote-1'},
      ],
    );
    expect(h.store.purchases, hasLength(1));
  });

  test(
    'a pending native purchase only reconciles on repeated clicks',
    () async {
      h.store.next = _transaction(status: PurchaseStatus.pending);
      h.response = (request) => request.path.endsWith('/purchase-1')
          ? _purchase(payment: 'pending_payment', fulfillment: 'pending')
          : h._response(request);
      expect(await buy(), StorePurchaseOutcome.processing);
      expect(await buy(), StorePurchaseOutcome.processing);
      expect(h.store.purchases, hasLength(1));
      expect(
        h.requests.where((item) => item.path.endsWith('/purchases')),
        hasLength(1),
      );
      expect(h.storage.readAll().single.storeRequested, isTrue);
    },
  );

  test(
    'restore batches at ten and finishes only individually delivered entries',
    () async {
      h.store.transactions = [
        for (var index = 0; index < 11; index++) _transaction(id: '$index'),
      ];
      h.response = (request) {
        if (!request.path.endsWith('/restore')) return h._response(request);
        final signed = (request.data as Map)['signedTransactions'] as List;
        return [
          for (var index = 0; index < signed.length; index++)
            {
              'index': index,
              'success': index != 1,
              'data': index != 1 ? _purchase() : null,
            },
        ];
      };
      expect(await service.restore(), isFalse);
      final batches = h.requests
          .where((item) => item.path.endsWith('/restore'))
          .map(
            (item) => ((item.data as Map)['signedTransactions'] as List).length,
          );
      expect(batches, [10, 1]);
      expect(h.store.finished, hasLength(10));
      expect(h.store.finished, isNot(contains('1')));
    },
  );

  test(
    'unknown unfinished transactions use restore and never create a new intent',
    () async {
      h.store.transactions = [_transaction()];
      await service.recover();
      expect(h.store.finished, ['10']);
      expect(h.requests.last.path.endsWith('/restore'), isTrue);
      expect(h.store.purchases, isEmpty);
    },
  );

  test('storage failures before creation never launch StoreKit', () async {
    await service.dispose();
    service = h.service(
      pendingStorage: _FailingStorage(
        PreferencesStorage(h.preferences),
        '1',
        failSave: true,
      ),
    )..start();
    expect(await buy(), StorePurchaseOutcome.processing);
    expect(h.store.purchases, isEmpty);
    expect(
      h.requests.any((request) => request.path.endsWith('/purchases')),
      isFalse,
    );
  });

  test(
    'cleanup and refresh failures do not turn delivered payment into failure',
    () async {
      await service.dispose();
      final failing = _FailingStorage(
        PreferencesStorage(h.preferences),
        '1',
        failRemove: true,
      );
      service = ApplePurchaseService(
        repository: ApplePaymentRepository(NetworkApi(h.dio)),
        storage: failing,
        store: h.store,
        environment: 'Sandbox',
        supported: true,
        verifyInterval: Duration.zero,
        onCompleted: () async {
          throw StateError('Refresh failed');
        },
      )..start();
      expect(await buy(), StorePurchaseOutcome.purchased);
      expect(h.store.finished, ['10']);
      expect(failing.readAll(), hasLength(1));
    },
  );

  test('persistent references are isolated between accounts', () async {
    await h.persist();
    final other = PendingApplePurchaseStorage(
      PreferencesStorage(h.preferences),
      '2',
    );
    expect(other.readAll(), isEmpty);
    expect(h.storage.readAll(), hasLength(1));
    await h.storage.remove('quote-1');
    expect(h.storage.readAll(), isEmpty);
  });

  test(
    'completed order queries clear references after StoreKit already finished',
    () async {
      await h.persist();
      expect(await buy(), StorePurchaseOutcome.purchased);
      expect(h.storage.readAll(), isEmpty);
      expect(h.store.purchases, isEmpty);
      expect(h.refreshes, 1);
      expect(await buy(), StorePurchaseOutcome.purchased);
      expect(h.store.purchases, hasLength(1));
    },
  );

  test(
    'restore continues when finishing one delivered transaction fails',
    () async {
      h.store.transactions = [
        _transaction(id: 'first'),
        _transaction(id: 'second'),
      ];
      h.store.finishFailure = 'first';
      expect(await service.restore(), isFalse);
      expect(h.store.finished, ['second']);
      expect(h.store.transactions.map((item) => item.id), ['first']);
    },
  );

  test(
    'an invalid unfinished transaction does not block the next one',
    () async {
      h.store.transactions = [
        _transaction(id: 'bad'),
        _transaction(id: 'good'),
      ];
      h.response = (request) {
        if (request.path.endsWith('/restore') &&
            ((request.data as Map)['signedTransactions'] as List).first ==
                'header.bad.signature') {
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.badResponse,
          );
        }
        return h._response(request);
      };
      await service.recover();
      expect(h.store.finished, ['good']);
      expect(h.store.purchases, isEmpty);
    },
  );
}
