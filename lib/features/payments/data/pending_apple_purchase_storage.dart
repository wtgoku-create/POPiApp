import 'dart:convert';

import '../../../core/storage/preferences_storage.dart';
import '../domain/apple_payment.dart';

/// Account-scoped purchase references; signed transactions stay in StoreKit.
class PendingApplePurchaseStorage {
  PendingApplePurchaseStorage(this.preferences, this.userId);

  final PreferencesStorage preferences;
  final String userId;
  Future<void> _writes = Future.value();
  String get _key => 'payment.apple.pending.$userId';

  List<PendingApplePurchase> readAll() {
    final value = preferences.getString(_key);
    if (value == null) return [];
    return (jsonDecode(value) as List)
        .map(
          (item) => PendingApplePurchase.fromJson(
            Map<String, Object?>.from(item as Map),
          ),
        )
        .toList();
  }

  Future<void> save(PendingApplePurchase purchase) => _serialize(() async {
    final records = readAll()
      ..removeWhere((item) => item.quoteId == purchase.quoteId);
    records.add(purchase);
    await preferences.setString(
      _key,
      jsonEncode(records.map((item) => item.toJson()).toList()),
    );
  });

  Future<void> remove(String quoteId) => _serialize(() async {
    final records = readAll()..removeWhere((item) => item.quoteId == quoteId);
    if (records.isEmpty) {
      await preferences.remove(_key);
    } else {
      await preferences.setString(
        _key,
        jsonEncode(records.map((item) => item.toJson()).toList()),
      );
    }
  });

  Future<void> _serialize(Future<void> Function() write) {
    final result = _writes.then((_) => write());
    _writes = result.catchError((Object _) {});
    return result;
  }
}
