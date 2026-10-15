import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';

class AppleStoreProduct {
  const AppleStoreProduct(this.id, this.title, this.price);
  final String id;
  final String title;
  final String price;
}

class AppleStoreTransaction {
  const AppleStoreTransaction({
    required this.id,
    required this.productId,
    required this.status,
    this.accountToken,
    this.jws = '',
  });
  final String id;
  final String productId;
  final PurchaseStatus status;
  final String? accountToken;
  final String jws;
}

/// Isolates StoreKit 2 JWS, account tokens, and transaction completion.
abstract class ApplePaymentStore {
  Stream<List<AppleStoreTransaction>> get updates;
  Future<bool> available();
  Future<AppleStoreProduct?> product(String id);
  Future<List<AppleStoreProduct>> products(Set<String> ids) async {
    final result = <AppleStoreProduct>[];
    for (final id in ids) {
      final item = await product(id);
      if (item != null) result.add(item);
    }
    return result;
  }

  Future<bool> buy(
    AppleStoreProduct product,
    String accountToken, {
    required bool consumable,
  });
  Future<List<AppleStoreTransaction>> unfinished();
  Future<List<AppleStoreTransaction>> restore();
  Future<void> finish(AppleStoreTransaction transaction);
}

class NativeApplePaymentStore extends ApplePaymentStore {
  InAppPurchase get _store => InAppPurchase.instance;
  final _products = <String, ProductDetails>{};

  @override
  Stream<List<AppleStoreTransaction>> get updates => _store.purchaseStream.map(
    (items) => items.map((item) {
      if (item is! SK2PurchaseDetails) {
        throw StateError('Apple payments require StoreKit 2');
      }
      return AppleStoreTransaction(
        id: item.purchaseID ?? '',
        productId: item.productID,
        status: item.status,
        accountToken: item.appAccountToken,
        jws: item.verificationData.serverVerificationData,
      );
    }).toList(),
  );

  @override
  Future<bool> available() => _store.isAvailable();

  @override
  Future<AppleStoreProduct?> product(String id) async {
    return (await products({id})).firstOrNull;
  }

  @override
  Future<List<AppleStoreProduct>> products(Set<String> ids) async {
    if (ids.isEmpty) return const [];
    final response = await _store.queryProductDetails(ids);
    if (kDebugMode) {
      debugPrint(
        'StoreKit product query: requested=$ids, '
        'returned=${response.productDetails.map((item) => item.id).toList()}, '
        'notFound=${response.notFoundIDs}',
      );
    }
    final error = response.error;
    if (error != null) {
      if (kDebugMode) {
        debugPrint(
          'StoreKit product query error: source=${error.source}, '
          'code=${error.code}, message=${error.message}, '
          'details=${error.details}',
        );
      }
      throw error;
    }
    for (final product in response.productDetails) {
      _products[product.id] = product;
    }
    return response.productDetails
        .map((item) => AppleStoreProduct(item.id, item.title, item.price))
        .toList();
  }

  @override
  Future<bool> buy(
    AppleStoreProduct product,
    String accountToken, {
    required bool consumable,
  }) {
    // The StoreKit 2 plugin forwards this UUID as appAccountToken.
    final params = PurchaseParam(
      productDetails: _products[product.id]!,
      applicationUserName: accountToken,
    );
    // iOS requires autoConsume; StoreKit 2 still waits for our explicit finish.
    return consumable
        ? _store.buyConsumable(purchaseParam: params)
        : _store.buyNonConsumable(purchaseParam: params);
  }

  AppleStoreTransaction _transaction(SK2Transaction item) =>
      AppleStoreTransaction(
        id: item.id,
        productId: item.productId,
        status: PurchaseStatus.purchased,
        accountToken: item.appAccountToken,
        jws: item.receiptData ?? '',
      );

  @override
  Future<List<AppleStoreTransaction>> unfinished() async =>
      (await SK2Transaction.unfinishedTransactions())
          .map(_transaction)
          .toList();

  @override
  Future<List<AppleStoreTransaction>> restore() async {
    await SK2Transaction.restorePurchases();
    return (await SK2Transaction.transactions()).map(_transaction).toList();
  }

  @override
  Future<void> finish(AppleStoreTransaction transaction) =>
      SK2Transaction.finish(int.parse(transaction.id));
}
