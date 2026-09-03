import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/network/network_api.dart';

enum StorePurchaseOutcome {
  purchased,
  canceled,
  unavailable,
  productNotFound,
  failed,
}

class ApplePurchaseService {
  ApplePurchaseService({
    required NetworkApi networkApi,
    InAppPurchase? store,
  })  : _networkApi = networkApi,
        _store = store ?? InAppPurchase.instance {
    if (isSupported) {
      _subscription = _store.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: _handleStreamError,
      );
    }
  }

  final NetworkApi _networkApi;
  final InAppPurchase _store;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Completer<StorePurchaseOutcome>? _activePurchase;
  String? _activeProductId;
  String? _activeBusinessProductId;
  String? _activeBusinessProductType;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<StorePurchaseOutcome> purchase({
    required String productId,
    required String businessProductId,
    required String businessProductType,
    required bool consumable,
  }) async {
    if (!isSupported || !await _store.isAvailable()) {
      return StorePurchaseOutcome.unavailable;
    }
    if (productId.trim().isEmpty) {
      return StorePurchaseOutcome.productNotFound;
    }
    if (_activePurchase != null) return StorePurchaseOutcome.failed;

    final response = await _store.queryProductDetails({productId});
    if (response.error != null || response.productDetails.isEmpty) {
      debugPrint(
        'StoreKit product query failed: productId=$productId, '
        'error=${response.error}, notFoundIDs=${response.notFoundIDs}',
      );
      return StorePurchaseOutcome.productNotFound;
    }

    final completer = Completer<StorePurchaseOutcome>();
    _activePurchase = completer;
    _activeProductId = productId;
    _activeBusinessProductId = businessProductId;
    _activeBusinessProductType = businessProductType;
    final purchaseParam = PurchaseParam(
      productDetails: response.productDetails.single,
    );

    try {
      final started = consumable
          ? await _store.buyConsumable(
              purchaseParam: purchaseParam,
              autoConsume: false,
            )
          : await _store.buyNonConsumable(purchaseParam: purchaseParam);
      if (!started) _completeActive(StorePurchaseOutcome.failed);
    } catch (_) {
      _completeActive(StorePurchaseOutcome.failed);
    }
    return completer.future;
  }

  Future<bool> restorePurchases() async {
    if (!isSupported || !await _store.isAvailable()) return false;
    await _store.restorePurchases();
    return true;
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          continue;
        case PurchaseStatus.canceled:
          _completeIfActive(purchase, StorePurchaseOutcome.canceled);
          continue;
        case PurchaseStatus.error:
          _completeIfActive(purchase, StorePurchaseOutcome.failed);
          continue;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndFinish(purchase);
          continue;
      }
    }
  }

  Future<void> _verifyAndFinish(PurchaseDetails purchase) async {
    try {
      await _networkApi.verifyApplePurchase(
        productId: purchase.productID,
        businessProductId: _activeBusinessProductId ?? '',
        businessProductType: _activeBusinessProductType ?? '',
        purchaseId: purchase.purchaseID,
        verificationData: purchase.verificationData.serverVerificationData,
        transactionDate: purchase.transactionDate ?? '',
      );
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
      _completeIfActive(purchase, StorePurchaseOutcome.purchased);
    } catch (error, stackTrace) {
      debugPrint('Failed to verify Apple purchase: $error');
      debugPrintStack(stackTrace: stackTrace);
      _completeIfActive(purchase, StorePurchaseOutcome.failed);
    }
  }

  void _completeIfActive(
    PurchaseDetails purchase,
    StorePurchaseOutcome outcome,
  ) {
    if (purchase.productID == _activeProductId) _completeActive(outcome);
  }

  void _completeActive(StorePurchaseOutcome outcome) {
    final completer = _activePurchase;
    _activePurchase = null;
    _activeProductId = null;
    _activeBusinessProductId = null;
    _activeBusinessProductType = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete(outcome);
    }
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    debugPrint('Apple purchase stream failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    _completeActive(StorePurchaseOutcome.failed);
  }

  Future<void> dispose() async {
    _completeActive(StorePurchaseOutcome.failed);
    await _subscription?.cancel();
  }
}
