import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../core/network/payment_exception.dart';
import '../../../core/network/api_exception.dart';
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
    required this.supported,
    this.onCompleted,
    this.retryInterval = const Duration(seconds: 15),
    this.verifyAttempts = 3,
    this.verifyInterval = const Duration(seconds: 1),
    this.requestTimeout = const Duration(minutes: 2),
  });

  final ApplePaymentRepository repository;
  final PendingApplePurchaseStorage storage;
  final ApplePaymentStore store;
  final bool supported;
  final Future<void> Function()? onCompleted;
  final Duration retryInterval;
  final int verifyAttempts;
  final Duration verifyInterval;
  final Duration requestTimeout;
  StreamSubscription<List<AppleStoreTransaction>>? _subscription;
  Timer? _timer;
  Future<void> _operations = Future.value();
  Completer<StorePurchaseOutcome>? _active;
  PendingApplePurchase? _activeIntent;
  bool _busy = false;
  bool _launchInFlight = false;
  bool _disposed = false;
  final _finished = <String>{};
  String? lastFailureMessage;

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
    required int productVersionId,
    required PaymentProductKind kind,
    required Future<bool> Function(AppleStoreProduct product, int? grantPoints)
    confirm,
  }) async {
    if (!isSupported) return StorePurchaseOutcome.unavailable;
    if (_busy || _launchInFlight || store.purchaseInFlight) {
      return StorePurchaseOutcome.processing;
    }
    _busy = true;
    lastFailureMessage = null;
    PendingApplePurchase? pending;
    var confirmed = false;
    try {
      if (!await store.available()) return StorePurchaseOutcome.unavailable;
      if (_disposed) return StorePurchaseOutcome.unavailable;
      for (final item in storage.readAll()) {
        final version =
            item.productVersionId ?? item.purchase?.json['product_version_id'];
        if (version == productVersionId && item.kind == kind) {
          pending = item;
          break;
        }
      }
      if (pending?.purchase != null) {
        final result = await _checkPending(pending!);
        if (result != null) return result;
        pending = _saved(pending.quoteId);
      }
      AppleStoreProduct? product;
      if (pending == null) {
        final mappings = (await repository.products())
            .where((item) => item.id == productVersionId && item.kind == kind)
            .toList();
        // Select the exact mapping, not a plan shared by multiple upgrades.
        if (mappings.length != 1) return StorePurchaseOutcome.productNotFound;
        final mapping = mappings.single;
        // Recover references written before mapping IDs were persisted.
        pending = storage
            .readAll()
            .where(
              (item) =>
                  item.productVersionId == null &&
                  item.businessId == mapping.businessId &&
                  item.kind == kind,
            )
            .firstOrNull;
        if (pending?.purchase != null) {
          final result = await _checkPending(pending!);
          if (result != null) return result;
          pending = _saved(pending.quoteId);
        }
        if (pending == null) {
          final quote = await repository.preview(mapping.id);
          final productId = quote['product_id'];
          final quoteId = quote['quote_id'];
          if (quote['can_purchase'] == false ||
              productId is! String ||
              productId.trim().isEmpty ||
              quoteId is! String ||
              quoteId.trim().isEmpty) {
            return StorePurchaseOutcome.failed;
          }
          // 升级报价可能选择另一商品，确认价格与原生支付都使用实际支付商品。
          product = await store.product(productId);
          if (product == null) return StorePurchaseOutcome.productNotFound;
          if (product.id != productId) return StorePurchaseOutcome.failed;
          final points = (quote['grant_points'] as num?)?.toInt();
          if (_disposed || !await confirm(product, points)) {
            return StorePurchaseOutcome.canceled;
          }
          confirmed = true;
          pending = PendingApplePurchase(
            businessId: mapping.businessId,
            productVersionId: mapping.id,
            grantPoints: points,
            kind: kind,
            quoteId: quoteId,
          );
          await storage.save(pending);
        }
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
      if (!confirmed &&
          !await confirm(
            product,
            (intent.json['grant_points'] as num?)?.toInt() ??
                pending.grantPoints,
          )) {
        return StorePurchaseOutcome.canceled;
      }
      if (_disposed) return StorePurchaseOutcome.processing;
      if (!confirmed) {
        // A late transaction can arrive while the confirmation is visible.
        final result = await _checkPending(pending);
        if (result != null) return result;
        final saved = _saved(pending.quoteId);
        if (saved == null) return StorePurchaseOutcome.failed;
        pending = saved;
      }
      pending = pending.withPurchase(
        intent,
        phase: ApplePurchasePhase.launching,
      );
      await storage.save(pending);
      if (_disposed) return StorePurchaseOutcome.processing;
      final completer = Completer<StorePurchaseOutcome>();
      _active = completer;
      _activeIntent = pending;
      _launchInFlight = true;
      // Timeout releases the UI, not the native call. Its eventual result still
      // updates the saved order, including cancellation after leaving the page.
      final launch = _launch(pending, product, completer).whenComplete(() {
        _launchInFlight = false;
      });
      return await launch.timeout(
        requestTimeout,
        onTimeout: () => StorePurchaseOutcome.processing,
      );
    } on PaymentException catch (error) {
      lastFailureMessage = error.message;
      if (pending != null &&
          pending.purchase == null &&
          pending.phase == ApplePurchasePhase.ready &&
          error.data['purchase_id'] == null &&
          error.data['trade_no'] == null &&
          const {'4000', '4001', '4003', '4302'}.contains(error.code)) {
        await storage.remove(pending.quoteId);
        return StorePurchaseOutcome.failed;
      }
      return pending == null
          ? StorePurchaseOutcome.failed
          : StorePurchaseOutcome.processing;
    } on ApiException catch (error) {
      lastFailureMessage = error.message;
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

  PendingApplePurchase? _saved(String quoteId) =>
      storage.readAll().where((item) => item.quoteId == quoteId).firstOrNull;

  void _log(PendingApplePurchase pending, String event) {
    if (kDebugMode) {
      debugPrint('Apple purchase ${pending.purchase?.id}: $event');
    }
  }

  Future<StorePurchaseOutcome> _launch(
    PendingApplePurchase pending,
    AppleStoreProduct product,
    Completer<StorePurchaseOutcome> completer,
  ) async {
    try {
      _log(pending, 'launching');
      final result = await store.buy(
        product,
        pending.purchase!.accountToken,
        consumable:
            pending.kind == PaymentProductKind.points ||
            pending.purchase!.json['kind'] == 'upgrade',
      );
      _log(pending, 'native result=${result.name}');
      await _enqueueResult(() async {
        final saved = _saved(pending.quoteId);
        if (saved == null) return;
        final phase = switch (result) {
          AppleStorePurchaseResult.canceled ||
          AppleStorePurchaseResult.notStarted => ApplePurchasePhase.ready,
          AppleStorePurchaseResult.pending => ApplePurchasePhase.deferred,
          _ => ApplePurchasePhase.verifying,
        };
        // A transaction callback may already have advanced to verification.
        if (saved.phase != ApplePurchasePhase.verifying) {
          await storage.save(saved.withPurchase(saved.purchase!, phase: phase));
        }
      });
      if (_disposed) return StorePurchaseOutcome.processing;
      if (completer.isCompleted) return await completer.future;
      switch (result) {
        case AppleStorePurchaseResult.canceled:
          return StorePurchaseOutcome.canceled;
        case AppleStorePurchaseResult.notStarted:
          return StorePurchaseOutcome.failed;
        case AppleStorePurchaseResult.pending:
          return StorePurchaseOutcome.processing;
        case AppleStorePurchaseResult.purchased:
        case AppleStorePurchaseResult.unverified:
          await _enqueueResult(_recoverTransactions);
          if (completer.isCompleted) return await completer.future;
          if (_active != completer) return StorePurchaseOutcome.processing;
          return await completer.future.timeout(
            requestTimeout,
            onTimeout: () => StorePurchaseOutcome.processing,
          );
      }
    } catch (error) {
      final notStarted =
          error is AssertionError ||
          (error is PlatformException &&
              error.code == 'storekit2_failed_to_fetch_product');
      _log(
        pending,
        'native error=${error is PlatformException ? error.code : error.runtimeType}',
      );
      try {
        await _enqueueResult(() async {
          final saved = _saved(pending.quoteId);
          if (saved == null || saved.phase == ApplePurchasePhase.verifying) {
            return;
          }
          await storage.save(
            saved.withPurchase(
              saved.purchase!,
              phase: notStarted
                  ? ApplePurchasePhase.ready
                  : ApplePurchasePhase.unknown,
            ),
          );
        });
      } catch (_) {
        // Keep the persisted launching state for reconciliation on next entry.
      }
      if (completer.isCompleted) return await completer.future;
      return notStarted
          ? StorePurchaseOutcome.failed
          : StorePurchaseOutcome.processing;
    }
  }

  // Null allows a user-confirmed retry of the same unpaid order, or a new quote
  // after the server has definitively closed the old order.
  Future<StorePurchaseOutcome?> _checkPending(
    PendingApplePurchase pending,
  ) async {
    final purchase = pending.purchase!;
    var hasTransaction = false;
    await _enqueueResult(() async {
      final unfinished = await store.unfinished();
      hasTransaction = unfinished.any(
        (item) => item.productId == purchase.productId,
      );
      await _handleUpdates(unfinished);
      if (_saved(pending.quoteId) != null) {
        // Finished transactions can be absent from Transaction.unfinished.
        final history = (await store.history())
            .where((item) => _matches(purchase, item))
            .toList();
        hasTransaction = hasTransaction || history.isNotEmpty;
        await _handleUpdates(history);
      }
    });
    if (_disposed) return StorePurchaseOutcome.processing;
    if (_saved(pending.quoteId) == null) return StorePurchaseOutcome.purchased;
    final state = await repository.query(purchase.id);
    if (_disposed ||
        state.id != purchase.id ||
        state.productId != purchase.productId ||
        state.accountToken.toLowerCase() !=
            purchase.accountToken.toLowerCase() ||
        state.json['user_id'] != purchase.json['user_id']) {
      return StorePurchaseOutcome.processing;
    }
    _log(
      pending,
      'reconciled payment=${state.json['payment_status']}, phase=${pending.phase.name}, transaction=$hasTransaction',
    );
    if (state.completed) {
      // Reconciliation may already have removed the reference and refreshed.
      if (_saved(pending.quoteId) != null) {
        await _recordCompletion(pending.quoteId);
      }
      return StorePurchaseOutcome.purchased;
    }
    final saved = _saved(pending.quoteId);
    if (saved == null ||
        hasTransaction ||
        saved.phase == ApplePurchasePhase.deferred ||
        saved.phase == ApplePurchasePhase.verifying) {
      return StorePurchaseOutcome.processing;
    }
    if (const {
      'expired',
      'canceled',
      'cancelled',
      'closed',
    }.contains(state.json['payment_status'])) {
      await storage.remove(pending.quoteId);
      return null;
    }
    if (state.json['payment_status'] != 'pending_payment' ||
        state.json['fulfillment_status'] != 'pending' ||
        state.json['refund_status'] != 'none') {
      return StorePurchaseOutcome.processing;
    }
    final expires = (state.json['expires_at'] as num?)?.toInt();
    if (expires != null &&
        expires <= DateTime.now().millisecondsSinceEpoch ~/ 1000) {
      // Local time alone cannot authorize replacing a potentially paid order.
      return StorePurchaseOutcome.failed;
    }
    await storage.save(
      saved.withPurchase(state, phase: ApplePurchasePhase.ready),
    );
    return null;
  }

  Future<void> recover() => _enqueue(() async {
    if (isSupported && !_busy) await _recoverTransactions();
  });

  Future<void> _recoverTransactions() async {
    if (!isSupported) return;
    await _handleUpdates(await store.unfinished());
    final references = storage
        .readAll()
        .where(
          (item) =>
              item.purchase != null && item.phase != ApplePurchasePhase.ready,
        )
        .toList();
    if (references.isEmpty || _disposed) return;
    final history = (await store.history())
        .where(
          (item) => references.any((entry) => _matches(entry.purchase!, item)),
        )
        .toList();
    await _handleUpdates(history);
  }

  Future<void> _handleUpdates(List<AppleStoreTransaction> items) async {
    for (final item in items) {
      if (_disposed) return;
      try {
        switch (item.status) {
          case PurchaseStatus.pending:
          case PurchaseStatus.canceled:
          case PurchaseStatus.error:
            // These callbacks have no attempt identity. Use the native call's
            // typed result so a late cancellation cannot clear another order.
            break;
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
    await storage.save(
      pending.withPurchase(
        pending.purchase!,
        phase: ApplePurchasePhase.verifying,
      ),
    );
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

  Future<T> _enqueueResult<T>(Future<T> Function() action) {
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
