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
  String productId = _product,
  String kind = 'subscription',
}) => {
  'purchase_id': 'purchase-1',
  'user_id': userId,
  'product_id': productId,
  'app_account_token': token,
  'payment_status': payment,
  'fulfillment_status': fulfillment,
  'refund_status': refund,
  'kind': kind,
};

AppleStoreTransaction _transaction({
  String id = '10',
  String token = _token,
  String productId = _product,
  PurchaseStatus status = PurchaseStatus.purchased,
}) => AppleStoreTransaction(
  id: id,
  productId: productId,
  status: status,
  accountToken: token,
  jws: 'header.$id.signature',
);

class _Store extends ApplePaymentStore {
  final controller = StreamController<List<AppleStoreTransaction>>.broadcast();
  List<AppleStoreTransaction> transactions = [];
  final finished = <String>[];
  final purchases = <String>[];
  final productQueries = <String>[];
  final purchasedProducts = <String>[];
  bool? consumable;
  AppleStoreTransaction? next = _transaction();
  bool isAvailable = true;
  bool missingProduct = false;
  String? finishFailure;
  bool launchAccepted = true;
  bool rejectArguments = false;
  Object? launchFailure;
  Completer<AppleStorePurchaseResult>? pendingLaunch;
  List<AppleStoreTransaction> historyTransactions = [];
  Object? historyFailure;

  @override
  Stream<List<AppleStoreTransaction>> get updates => controller.stream;
  @override
  Future<bool> available() async => isAvailable;
  @override
  Future<AppleStoreProduct?> product(String id) async {
    productQueries.add(id);
    return missingProduct
        ? null
        : AppleStoreProduct(id, 'POPi Monthly', 'HK\$38.00');
  }

  @override
  Future<AppleStorePurchaseResult> buy(
    AppleStoreProduct product,
    String accountToken, {
    required bool consumable,
  }) {
    if (rejectArguments) throw AssertionError('Invalid purchase arguments');
    purchases.add(accountToken);
    purchasedProducts.add(product.id);
    this.consumable = consumable;
    if (launchFailure != null) return Future.error(launchFailure!);
    if (pendingLaunch != null) return pendingLaunch!.future;
    if (!launchAccepted) {
      return Future.value(AppleStorePurchaseResult.notStarted);
    }
    if (next != null) {
      transactions = next!.status == PurchaseStatus.purchased ? [next!] : [];
      controller.add([next!]);
    }
    return Future.value(switch (next?.status) {
      PurchaseStatus.canceled => AppleStorePurchaseResult.canceled,
      PurchaseStatus.pending => AppleStorePurchaseResult.pending,
      _ => AppleStorePurchaseResult.purchased,
    });
  }

  @override
  Future<List<AppleStoreTransaction>> unfinished() async => [...transactions];
  @override
  Future<List<AppleStoreTransaction>> history() async {
    if (historyFailure != null) throw historyFailure!;
    return [...historyTransactions];
  }

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
  ApplePurchaseService service({
    PendingApplePurchaseStorage? pendingStorage,
    Duration requestTimeout = const Duration(minutes: 2),
  }) => ApplePurchaseService(
    repository: ApplePaymentRepository(NetworkApi(dio)),
    storage: pendingStorage ?? storage,
    store: store,
    supported: true,
    retryInterval: const Duration(days: 1),
    verifyInterval: Duration.zero,
    requestTimeout: requestTimeout,
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
      return {
        'quote_id': 'quote-1',
        'product_id': _product,
        'grant_points': 2000,
      };
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
    if (request.path.endsWith('/purchase-1')) {
      return _purchase(payment: 'pending_payment', fulfillment: 'pending');
    }
    return _purchase();
  }

  Future<void> persist({
    ApplePurchasePhase phase = ApplePurchasePhase.unknown,
  }) => storage.save(
    PendingApplePurchase(
      businessId: 1,
      productVersionId: 101,
      kind: PaymentProductKind.subscription,
      quoteId: 'quote-1',
      purchase: ApplePurchase.fromJson(
        _purchase(payment: 'pending_payment', fulfillment: 'pending'),
      ),
      phase: phase,
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
    Future<bool> Function(AppleStoreProduct, int?)? confirm,
  }) => service.purchase(
    productVersionId: 101,
    kind: PaymentProductKind.subscription,
    confirm: confirm ?? (_, _) async => true,
  );

