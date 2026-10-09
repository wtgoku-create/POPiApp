import '../../../shared/type/payment_type.dart';

/// Catalog information is for display only; the server determines the charge.
class PaymentProduct {
  const PaymentProduct({
    required this.id,
    required this.kind,
    required this.title,
    required this.priceLabel,
  });

  final int id;
  final PaymentProductKind kind;
  final String title;
  final String priceLabel;

  String get storageKey => '${kind.name}:$id';

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'title': title,
    'priceLabel': priceLabel,
  };

  factory PaymentProduct.fromJson(Map<String, Object?> json) => PaymentProduct(
    id: paymentInteger(json['id']) ?? 0,
    kind: PaymentProductKind.values.byName(json['kind'] as String),
    title: json['title'] as String,
    priceLabel: json['priceLabel'] as String,
  );
}

/// Only these three server states together mean that benefits were delivered.
class PaymentState {
  const PaymentState({
    required this.tradeNo,
    required this.payment,
    required this.fulfillment,
    required this.refund,
    this.amountFen,
  });

  final String tradeNo;
  final String payment;
  final String fulfillment;
  final String refund;
  final int? amountFen;

  bool get completed =>
      payment == 'paid' && fulfillment == 'completed' && refund == 'none';

  bool get terminal =>
      completed ||
      const {'closed', 'expired', 'canceled', 'failed'}.contains(payment) ||
      const {'refunded', 'completed', 'partial'}.contains(refund) ||
      fulfillment == 'revoked';

  factory PaymentState.fromJson(Map<String, Object?> json) => PaymentState(
    tradeNo: json['trade_no']?.toString() ?? '',
    payment: json['payment_status']?.toString() ?? '',
    fulfillment: json['fulfillment_status']?.toString() ?? '',
    refund: json['refund_status']?.toString() ?? '',
    amountFen: paymentInteger(json['amount_fen']),
  );
}

class MobilePaymentOrder {
  const MobilePaymentOrder({
    required this.tradeNo,
    required this.channel,
    this.amountFen,
    this.expiresAt,
    this.payParams = const {},
    this.orderString = '',
  });

  final String tradeNo;
  final PaymentChannel channel;
  final int? amountFen;
  final DateTime? expiresAt;
  final Map<String, Object?> payParams;
  final String orderString;

  factory MobilePaymentOrder.fromJson(
    Map<String, Object?> json,
    PaymentChannel channel,
  ) {
    final expires = paymentInteger(json['expires_at']);
    final params = json['pay_params'];
    return MobilePaymentOrder(
      tradeNo: json['trade_no']?.toString() ?? '',
      channel: channel,
      amountFen: paymentInteger(json['amount_fen']),
      expiresAt: expires == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expires * 1000, isUtc: true),
      payParams: params is Map ? Map<String, Object?>.from(params) : const {},
      orderString: json['order_string'] is String
          ? json['order_string'] as String
          : '',
    );
  }
}

/// Persist references only, never SDK signatures or account credentials.
class PendingPayment {
  const PendingPayment({
    required this.product,
    required this.channel,
    this.tradeNo,
    this.amountFen,
    this.active = true,
  });

  final PaymentProduct product;
  final PaymentChannel channel;
  final String? tradeNo;
  final int? amountFen;
  final bool active;

  Map<String, Object?> toJson() => {
    'product': product.toJson(),
    'channel': channel.name,
    'tradeNo': tradeNo,
    'amountFen': amountFen,
    'active': active,
  };

  factory PendingPayment.fromJson(Map<String, Object?> json) => PendingPayment(
    product: PaymentProduct.fromJson(
      Map<String, Object?>.from(json['product'] as Map),
    ),
    channel: PaymentChannel.values.byName(json['channel'] as String),
    tradeNo: json['tradeNo'] as String?,
    amountFen: paymentInteger(json['amountFen']),
    active: json['active'] != false,
  );
}

class PaymentResult {
  const PaymentResult(this.outcome, {this.pending, this.state, this.message});

  final PaymentOutcome outcome;
  final PendingPayment? pending;
  final PaymentState? state;
  final String? message;
}

int? paymentInteger(Object? value) =>
    value is int ? value : int.tryParse(value?.toString() ?? '');

String formatPaymentAmount(int fen) => '¥${(fen / 100).toStringAsFixed(2)}';
