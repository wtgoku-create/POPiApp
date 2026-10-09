import '../../../shared/type/payment_type.dart';

/// Server product versions are distinct from StoreKit product identifiers.
class AppleProductMapping {
  const AppleProductMapping({
    required this.id,
    required this.productId,
    required this.kind,
    required this.businessId,
  });

  final int id;
  final String productId;
  final PaymentProductKind kind;
  final int businessId;

  factory AppleProductMapping.fromJson(Map<String, Object?> json) {
    final kind = json['kind'] == 'points'
        ? PaymentProductKind.points
        : PaymentProductKind.subscription;
    if (!const {'points', 'subscription', 'upgrade'}.contains(json['kind'])) {
      throw const FormatException('Unknown Apple product kind');
    }
    return AppleProductMapping(
      id: (json['id'] as num).toInt(),
      productId: json['product_id'] as String,
      kind: kind,
      businessId:
          (json[kind == PaymentProductKind.points ? 'package_id' : 'plan_id']
                  as num)
              .toInt(),
    );
  }
}

class ApplePurchase {
  ApplePurchase.fromJson(this.json);

  final Map<String, Object?> json;
  String get id => json['purchase_id'] as String;
  String get productId => json['product_id'] as String;
  String get accountToken => json['app_account_token'] as String;
  bool get completed =>
      json['payment_status'] == 'paid' &&
      json['fulfillment_status'] == 'completed' &&
      json['refund_status'] == 'none';
}

/// Persist the quote before creation and the native attempt before payment.
class PendingApplePurchase {
  const PendingApplePurchase({
    required this.businessId,
    required this.kind,
    required this.quoteId,
    this.purchase,
    this.storeRequested = false,
  });

  final int businessId;
  final PaymentProductKind kind;
  final String quoteId;
  final ApplePurchase? purchase;
  final bool storeRequested;

  factory PendingApplePurchase.fromJson(Map<String, Object?> json) =>
      PendingApplePurchase(
        businessId: (json['businessId'] as num).toInt(),
        kind: PaymentProductKind.values.byName(json['kind'] as String),
        quoteId: json['quoteId'] as String,
        purchase: json['purchase'] is Map
            ? ApplePurchase.fromJson(
                Map<String, Object?>.from(json['purchase'] as Map),
              )
            : null,
        storeRequested: json['storeRequested'] == true,
      );

  PendingApplePurchase withPurchase(ApplePurchase value, {bool? requested}) =>
      PendingApplePurchase(
        businessId: businessId,
        kind: kind,
        quoteId: quoteId,
        purchase: value,
        storeRequested: requested ?? storeRequested,
      );

  Map<String, Object?> toJson() => {
    'businessId': businessId,
    'kind': kind.name,
    'quoteId': quoteId,
    'purchase': purchase?.json,
    'storeRequested': storeRequested,
  };
}
