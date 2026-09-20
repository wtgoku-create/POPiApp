import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:popi_ai_app/core/network/network_api.dart';
import 'package:popi_ai_app/features/payments/data/apple_purchase_service.dart';
import 'package:popi_ai_app/features/payments/domain/apple_product_catalog.dart';

class FakeStore implements InAppPurchase {
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  String? method;
  bool missing = false;
  int completed = 0;
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => updates.stream;
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> ids) async =>
      ProductDetailsResponse(
          productDetails: missing
              ? []
              : [
                  ProductDetails(
                      id: ids.single,
                      title: 'Product',
                      description: 'Product',
                      price: '30',
                      rawPrice: 30,
                      currencyCode: 'CNY'),
                ],
          notFoundIDs: missing ? ids.toList() : []);
  @override
  Future<bool> buyConsumable(
      {required PurchaseParam purchaseParam, bool autoConsume = true}) async {
    expect(autoConsume, isFalse);
    method = 'consumable';
    return true;
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    method = 'membership';
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PurchaseDetails transaction(String id, PurchaseStatus status) =>
    PurchaseDetails(
      productID: id,
      purchaseID: 'transaction-1',
      transactionDate: '123',
      status: status,
      verificationData: PurchaseVerificationData(
          localVerificationData: '',
          serverVerificationData: 'receipt',
          source: 'app_store'),
    )..pendingCompletePurchase = status == PurchaseStatus.purchased;

Future<void> flush() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late FakeStore store;
  late ApplePurchaseService service;
  late List<Map<String, dynamic>> requests;
  bool fail = false;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    store = FakeStore();
    requests = [];
    fail = false;
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(Map<String, dynamic>.from(options.data as Map));
      handler.resolve(Response(requestOptions: options, statusCode: 200, data: {
        'status': fail ? 'error' : '0000',
        'data': <String, dynamic>{}
      }));
    }));
    service = ApplePurchaseService(networkApi: NetworkApi(dio), store: store);
  });
  tearDown(() async {
    await service.dispose();
    await store.updates.close();
    debugDefaultTargetPlatformOverride = null;
  });

  test('consumable and membership use distinct store methods', () async {
    for (final consumable in [true, false]) {
      final id = consumable ? 'popi.credits.600' : 'popi.starter.1750.monthly';
      final future = service.purchase(
          productId: id,
          businessProductId: '1',
          businessProductType:
              consumable ? appleConsumableType : appleMembershipType,
          consumable: consumable);
      await flush();
      expect(store.method, consumable ? 'consumable' : 'membership');
      store.updates.add([transaction(id, PurchaseStatus.purchased)]);
      expect(await future, StorePurchaseOutcome.purchased);
      expect(requests.last['bundle_id'], 'com.popiai.app');
    }
    expect(store.completed, 2);
  });

  test('wrong app or purchase type is rejected before store query', () async {
    expect(
        await service.purchase(
            productId: 'popistudio.credits.600',
            businessProductId: '1',
            businessProductType: appleConsumableType,
            consumable: true),
        StorePurchaseOutcome.productNotFound);
    expect(
        await service.purchase(
            productId: 'popi.credits.600',
            businessProductId: '1',
            businessProductType: appleMembershipType,
            consumable: false),
        StorePurchaseOutcome.productNotFound);
    expect(store.method, isNull);
  });

  test('unavailable product and cancellation never grant purchases', () async {
    store.missing = true;
    expect(
        await service.purchase(
            productId: 'popi.credits.600',
            businessProductId: '1',
            businessProductType: appleConsumableType,
            consumable: true),
        StorePurchaseOutcome.productNotFound);
    store.missing = false;
    final future = service.purchase(
        productId: 'popi.credits.600',
        businessProductId: '1',
        businessProductType: appleConsumableType,
        consumable: true);
    await flush();
    store.updates
        .add([transaction('popi.credits.600', PurchaseStatus.canceled)]);
    expect(await future, StorePurchaseOutcome.canceled);
    expect(requests, isEmpty);
  });

  test(
      'failed verification remains unfinished and replay resolves without page state',
      () async {
    fail = true;
    store.updates
        .add([transaction('popi.credits.600', PurchaseStatus.purchased)]);
    await flush();
    expect(store.completed, 0);
    fail = false;
    store.updates
        .add([transaction('popi.credits.600', PurchaseStatus.purchased)]);
    await flush();
    expect(store.completed, 1);
    expect(requests.last['business_product_id'], '');
    expect(requests.last['business_product_type'], appleConsumableType);
  });
}
