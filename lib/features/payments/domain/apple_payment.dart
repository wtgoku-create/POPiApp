import '../../../shared/type/payment_type.dart';
import '../../profile/domain/product_plan.dart' show ProductPlanCustomInfo;

/// Server product versions are distinct from StoreKit product identifiers.
class AppleProductMapping {
  const AppleProductMapping({
    required this.id,
    required this.productId,
    required this.kind,
    required this.businessId,
    this.title = '',
    this.description = '',
    this.amountFen = 0,
    this.originalPriceAmount = 0,
    this.customInfo,
    this.grantPoints = 0,
    this.pointsAmount = 0,
    this.bonusPoints = 0,
    this.memberLevel = 0,
    this.planCategory = '',
    this.durationUnit = '',
    this.durationValue = 0,
    this.pointsGrantMode = '',
    this.validityPeriod = '',
  });

  final int id;
  final String productId;
  final PaymentProductKind kind;
  final int businessId;
  final String title;
  final String description;
  final int amountFen;
  final int originalPriceAmount;
  final ProductPlanCustomInfo? customInfo;
  final int grantPoints;
  final int pointsAmount;
  final int bonusPoints;
  final int memberLevel;
  final String planCategory;
  final String durationUnit;
  final int durationValue;
  final String pointsGrantMode;
  final String validityPeriod;

  factory AppleProductMapping.fromJson(Map<String, Object?> json) {
    int integer(String key) => int.tryParse('${json[key]}') ?? 0;
    final customInfo = json['custom_info'];
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
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      amountFen: json['regular_amount_fen'] == null
          ? integer('amount_fen')
          : integer('regular_amount_fen'),
      originalPriceAmount: integer('original_price_amount'),
      customInfo: customInfo is Map
          ? ProductPlanCustomInfo.fromJson(
              Map<String, Object?>.from(customInfo),
            )
          : null,
      grantPoints: integer('grant_points'),
      pointsAmount: integer('points_amount'),
      bonusPoints: integer('bonus_points'),
      memberLevel: integer('member_level'),
      planCategory: json['plan_category']?.toString() ?? '',
      durationUnit: json['duration_unit']?.toString() ?? '',
      durationValue: integer('duration_value'),
      pointsGrantMode: json['points_grant_mode']?.toString() ?? '',
      validityPeriod: json['validity_period']?.toString() ?? '',
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
    this.productVersionId,
    this.grantPoints,
    this.purchase,
    this.storeRequested = false,
  });

  final int businessId;
  final PaymentProductKind kind;
  final String quoteId;
  final int? productVersionId;
  final int? grantPoints;
  final ApplePurchase? purchase;
  final bool storeRequested;

  factory PendingApplePurchase.fromJson(Map<String, Object?> json) =>
      PendingApplePurchase(
        businessId: (json['businessId'] as num).toInt(),
        kind: PaymentProductKind.values.byName(json['kind'] as String),
        quoteId: json['quoteId'] as String,
        productVersionId: (json['productVersionId'] as num?)?.toInt(),
        grantPoints: (json['grantPoints'] as num?)?.toInt(),
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
        productVersionId: productVersionId,
        grantPoints: grantPoints,
        purchase: value,
        storeRequested: requested ?? storeRequested,
      );

  Map<String, Object?> toJson() => {
    'businessId': businessId,
    'kind': kind.name,
    'quoteId': quoteId,
    'productVersionId': productVersionId,
    'grantPoints': grantPoints,
    'purchase': purchase?.json,
    'storeRequested': storeRequested,
  };
}
