import 'dart:async';

import '../../../core/network/payment_exception.dart';
import '../../../shared/type/payment_type.dart';
import '../domain/mobile_payment.dart';
import 'android_payment_sdk.dart';
import 'payment_repository.dart';
import 'pending_payment_storage.dart';

/// Tracks each payment attempt separately and reconciles saved orders.
class AndroidPaymentService {
  AndroidPaymentService({
    required this.repository,
    required this.storage,
    required this.sdk,
    required this.supported,
    this.onCompleted,
    this.pollAttempts = 4,
    this.pollInterval = const Duration(seconds: 1),
  });

  final PaymentRepository repository;
  final PendingPaymentStorage storage;
  final AndroidPaymentSdk sdk;
  final bool supported;
  final Future<void> Function()? onCompleted;
  final int pollAttempts;
  final Duration pollInterval;
  bool _busy = false;
  bool _recovering = false;
  bool _disposed = false;

  bool get available => supported && !_disposed && storage.userId.isNotEmpty;

  Future<PaymentResult> purchase(
    PaymentProduct product,
    PaymentChannel channel, {
    Future<bool> Function(SubscriptionPaymentPreview)? confirmPreview,
  }) async {
    if (!available || _busy || product.id <= 0) {
      return const PaymentResult(PaymentOutcome.failed);
    }
    _busy = true;
    PendingPayment? pending;
    try {
      if (!await sdk.available(channel)) {
        return const PaymentResult(PaymentOutcome.failed);
      }
      if (_disposed) return const PaymentResult(PaymentOutcome.failed);
      if (product.kind == PaymentProductKind.subscription) {
        final preview = await repository.preview(product);
        if (confirmPreview != null && !await confirmPreview(preview)) {
          return const PaymentResult(PaymentOutcome.canceled);
        }
      }
      if (_disposed) return const PaymentResult(PaymentOutcome.failed);
      // Mark the attempt first: a transport failure may have created an order.
      pending = PendingPayment(product: product, channel: channel);
      await storage.save(pending);
      if (_disposed) {
        return PaymentResult(PaymentOutcome.unknown, pending: pending);
      }
      final order = await repository.create(product, channel);
      pending = PendingPayment(
        product: product,
        channel: channel,
        tradeNo: order.tradeNo,
        amountFen: order.amountFen,
      );
      await storage.save(pending);
      if (_disposed) {
        return PaymentResult(PaymentOutcome.processing, pending: pending);
      }
      var sdkOutcome = PaymentSdkOutcome.unknown;
      try {
        if (order.expiresAt == null ||
            order.expiresAt!.isAfter(DateTime.now())) {
          sdkOutcome = await sdk.pay(order);
        }
      } catch (_) {
        // The saved order must still be reconciled when a native call fails.
      }
      return await _poll(pending, sdkOutcome: sdkOutcome);
    } on PaymentException catch (error) {
      final tradeNo = error.data['trade_no']?.toString();
      if (pending != null && tradeNo != null && tradeNo.isNotEmpty) {
        pending = PendingPayment(
          product: product,
          channel: channel,
          tradeNo: tradeNo,
          amountFen: paymentInteger(error.data['amount_fen']),
        );
        await storage.save(pending);
        return await _poll(pending);
      }
      // Only explicit validation/auth rejection without an order permits a new attempt.
      if (pending != null &&
          const {'4000', '4001', '4003'}.contains(error.code)) {
        await storage.remove(pending);
        pending = null;
      }
      return PaymentResult(
        pending == null ? PaymentOutcome.failed : PaymentOutcome.unknown,
        pending: pending,
        message: error.message,
      );
    } catch (_) {
      return PaymentResult(
        pending == null ? PaymentOutcome.failed : PaymentOutcome.unknown,
        pending: pending,
      );
    } finally {
      _busy = false;
    }
  }

  Future<PaymentResult> check(PendingPayment pending) => _poll(pending);

  /// Reconcile saved orders after launch/resume without creating new orders.
  Future<void> recover() async {
    if (!available || _recovering) return;
    _recovering = true;
    try {
      for (final pending in storage.readAll()) {
        if (_disposed) break;
        if (pending.tradeNo != null) await check(pending);
      }
    } catch (_) {
      // Keep references so a later resume or checkout can retry reconciliation.
    } finally {
      _recovering = false;
    }
  }

  Future<PaymentResult> _poll(
    PendingPayment pending, {
    PaymentSdkOutcome? sdkOutcome,
  }) async {
    if (!available || pending.tradeNo == null) {
      return PaymentResult(PaymentOutcome.unknown, pending: pending);
    }
    PaymentState? state;
    for (var attempt = 0; attempt < pollAttempts && !_disposed; attempt++) {
      try {
        state = await repository.query(pending.tradeNo!);
        if (_disposed) break;
        if (state.terminal) {
          try {
            await storage.remove(pending);
          } catch (_) {
            // A local storage failure cannot change the server's payment result.
          }
          if (state.completed) {
            try {
              await onCompleted?.call();
            } catch (_) {
              /* Delivery is authoritative. */
            }
          }
          return PaymentResult(
            state.completed ? PaymentOutcome.completed : PaymentOutcome.failed,
            pending: pending,
            state: state,
          );
        }
      } catch (_) {
        // Query failures keep the reference and never replay the creation request.
      }
      if (attempt + 1 < pollAttempts && !_disposed) {
        await Future<void>.delayed(pollInterval);
      }
    }
    return PaymentResult(
      sdkOutcome == PaymentSdkOutcome.canceled && state?.payment != 'paid'
          ? PaymentOutcome.canceled
          : PaymentOutcome.processing,
      pending: pending,
      state: state,
    );
  }

  /// A new attempt is allowed only by a separate, explicit user command.
  Future<void> abandon(PaymentProduct product) async {
    if (_busy || !available) return;
    _busy = true;
    try {
      final pending = storage.read(product);
      if (pending?.tradeNo != null) {
        final state = await repository.query(pending!.tradeNo!);
        if (state.payment == 'paid' && !state.terminal) {
          throw StateError('Paid order is awaiting fulfillment');
        }
      }
      if (!_disposed) await storage.archive(product);
    } finally {
      _busy = false;
    }
  }

  void dispose() {
    _disposed = true;
  }
}
