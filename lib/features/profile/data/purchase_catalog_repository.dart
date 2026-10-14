import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/network_api.dart';
import '../../../shared/type/payment_type.dart';
import '../../payments/data/apple_payment_repository.dart';
import '../../payments/domain/apple_payment.dart';
import '../domain/point_package.dart';
import '../domain/product_plan.dart';
import 'point_package_repository.dart';
import 'product_plan_repository.dart';

/// Apple catalogs render server mappings without requiring StoreKit access.
class PurchaseCatalogRepository {
  const PurchaseCatalogRepository(
    this.api, {
    this.useAppleCatalog = false,
    this.environment = AppConfig.applePaymentEnvironment,
  });

  final NetworkApi api;
  final bool useAppleCatalog;
  final String environment;

  Future<List<AppleProductMapping>> _appleProducts(
    PaymentProductKind kind,
  ) async {
    final mappings = (await ApplePaymentRepository(
      api,
    ).products(environment)).where((item) => item.kind == kind).toList();
    if (kDebugMode) {
      debugPrint(
        'Apple catalog: environment=$environment, kind=${kind.name}, '
        'eligible=${mappings.length}',
      );
    }
    return mappings;
  }

  Future<List<ProductPlan>> plans() async {
    if (!useAppleCatalog) return ProductPlanRepository(api).fetchAll();
    return [
      for (final mapping in await _appleProducts(
        PaymentProductKind.subscription,
      ))
        ProductPlan(
          id: mapping.businessId,
          type: 1,
          image: '',
          title: mapping.title,
          description: mapping.description,
          details: null,
          level: mapping.memberLevel,
          coins: mapping.pointsAmount,
          months: switch (mapping.durationUnit) {
            'year' => mapping.durationValue * 12,
            'month' => mapping.durationValue,
            _ => 0,
          },
          days: mapping.durationUnit == 'day' ? mapping.durationValue : 0,
          power: 0,
          videoLength: 0,
          audioLength: 0,
          originalPriceAmount: 0,
          customInfo: null,
          planCategory: mapping.planCategory,
          pointsGrantMode: mapping.pointsGrantMode,
          bonusPointsAmount: mapping.bonusPoints,
          price: mapping.amountFen,
          oldPrice: 0,
          recommended: false,
          sortNum: 0,
          status: 1,
          createTime: null,
          updateTime: null,
          deleted: false,
          deleteTime: null,
          appleProductId: mapping.productId,
          appleProductVersionId: mapping.id,
        ),
    ];
  }

  Future<List<PointPackage>> pointPackages() async {
    if (!useAppleCatalog) return PointPackageRepository(api).fetchAll();
    return [
      for (final mapping in await _appleProducts(PaymentProductKind.points))
        PointPackage(
          id: mapping.businessId,
          name: mapping.title,
          currency: 'CNY',
          priceAmount: mapping.amountFen / 100,
          pointsAmount: mapping.pointsAmount,
          bonusPoints: mapping.bonusPoints,
          enabled: true,
          sortOrder: 0,
          createdAt: null,
          updatedAt: null,
          appleProductId: mapping.productId,
          appleProductVersionId: mapping.id,
          validityPeriod: mapping.validityPeriod,
        ),
    ];
  }
}
