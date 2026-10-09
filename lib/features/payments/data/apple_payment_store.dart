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
  Future<bool> buy(
    AppleStoreProduct product,
    String accountToken, {
    required bool consumable,
  });
  Future<List<AppleStoreTransaction>> unfinished();
  Future<List<AppleStoreTransaction>> restore();
  Future<void> finish(AppleStoreTransaction transaction);
}

class NativeApplePaymentStore implements ApplePaymentStore {
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
    final response = await _store.queryProductDetails({id});
    if (response.error != null || response.productDetails.isEmpty) return null;
    final product = response.productDetails.single;
    _products[id] = product;
    return AppleStoreProduct(product.id, product.title, product.price);
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
    return consumable
        ? _store.buyConsumable(purchaseParam: params, autoConsume: false)
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
