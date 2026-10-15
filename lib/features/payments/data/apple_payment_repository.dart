import 'package:flutter/foundation.dart';

import '../../../core/network/network_api.dart';
import '../domain/apple_payment.dart';

/// Adapts the Apple payment contracts without mixing in StoreKit behavior.
class ApplePaymentRepository {
  const ApplePaymentRepository(this.api);

  final NetworkApi api;

  Future<List<AppleProductMapping>> products() async {
    final items = await api.appleProducts();
    if (kDebugMode) {
      debugPrint(
        'Apple catalog response: received=${items.length}, '
        'enabled=${items.whereType<Map>().where((item) => item['enabled'] == true).length}',
      );
    }
    return items
        .whereType<Map>()
        .where((item) => item['enabled'] == true)
        .where(
          (item) => const {'subscription', 'points'}.contains(item['kind']),
        )
        .map(
          (item) =>
              AppleProductMapping.fromJson(Map<String, Object?>.from(item)),
        )
        .toList();
  }

  Future<Map<String, Object?>> preview(int versionId) =>
      api.previewApplePurchase(productVersionId: versionId);

  Future<ApplePurchase> create(String quoteId) async =>
      ApplePurchase.fromJson(await api.createApplePurchase(quoteId));

  Future<ApplePurchase> verify(String id, String jws) async =>
      ApplePurchase.fromJson(
        await api.verifyApplePurchase(purchaseId: id, signedTransaction: jws),
      );

  Future<ApplePurchase> query(String id) async =>
      ApplePurchase.fromJson(await api.applePurchase(id));

  Future<List<ApplePurchase?>> restore(List<String> transactions) async {
    final purchases = <ApplePurchase?>[];
    var batch = <String>[];
    for (final transaction in transactions) {
      if (batch.isNotEmpty &&
          (batch.length == 10 ||
              NetworkApi.appleRestorePayloadBytes([...batch, transaction]) >
                  NetworkApi.appleRestoreMaxBytes)) {
        purchases.addAll(await _restoreBatch(batch));
        batch = [];
      }
      batch.add(transaction);
    }
    if (batch.isNotEmpty) purchases.addAll(await _restoreBatch(batch));
    return purchases;
  }

  Future<List<ApplePurchase?>> _restoreBatch(List<String> transactions) async {
    final results = await api.restoreApplePurchases(transactions);
    final purchases = List<ApplePurchase?>.filled(transactions.length, null);
    final seen = <int>{};
    for (final result in results.whereType<Map>()) {
      final index = result['index'];
      if (index is! int ||
          index < 0 ||
          index >= purchases.length ||
          !seen.add(index)) {
        throw const FormatException('Invalid Apple restore index');
      }
      final data = result['data'];
      if (result['success'] == true && data is Map) {
        purchases[index] = ApplePurchase.fromJson(
          Map<String, Object?>.from(data),
        );
      }
    }
    return purchases;
  }
}
