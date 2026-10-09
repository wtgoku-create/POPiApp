import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/network/payment_exception.dart';
import '../../../shared/type/payment_type.dart';
import '../domain/apple_payment.dart';
import 'apple_payment_repository.dart';
import 'apple_payment_store.dart';
import 'pending_apple_purchase_storage.dart';

/// Creates one intent, verifies JWS, and finishes only after delivered benefits.
class ApplePurchaseService {
  ApplePurchaseService({
    required this.repository,
    required this.storage,
    required this.store,
    required this.environment,
    required this.supported,
    this.onCompleted,
    this.retryInterval = const Duration(seconds: 15),
    this.verifyAttempts = 3,
    this.verifyInterval = const Duration(seconds: 1),
  });

  final ApplePaymentRepository repository;
  final PendingApplePurchaseStorage storage;
  final ApplePaymentStore store;
  final String environment;
  final bool supported;
  final Future<void> Function()? onCompleted;
  final Duration retryInterval;
  final int verifyAttempts;
  final Duration verifyInterval;
  StreamSubscription<List<AppleStoreTransaction>>? _subscription;
  Timer? _timer;
  Future<void> _operations = Future.value();
  Completer<StorePurchaseOutcome>? _active;
  PendingApplePurchase? _activeIntent;
  bool _busy = false;
  bool _disposed = false;
  final _finished = <String>{};

  bool get isSupported => supported && !_disposed && storage.userId.isNotEmpty;

  void start() {
    if (!isSupported || _subscription != null) return;
    _subscription = store.updates.listen(
      (items) => unawaited(_enqueue(() => _handleUpdates(items))),
      onError: (Object error, StackTrace stack) =>
          _complete(StorePurchaseOutcome.processing),
    );
    unawaited(recover());
    _timer = Timer.periodic(retryInterval, (_) => unawaited(recover()));
  }