  test(
    'mapping, localized price, intent, account token, JWS, then finish',
    () async {
      expect(h.storage.readAll(), isEmpty);
      var confirmations = 0;
      expect(
        await buy(
          confirm: (product, grantPoints) async {
            confirmations++;
            expect(product.price, 'HK\$38.00');
            expect(grantPoints, 2000);
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
      await buy(confirm: (_, _) async => false),
      StorePurchaseOutcome.canceled,
    );
    expect(h.store.purchases, isEmpty);
    expect(h.storage.readAll(), isEmpty);
    expect(h.requests.any((item) => item.path.endsWith('/purchases')), isFalse);
  });

  for (final rejection in ['arguments', 'not started']) {
    test(
      '$rejection fails and retries the same intent after confirmation',
      () async {
        h.store.rejectArguments = rejection == 'arguments';
        h.store.launchAccepted = rejection != 'not started';
        expect(await buy(), StorePurchaseOutcome.failed);
        final pending = h.storage.readAll().single;
        expect(pending.phase, ApplePurchasePhase.ready);
        expect(pending.purchase?.id, 'purchase-1');
        expect(h.store.finished, isEmpty);

        h.store.rejectArguments = false;
        h.store.launchAccepted = true;
        var confirmations = 0;
        expect(
          await buy(
            confirm: (_, _) async {
              confirmations++;
              return true;
            },
          ),
          StorePurchaseOutcome.purchased,
        );
        expect(confirmations, 1);
        expect(
          h.requests.where((r) => r.path.endsWith('/preview')),
          hasLength(1),
        );
        expect(
          h.requests.where((r) => r.path.endsWith('/purchases')),
          hasLength(1),
        );
        expect(h.store.finished, ['10']);
        expect(h.storage.readAll(), isEmpty);
      },
    );
  }

  test(
    'an interrupted native call reconciles and retries the same unpaid intent',
    () async {
      h.store.launchFailure = StateError('Native response lost');
      expect(await buy(), StorePurchaseOutcome.processing);
      expect(h.storage.readAll().single.phase, ApplePurchasePhase.unknown);
      h.store.launchFailure = null;
      var confirmed = false;
      expect(
        await buy(
          confirm: (_, _) async {
            confirmed = true;
            expect(h.requests.last.path.endsWith('/purchase-1'), isTrue);
            return true;
          },
        ),
        StorePurchaseOutcome.purchased,
      );
      expect(confirmed, isTrue);
      expect(h.store.purchases, [_token, _token]);
      expect(
        h.requests.where((r) => r.path.endsWith('/purchases')),
        hasLength(1),
      );
    },
  );

  for (final phase in [
    ApplePurchasePhase.launching,
    ApplePurchasePhase.unknown,
  ]) {
    test(
      'restart reconciles $phase and reopens payment after confirmation',
      () async {
        await h.persist(phase: phase);
        await service.dispose();
        service = h.service()..start();
        await service.recover();
        expect(h.store.purchases, isEmpty);
        expect(
          await buy(confirm: (_, _) async => false),
          StorePurchaseOutcome.canceled,
        );
        expect(h.store.purchases, isEmpty);
        expect(await buy(), StorePurchaseOutcome.purchased);
        expect(h.store.purchases, [_token]);
        expect(
          h.requests.any(
            (r) => r.path.endsWith('/preview') || r.path.endsWith('/purchases'),
          ),
          isFalse,
        );
      },
    );
  }

  test(
    'legacy requested flag migrates to unknown and can resume the old order',
    () async {
      await h.persist();
      final legacy = h.storage.readAll().single.toJson()
        ..remove('phase')
        ..['storeRequested'] = true;
      final migrated = PendingApplePurchase.fromJson(legacy);
      expect(migrated.phase, ApplePurchasePhase.unknown);
      await h.storage.save(migrated);
      expect(await buy(), StorePurchaseOutcome.purchased);
      expect(h.store.purchases, [_token]);
      expect(h.requests.any((r) => r.path.endsWith('/purchases')), isFalse);
    },
  );

  test('all payment phases persist and ready is the initial state', () async {
    final initial = PendingApplePurchase(
      businessId: 1,
      kind: PaymentProductKind.subscription,
      quoteId: 'quote-1',
    );
    expect(initial.phase, ApplePurchasePhase.ready);
    for (final phase in ApplePurchasePhase.values) {
      await h.persist(phase: phase);
      expect(h.storage.readAll().single.phase, phase);
    }
    await h.storage.remove('quote-1');
    expect(h.storage.readAll(), isEmpty);
  });

  test('native timeout keeps the lock and records late cancellation', () async {
    await service.dispose();
    service = h.service(requestTimeout: const Duration(milliseconds: 10))
      ..start();
    final native = Completer<AppleStorePurchaseResult>();
    h.store.pendingLaunch = native;
    expect(await buy(), StorePurchaseOutcome.processing);
    expect(h.storage.readAll().single.phase, ApplePurchasePhase.launching);
    expect(await buy(), StorePurchaseOutcome.processing);
    expect(h.store.purchases, hasLength(1));
    native.complete(AppleStorePurchaseResult.canceled);
    // Drain the serialized late result before making the next attempt.
    await Future<void>.delayed(Duration.zero);
    await service.recover();
    expect(h.storage.readAll().single.phase, ApplePurchasePhase.ready);
    h.store.pendingLaunch = null;
    expect(await buy(), StorePurchaseOutcome.purchased);
    expect(h.store.purchases, hasLength(2));
    expect(
      h.requests.where((r) => r.path.endsWith('/purchases')),
      hasLength(1),
    );
  });

  test(
    'late cancellation after disposal still repairs the old account reference',
    () async {
      final native = Completer<AppleStorePurchaseResult>();
      h.store.pendingLaunch = native;
      final first = buy();
      while (h.store.purchases.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await service.dispose();
      native.complete(AppleStorePurchaseResult.canceled);
      expect(await first, StorePurchaseOutcome.processing);
      expect(h.storage.readAll().single.phase, ApplePurchasePhase.ready);
      expect(h.refreshes, 0);
    },
  );

  test(
    'late success after timeout is verified and clears the saved attempt',
    () async {
      await service.dispose();
      service = h.service(requestTimeout: const Duration(milliseconds: 10))
        ..start();
      final native = Completer<AppleStorePurchaseResult>();
      h.store.pendingLaunch = native;
      expect(await buy(), StorePurchaseOutcome.processing);
      h.store.transactions = [_transaction()];
      native.complete(AppleStorePurchaseResult.purchased);
      await Future<void>.delayed(Duration.zero);
      await service.recover();
      expect(h.store.finished, ['10']);
      expect(h.storage.readAll(), isEmpty);
      expect(h.store.purchases, hasLength(1));
    },
  );

  test(
    'unknown order checks finished transaction history before reopening payment',
    () async {
      await h.persist();
      h.store.historyTransactions = [_transaction()];
      h.response = (request) => request.path.endsWith('/purchase-1')
          ? _purchase()
          : h._response(request);
      expect(await buy(), StorePurchaseOutcome.purchased);
      expect(h.store.purchases, isEmpty);
      expect(h.store.finished, ['10']);
      expect(h.storage.readAll(), isEmpty);
    },
  );

  test(
    'a history transaction with failed verification cannot be purchased again',
    () async {
      await h.persist();
      h.store.historyTransactions = [_transaction()];
      h.response = (request) {
        if (request.path.endsWith('/verify')) {
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return h._response(request);
      };
      expect(await buy(), StorePurchaseOutcome.processing);
      expect(await buy(), StorePurchaseOutcome.processing);
      expect(h.storage.readAll().single.phase, ApplePurchasePhase.verifying);
      expect(h.store.purchases, isEmpty);
      h.response = null;
      await service.recover();
      expect(h.storage.readAll(), isEmpty);
      expect(h.store.finished, ['10']);
      expect(h.store.purchases, isEmpty);
    },
  );

  test(
    'history failure preserves unknown state and prevents another native call',
    () async {
      await h.persist();
      h.store.historyFailure = StateError('StoreKit unavailable');
      expect(await buy(), StorePurchaseOutcome.processing);
      expect(h.store.purchases, isEmpty);
      expect(h.storage.readAll().single.phase, ApplePurchasePhase.unknown);
    },
  );

  test(
    'old order query failure preserves the reference without another charge',
    () async {
      await h.persist();
      h.response = (request) {
        if (request.path.endsWith('/purchase-1')) {
          throw DioException(
            requestOptions: request,
            type: DioExceptionType.receiveTimeout,
          );
        }
        return h._response(request);
      };
      expect(await buy(), StorePurchaseOutcome.processing);
      expect(h.store.purchases, isEmpty);
      expect(h.storage.readAll().single.phase, ApplePurchasePhase.unknown);
    },
  );

  test(
    'a finished transaction arriving during confirmation prevents relaunch',
    () async {
      await h.persist();
      var delivered = false;
      h.response = (request) =>
          request.path.endsWith('/purchase-1') && delivered
          ? _purchase()
          : h._response(request);
      expect(
        await buy(
          confirm: (_, _) async {
            h.store.historyTransactions = [_transaction()];
            delivered = true;
            return true;
          },
        ),
        StorePurchaseOutcome.purchased,
      );
      expect(h.store.purchases, isEmpty);
      expect(h.store.finished, ['10']);
    },
  );

  for (final state in [
    _purchase(fulfillment: 'pending'),
    _purchase(
      payment: 'pending_payment',
      fulfillment: 'pending',
      refund: 'refunded',
    ),
    _purchase(
      payment: 'pending_payment',
      fulfillment: 'pending',
      userId: 'other',
    ),
  ]) {
    test('an ineligible old order is not relaunched: $state', () async {
      await h.persist();
      h.response = (request) =>
          request.path.endsWith('/purchase-1') ? state : h._response(request);
      expect(await buy(), StorePurchaseOutcome.processing);
      expect(h.store.purchases, isEmpty);
      expect(h.storage.readAll(), hasLength(1));
    });
  }

  for (final phase in [
    ApplePurchasePhase.deferred,
    ApplePurchasePhase.verifying,
  ]) {
    test('$phase survives restart without reopening Apple payment', () async {
      await h.persist(phase: phase);
      await service.dispose();
      service = h.service()..start();
      expect(await buy(), StorePurchaseOutcome.processing);
      expect(h.store.purchases, isEmpty);
      expect(h.storage.readAll().single.phase, phase);
    });
  }

  test(
    'a definitively expired old order permits a new quote after reconciliation',
    () async {
      await h.persist();
      h.response = (request) => request.path.endsWith('/purchase-1')
          ? _purchase(payment: 'expired', fulfillment: 'pending')
          : h._response(request);
      expect(await buy(), StorePurchaseOutcome.purchased);
      expect(
        h.requests.where((r) => r.path.endsWith('/preview')),
        hasLength(1),
      );
      expect(h.store.purchases, hasLength(1));
    },
  );

  test(
    'local expiry alone cannot replace an unresolved server order',
    () async {
      await h.persist();
      h.response = (request) => request.path.endsWith('/purchase-1')
          ? {
              ..._purchase(payment: 'pending_payment', fulfillment: 'pending'),
              'expires_at': 1,
            }
          : h._response(request);
      expect(await buy(), StorePurchaseOutcome.failed);
      expect(h.store.purchases, isEmpty);
      expect(h.storage.readAll(), hasLength(1));
    },
  );

  test(
    'upgrade uses the quoted product for confirmation and payment',
    () async {
      const upgradeProduct = 'com.popi.vip.upgrade';
      h.store.next = _transaction(productId: upgradeProduct);
      h.response = (request) {
        if (request.path.endsWith('/preview')) {
          return {
            'can_purchase': true,
            'action': 'upgrade',
            'product_version_id': 202,
            'product_id': upgradeProduct,
            'quote_id': 'quote-upgrade',
            'grant_points': 1000,
          };
        }
        if (request.path.endsWith('/purchases')) {
          return _purchase(
            payment: 'pending_payment',
            fulfillment: 'pending',
            productId: upgradeProduct,
            kind: 'upgrade',
          );
        }
        if (request.path.endsWith('/verify')) {
          return _purchase(productId: upgradeProduct, kind: 'upgrade');
        }
        return h._response(request);
      };
      expect(
        await buy(
          confirm: (product, points) async {
            expect(product.id, upgradeProduct);
            expect(product.price, 'HK\$38.00');
            expect(points, 1000);
            expect(h.requests.last.path.endsWith('/preview'), isTrue);
            return true;
          },
        ),
        StorePurchaseOutcome.purchased,
      );
      expect(h.store.productQueries, [upgradeProduct]);
      expect(h.store.purchasedProducts, [upgradeProduct]);
      expect(h.store.consumable, isTrue);
      expect(h.store.finished, ['10']);
      expect(h.storage.readAll(), isEmpty);
      expect(h.requests.singleWhere((r) => r.path.endsWith('/preview')).data, {
        'productVersionId': 101,
      });
      expect(
        h.requests.singleWhere((r) => r.path.endsWith('/purchases')).data,
        {'quoteId': 'quote-upgrade'},
      );
    },
  );

  test(
    'ineligible preview never queries StoreKit or creates an intent',
    () async {
      h.response = (request) => request.path.endsWith('/preview')
          ? {'can_purchase': false}
          : h._response(request);
      var confirmed = false;
      expect(
        await buy(
          confirm: (_, _) async {
            confirmed = true;
            return true;
          },
        ),
        StorePurchaseOutcome.failed,
      );
      expect(confirmed, isFalse);
      expect(h.store.productQueries, isEmpty);
      expect(h.store.purchases, isEmpty);
      expect(h.storage.readAll(), isEmpty);
      expect(h.requests.any((r) => r.path.endsWith('/purchases')), isFalse);
    },
  );

  test(
    'a created product differing from the confirmed quote is not paid',
    () async {
      h.response = (request) => request.path.endsWith('/purchases')
          ? _purchase(
              payment: 'pending_payment',
              fulfillment: 'pending',
              productId: 'unexpected-product',
            )
          : h._response(request);
      expect(await buy(), StorePurchaseOutcome.failed);
      expect(h.store.purchases, isEmpty);
      expect(h.storage.readAll(), hasLength(1));
    },
  );

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
    'selects the mapping ID even when multiple versions share a plan ID',
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
      expect(await buy(), StorePurchaseOutcome.purchased);
      expect(
        (h.requests.singleWhere((item) => item.path.endsWith('/preview')).data
            as Map)['productVersionId'],
        101,
      );
    },
  );

  test(
    'points use the selected mapping ID and consumable StoreKit purchases',
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
          productVersionId: 201,
          kind: PaymentProductKind.points,
          confirm: (_, _) async => true,
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
          confirm: (_, _) async {
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

  test(
    'StoreKit cancellation keeps the order available for confirmed retry',
    () async {
      h.store.next = _transaction(status: PurchaseStatus.canceled);
      expect(await buy(), StorePurchaseOutcome.canceled);
      expect(h.storage.readAll().single.phase, ApplePurchasePhase.ready);
      expect(h.store.finished, isEmpty);
      h.store.next = _transaction();
      expect(await buy(), StorePurchaseOutcome.purchased);
      expect(
        h.requests.where((r) => r.path.endsWith('/purchases')),
        hasLength(1),
      );
    },
  );

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
      expect(h.storage.readAll().single.phase, ApplePurchasePhase.deferred);
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
      h.response = (request) => request.path.endsWith('/purchase-1')
          ? _purchase()
          : h._response(request);
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
