import 'dart:async';

import '../../../core/network/payment_exception.dart';
import '../../../shared/type/payment_type.dart';
import '../domain/mobile_payment.dart';
import 'android_payment_sdk.dart';
import 'payment_repository.dart';
import 'pending_payment_storage.dart';

/// Creates once, persists before switching apps, and only retries order queries.
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
  bool _disposed = false;

  bool get available => supported && !_disposed && storage.userId.isNotEmpty;

  Future<PaymentResult> purchase(
    PaymentProduct product,
    PaymentChannel channel,
  ) async {
    if (!available || _busy || product.id <= 0) {
      return const PaymentResult(PaymentOutcome.failed);
    }
    _busy = true;
    PendingPayment? pending;
    try {
      final previous = storage.read(product);
      if (previous != null) return await check(previous);
      if (!await sdk.available(channel)) {
        return const PaymentResult(PaymentOutcome.failed);
      }
      if (_disposed) return const PaymentResult(PaymentOutcome.failed);
      if (product.kind == PaymentProductKind.subscription) {
        await repository.preview(product);
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
          const {'4000', '4001', '4003', '4302'}.contains(error.code)) {
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
    if (!_busy && available) await storage.archive(product);
  }

  void dispose() {
    _disposed = true;
  }
}