  Future<StorePurchaseOutcome> purchase({
    required int businessProductId,
    required PaymentProductKind kind,
    required Future<bool> Function(AppleStoreProduct product) confirm,
  }) async {
    if (!isSupported) return StorePurchaseOutcome.unavailable;
    if (_busy) return StorePurchaseOutcome.processing;
    _busy = true;
    PendingApplePurchase? pending;
    var confirmed = false;
    try {
      if (!await store.available()) return StorePurchaseOutcome.unavailable;
      if (_disposed) return StorePurchaseOutcome.unavailable;
      for (final item in storage.readAll()) {
        if (item.businessId == businessProductId && item.kind == kind) {
          pending = item;
          break;
        }
      }
      if (pending?.storeRequested == true) {
        await _enqueue(_recoverTransactions);
        final state = await repository.query(pending!.purchase!.id);
        if (_disposed ||
            state.id != pending.purchase!.id ||
            state.json['user_id'] != pending.purchase!.json['user_id']) {
          return StorePurchaseOutcome.processing;
        }
        if (!state.completed) return StorePurchaseOutcome.processing;
        await _recordCompletion(pending.quoteId);
        return StorePurchaseOutcome.purchased;
      }
      AppleStoreProduct? product;
      if (pending == null) {
        final mappings = (await repository.products(environment))
            .where(
              (item) =>
                  item.businessId == businessProductId && item.kind == kind,
            )
            .toList();
        // Ambiguous upgrade/version mappings must be resolved by the backend.
        if (mappings.length != 1) return StorePurchaseOutcome.productNotFound;
        final mapping = mappings.single;
        product = await store.product(mapping.productId);
        if (product == null) return StorePurchaseOutcome.productNotFound;
        final quote = await repository.preview(mapping.id, environment);
        if (quote['product_id'] != product.id) {
          return StorePurchaseOutcome.failed;
        }
        if (_disposed || !await confirm(product)) {
          return StorePurchaseOutcome.canceled;
        }
        confirmed = true;
        pending = PendingApplePurchase(
          businessId: businessProductId,
          kind: kind,
          quoteId: quote['quote_id'] as String,
        );
        await storage.save(pending);
      }
      if (_disposed) return StorePurchaseOutcome.processing;
      // A lost response retries the persisted quote, never a fresh quotation.
      final intent =
          pending.purchase ?? await repository.create(pending.quoteId);
      if (_disposed) return StorePurchaseOutcome.processing;
      pending = pending.withPurchase(intent);
      await storage.save(pending);
      if (intent.completed) {
        await _recordCompletion(pending.quoteId);
        return StorePurchaseOutcome.purchased;
      }
      if (intent.json['payment_status'] != 'pending_payment' ||
          intent.json['refund_status'] != 'none') {
        return StorePurchaseOutcome.processing;
      }
      product ??= await store.product(intent.productId);
      if (product == null) return StorePurchaseOutcome.productNotFound;
      if (product.id != intent.productId || !_validToken(intent.accountToken)) {
        return StorePurchaseOutcome.failed;
      }
      if (_disposed) return StorePurchaseOutcome.processing;
      if (!confirmed && !await confirm(product)) {
        return StorePurchaseOutcome.canceled;
      }
      if (_disposed) return StorePurchaseOutcome.processing;
      pending = pending.withPurchase(intent, requested: true);
      await storage.save(pending);
      if (_disposed) return StorePurchaseOutcome.processing;
      final completer = Completer<StorePurchaseOutcome>();
      _active = completer;
      _activeIntent = pending;
      final started = await store
          .buy(
            product,
            intent.accountToken,
            consumable:
                kind == PaymentProductKind.points ||
                intent.json['kind'] == 'upgrade',
          )
          .timeout(const Duration(minutes: 2));
      if (!started) _complete(StorePurchaseOutcome.processing);
      return await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => StorePurchaseOutcome.processing,
      );
    } on PaymentException catch (error) {
      if (pending != null &&
          !pending.storeRequested &&
          error.data['purchase_id'] == null &&
          error.data['trade_no'] == null &&
          const {'4000', '4001', '4003', '4302'}.contains(error.code)) {
        await storage.remove(pending.quoteId);
        return StorePurchaseOutcome.failed;
      }
      return pending == null
          ? StorePurchaseOutcome.failed
          : StorePurchaseOutcome.processing;
    } catch (error) {
      debugPrint('Apple payment could not be completed: ${error.runtimeType}');
      return pending == null
          ? StorePurchaseOutcome.failed
          : StorePurchaseOutcome.processing;
    } finally {
      _busy = false;
      _active = null;
      _activeIntent = null;
    }
  }

  bool _validToken(String token) => RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(token);

  Future<void> recover() => _enqueue(() async {
    if (isSupported && !_busy) await _recoverTransactions();
  });

  Future<void> _recoverTransactions() async {
    if (!isSupported) return;
    await _handleUpdates(await store.unfinished());
  }

  Future<void> _handleUpdates(List<AppleStoreTransaction> items) async {
    for (final item in items) {
      if (_disposed) return;
      try {
        switch (item.status) {
          case PurchaseStatus.pending:
            if (item.productId == _activeIntent?.purchase?.productId) {
              _complete(StorePurchaseOutcome.processing);
            }
          case PurchaseStatus.canceled:
            if (item.productId == _activeIntent?.purchase?.productId) {
              await storage.remove(_activeIntent!.quoteId);
              _complete(StorePurchaseOutcome.canceled);
            }
          case PurchaseStatus.error:
            if (item.productId == _activeIntent?.purchase?.productId) {
              _complete(StorePurchaseOutcome.processing);
            }
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            if (_finished.contains(item.id)) continue;
            final matched = storage
                .readAll()
                .where(
                  (pending) =>
                      pending.purchase?.accountToken.toLowerCase() ==
                          item.accountToken?.toLowerCase() &&
                      pending.purchase?.productId == item.productId,
                )
                .firstOrNull;
            final delivered = matched == null
                ? await _restoreBatch([item])
                : await _verify(item, matched);
            if (matched != null && matched.quoteId == _activeIntent?.quoteId) {
              _complete(
                delivered
                    ? StorePurchaseOutcome.purchased
                    : StorePurchaseOutcome.processing,
              );
            }
        }
      } catch (error) {
        // One invalid or unavailable transaction must not block other purchases.
        debugPrint(
          'Apple transaction reconciliation failed: ${error.runtimeType}',
        );
        if (item.accountToken?.toLowerCase() ==
            _activeIntent?.purchase?.accountToken.toLowerCase()) {
          _complete(StorePurchaseOutcome.processing);
        }
      }
    }
  }

  bool _matches(ApplePurchase purchase, AppleStoreTransaction transaction) =>
      purchase.productId == transaction.productId &&
      transaction.accountToken != null &&
      purchase.accountToken.toLowerCase() ==
          transaction.accountToken!.toLowerCase();

  Future<bool> _verify(
    AppleStoreTransaction item,
    PendingApplePurchase pending,
  ) async {
    if (item.jws.isEmpty) return false;
    for (var attempt = 0; attempt < verifyAttempts && !_disposed; attempt++) {
      try {
        final state = await repository.verify(pending.purchase!.id, item.jws);
        if (_disposed) return false;
        if (state.id == pending.purchase!.id &&
            // The backend exposes the gateway user ID, not the app user ID.
            state.json['user_id'] == pending.purchase!.json['user_id'] &&
            state.completed &&
            _matches(state, item)) {
          await _finish(item, pending.quoteId);
          return true;
        }
      } catch (_) {
        // Re-submit this JWS on transient failure; never invoke payment again.
      }
      if (attempt + 1 < verifyAttempts && !_disposed) {
        await Future<void>.delayed(verifyInterval);
      }
    }
    return false;
  }

  Future<bool> restore() async {
    if (!isSupported || _busy) return false;
    _busy = true;
    try {
      return await _enqueueResult(() async {
        final transactions = await store.restore();
        var succeeded = true;
        for (
          var index = 0;
          index < transactions.length && !_disposed;
          index += 10
        ) {
          try {
            if (!await _restoreBatch(
              transactions.skip(index).take(10).toList(),
            )) {
              succeeded = false;
            }
          } catch (_) {
            succeeded = false;
          }
        }
        return succeeded && !_disposed;
      });
    } catch (_) {
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<bool> _restoreBatch(List<AppleStoreTransaction> batch) async {
    if (_disposed || batch.any((item) => item.jws.isEmpty)) return false;
    final results = await repository.restore(
      batch.map((item) => item.jws).toList(),
    );
    var succeeded = true;
    for (var index = 0; index < batch.length && !_disposed; index++) {
      final state = results[index];
      final item = batch[index];
      if (state == null || !state.completed || !_matches(state, item)) {
        succeeded = false;
        continue;
      }
      try {
        final pending = storage
            .readAll()
            .where((entry) => entry.purchase?.id == state.id)
            .firstOrNull;
        await _finish(item, pending?.quoteId);
      } catch (_) {
        succeeded = false;
      }
    }
    return succeeded && !_disposed;
  }

  Future<void> _finish(AppleStoreTransaction item, String? quoteId) async {
    if (_disposed) return;
    if (!_finished.contains(item.id)) {
      await store.finish(item);
      _finished.add(item.id);
    }
    await _recordCompletion(quoteId);
  }

  Future<void> _recordCompletion(String? quoteId) async {
    if (quoteId != null) {
      try {
        await storage.remove(quoteId);
      } catch (_) {
        // Keep the reference for a later query without changing delivery status.
      }
    }
    try {
      if (!_disposed) await onCompleted?.call();
    } catch (_) {
      // Profile refresh errors cannot change confirmed delivery.
    }
  }

  void _complete(StorePurchaseOutcome outcome) {
    final active = _active;
    if (active != null && !active.isCompleted) active.complete(outcome);
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _operations.then((_) => action());
    _operations = result.catchError((Object error) {
      debugPrint(
        'Apple transaction reconciliation failed: ${error.runtimeType}',
      );
      _complete(StorePurchaseOutcome.processing);
    });
    return _operations;
  }

  Future<bool> _enqueueResult(Future<bool> Function() action) {
    final result = _operations.then((_) => action());
    _operations = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _complete(StorePurchaseOutcome.processing);
    await _subscription?.cancel();
  }
}
