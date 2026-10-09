import 'dart:convert';

import '../../../core/storage/preferences_storage.dart';
import '../domain/mobile_payment.dart';

/// Account-scoped references survive SDK switches and application restarts.
class PendingPaymentStorage {
  PendingPaymentStorage(this.preferences, this.userId);

  final PreferencesStorage preferences;
  final String userId;
  Future<void>? _writes;
  String get _key => 'payment.android.pending.$userId';

  List<PendingPayment> readAll() {
    final text = preferences.getString(_key);
    if (text == null) return const [];
    final records = jsonDecode(text) as List;
    return records
        .map(
          (item) =>
              PendingPayment.fromJson(Map<String, Object?>.from(item as Map)),
        )
        .toList(growable: false);
  }

  PendingPayment? read(PaymentProduct product) {
    for (final item in readAll()) {
      if (item.active && item.product.storageKey == product.storageKey) {
        return item;
      }
    }
    return null;
  }

  Future<void> save(PendingPayment payment) => _serialize(() async {
    final records = readAll()
        .where(
          (item) =>
              !_sameReference(item, payment) &&
              !(item.active &&
                  item.product.storageKey == payment.product.storageKey &&
                  item.tradeNo == null),
        )
        .toList();
    records.add(payment);
    await preferences.setString(
      _key,
      jsonEncode(records.map((item) => item.toJson()).toList()),
    );
  });

  Future<void> remove(PendingPayment payment) => _serialize(() async {
    final records = readAll()
        .where((item) => !_sameReference(item, payment))
        .toList();
    if (records.isEmpty) {
      await preferences.remove(_key);
    } else {
      await preferences.setString(
        _key,
        jsonEncode(records.map((item) => item.toJson()).toList()),
      );
    }
  });

  Future<void> archive(PaymentProduct product) async {
    final payment = read(product);
    if (payment == null) return;
    await save(
      PendingPayment(
        product: payment.product,
        channel: payment.channel,
        tradeNo: payment.tradeNo,
        amountFen: payment.amountFen,
        active: false,
      ),
    );
  }

  bool _sameReference(PendingPayment left, PendingPayment right) =>
      left.product.storageKey == right.product.storageKey &&
      left.tradeNo == right.tradeNo;

  // Order queries on separate pages must not overwrite each other's updates.
  Future<void> _serialize(Future<void> Function() write) {
    final previous = _writes;
    final result = previous == null ? write() : previous.then((_) => write());
    _writes = result.catchError((Object _) {});
    return result;
  }
}
